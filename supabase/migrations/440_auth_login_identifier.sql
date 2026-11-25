-- 440: server-side session-only login - storage and service-role-only
-- helpers for the auth-login-identifier edge function.
--
-- Context: 439 made username a login identifier, resolved client-side
-- through the anon-callable lookup_email_by_phone /
-- lookup_email_by_username RPCs. Those RPCs hand an email address to
-- anyone who can guess a username or phone: an email-harvest channel.
-- The auth-login-identifier edge function replaces that flow: the client
-- sends (identifier, password), the function resolves the identifier
-- SERVER-SIDE through auth_login_resolve_email (service-role only),
-- checks the password with GoTrue, and returns ONLY session tokens -
-- never a user object or a standalone email. This migration is the DB
-- half; the edge function is supabase/functions/auth-login-identifier.
--
--   auth_login_attempts                        - attempt ledger + lockout
--   auth_login_begin(identifier_key, ip)       -> attempt id, or NULL when locked
--   auth_login_finish(attempt_id, success)     -> true when the row was updated
--   auth_login_resolve_email(identifier)       -> email or NULL
--
-- Lockout design (review items #231 + security):
--   auth_login_begin RESERVES the attempt atomically: it takes
--   transaction-scoped advisory locks on the identifier bucket and the
--   IP bucket (fixed order, no deadlock), counts recent failures, and
--   only then inserts the attempt row as success=false. Parallel
--   requests serialize on the locks, so at most 5 reservations per
--   identifier (20 per IP) per 10 minutes can ever exist - there is no
--   check-then-act window. auth_login_finish marks the outcome; a
--   successful login converts its row so it stops counting as a failure.
--
-- Bucket scope (review item #231 clarification): buckets are per
-- identifier CLASS AND VALUE - phone:<last 10 digits>, uname:<lowercased
-- username>, email:<lowercased email> - computed by the edge function so
-- every spelling the resolver accepts collapses to one key. Aliases of
-- one account (its phone vs its username) are SEPARATE buckets by
-- design: the account is unknown before authentication, so aliases
-- cannot be merged without resolving first. An account is therefore
-- reachable through at most three bounded buckets, each independently
-- locked; this is the accepted trade-off, documented here.
--
-- Retention (security item): auth_login_begin deletes rows older than
-- 1 day on ~2% of calls (probabilistic, self-contained; no pg_cron
-- dependency).
--
-- Everything here is service-role only: the table denies anon and
-- authenticated (RLS enabled, no policies, ALL revoked), and every
-- function is EXECUTE-revoked from PUBLIC/anon/authenticated.
--
-- auth_login_resolve_email mirrors the resolution rules of
-- lookup_email_by_phone / lookup_email_by_username exactly (same
-- normalization, same deactivated/anonymized exclusions), minus their
-- internal rate limiting - lockout lives in auth_login_begin at the edge
-- layer instead, where it also covers wrong-password attempts.
--
-- This migration is NOT applied to prod without the owner's explicit
-- order.

BEGIN;

-- A0 pre-image guard: none of the new objects may already exist.
DO $a0$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
              WHERE table_schema = 'public' AND table_name = 'auth_login_attempts') THEN
    RAISE EXCEPTION '440 precondition failed: public.auth_login_attempts already exists';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public'
                AND p.proname IN ('auth_login_begin', 'auth_login_finish', 'auth_login_resolve_email')) THEN
    RAISE EXCEPTION '440 precondition failed: an auth_login_* function already exists';
  END IF;
END
$a0$;

CREATE TABLE public.auth_login_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  identifier_key text NOT NULL,
  ip text NOT NULL,
  success boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_login_attempts_identifier_idx
  ON public.auth_login_attempts (identifier_key, created_at DESC);
CREATE INDEX auth_login_attempts_ip_idx
  ON public.auth_login_attempts (ip, created_at DESC);

ALTER TABLE public.auth_login_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auth_login_attempts FROM PUBLIC;
REVOKE ALL ON public.auth_login_attempts FROM anon;
REVOKE ALL ON public.auth_login_attempts FROM authenticated;

-- Reserve an attempt under serialization. Returns the new attempt id,
-- or NULL when the identifier or the IP is over its failure budget.
CREATE FUNCTION public.auth_login_begin(p_identifier_key text, p_ip text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id bigint;
BEGIN
  -- Serialize per identifier bucket and per IP bucket. Fixed order,
  -- transaction-scoped: released when the PostgREST call commits.
  PERFORM pg_advisory_xact_lock(hashtext('id:' || p_identifier_key));
  PERFORM pg_advisory_xact_lock(hashtext('ip:' || p_ip));

  -- Retention: drop rows older than a day on ~2% of calls.
  IF random() < 0.02 THEN
    DELETE FROM public.auth_login_attempts
     WHERE created_at < now() - interval '1 day';
  END IF;

  IF (SELECT count(*) FROM public.auth_login_attempts
       WHERE identifier_key = p_identifier_key
         AND NOT success
         AND created_at > now() - interval '10 minutes') >= 5
  OR (SELECT count(*) FROM public.auth_login_attempts
       WHERE ip = p_ip
         AND NOT success
         AND created_at > now() - interval '10 minutes') >= 20 THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.auth_login_attempts (identifier_key, ip, success)
  VALUES (p_identifier_key, p_ip, false)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

-- Record the outcome. Returns true exactly when the reserved row was
-- updated; the edge function denies tokens when this is not true.
CREATE FUNCTION public.auth_login_finish(p_attempt_id bigint, p_success boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.auth_login_attempts
     SET success = p_success
   WHERE id = p_attempt_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END;
$function$;

-- Resolve a login identifier to the account's auth email. Returns NULL
-- when nothing matches; the edge function answers that case exactly
-- like a wrong password (same status, body, and a dummy GoTrue password
-- check so timing matches too). Email-shaped identifiers are returned
-- as-is: existence is GoTrue's call, so this function never reveals
-- whether an email is registered.
CREATE FUNCTION public.auth_login_resolve_email(p_identifier text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := btrim(coalesce(p_identifier, ''));
  v_email text;
  v_norm text;
  v_digits text;
  v_last10 text;
  v_uname text;
BEGIN
  IF v_id = '' OR length(v_id) > 254 THEN
    RETURN NULL;
  END IF;

  -- Email: pass through untouched (GoTrue decides existence + password).
  IF position('@' IN v_id) > 0 THEN
    RETURN lower(v_id);
  END IF;

  v_digits := regexp_replace(v_id, '[^0-9]', '', 'g');

  -- Phone-shaped: same resolution as lookup_email_by_phone.
  IF length(v_digits) >= 9 AND v_id ~ '^[+0-9 ()-]+$' THEN
    v_norm := public._normalize_egypt_phone(v_id);
    v_last10 := right(v_digits, 10);
    SELECT email INTO v_email
      FROM public.users
     WHERE account_status <> 'deactivated'
       AND email IS NOT NULL
       AND email <> ''
       AND email NOT LIKE '%@anonymized.invalid'
       AND (
         public._normalize_egypt_phone(phone) = v_norm
         OR right(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'), 10) = v_last10
       )
     ORDER BY created_at DESC
     LIMIT 1;
    RETURN v_email;
  END IF;

  -- Username: same resolution as lookup_email_by_username.
  v_uname := lower(v_id);
  SELECT email INTO v_email
    FROM public.users
   WHERE username IS NOT NULL
     AND lower(username) = v_uname
     AND account_status <> 'deactivated'
     AND email NOT LIKE '%@anonymized.invalid'
   LIMIT 1;
  RETURN v_email;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.auth_login_begin(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auth_login_begin(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_login_begin(text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.auth_login_begin(text, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.auth_login_finish(bigint, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auth_login_finish(bigint, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_login_finish(bigint, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.auth_login_finish(bigint, boolean) TO service_role;

REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.auth_login_resolve_email(text) TO service_role;

COMMIT;
