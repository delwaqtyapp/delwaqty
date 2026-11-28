-- 466: phone + password signup without WhatsApp (DRAFT, NOT APPLIED).
-- Why: Meta's WhatsApp number is still pending. This adds a server switch,
-- platform_settings.feature_flags.signup_phone_mode:
--   'whatsapp' (default, today's behavior: a webhook-verified challenge is
--              required to sign up)
--   'password' (no OTP: instant account, phone confirmed at the first order)
-- Flip it with an UPDATE; the WhatsApp path is untouched and comes back by
-- setting the flag to 'whatsapp'.
-- What it adds:
--   1. users.phone_verified (existing rows true; a signup is true only when a
--      webhook-verified register challenge for that phone was just consumed,
--      or the account has no phone, e.g. Google).
--   2. signup_phone_mode() (anon-readable) and the unconfirmed-signup hourly
--      cap (feature_flags.signup_unverified_per_hour, default 30).
--   3. before_user_created_phone_guard: in 'password' mode a phone signup is
--      allowed without a challenge. All other checks stay (Egyptian mobile,
--      canonical identifier, one account per phone).
--   4. Limits for unconfirmed customers on orders: cash only, no platform
--      credit, at most 2 open orders (orders_unverified_limits trigger).
--   5. confirm_customer_phone(user): the merchant who owns one of the user's
--      orders, the driver on one, or an admin confirms the number after the
--      call. Audited in audit_log.
--   6. phone_verified cannot be changed by the account holder directly.
--   7. Courier rides get the same limits (rides_unverified_limits).
--   8. Forgotten password without WhatsApp: admin-issued one-time recovery
--      code (admin_issue_recovery_code) consumed by an edge function.
-- Re-runnable.

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone_verified boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION public.signup_phone_mode()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN feature_flags ->> 'signup_phone_mode' = 'password' THEN 'password' ELSE 'whatsapp' END
    FROM public.platform_settings WHERE id = 'default'
  UNION ALL SELECT 'whatsapp'
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.signup_phone_mode() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.signup_phone_mode() TO anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public._signup_unverified_hourly_cap()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT LEAST(GREATEST((feature_flags ->> 'signup_unverified_per_hour')::int, 1), 1000)
       FROM public.platform_settings
      WHERE id = 'default' AND (feature_flags ->> 'signup_unverified_per_hour') ~ '^[0-9]+$'),
    30);
$$;
REVOKE ALL ON FUNCTION public._signup_unverified_hourly_cap() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._signup_unverified_hourly_cap() TO service_role, supabase_auth_admin;

-- phone_verified is true only with a just-consumed webhook proof (or no phone).
CREATE OR REPLACE FUNCTION public.users_set_phone_verified()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.phone IS NULL OR btrim(NEW.phone) = '' THEN
    NEW.phone_verified := true;
  ELSE
    NEW.phone_verified := EXISTS (
      SELECT 1 FROM public.whatsapp_otp_verifications w
       WHERE w.phone = public._normalize_egypt_phone(NEW.phone)
         AND w.purpose = 'register'
         AND w.verified = true
         AND w.verified_via = 'webhook'
         AND w.consumed_at IS NOT NULL
         AND w.consumed_at > now() - interval '5 minutes');
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.users_set_phone_verified() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS users_set_phone_verified ON public.users;
CREATE TRIGGER users_set_phone_verified BEFORE INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_set_phone_verified();

CREATE OR REPLACE FUNCTION public.users_guard_phone_verified()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') AND NEW.phone_verified IS DISTINCT FROM OLD.phone_verified THEN
    RAISE EXCEPTION 'phone_verified is managed by confirm_customer_phone';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS users_guard_phone_verified ON public.users;
CREATE TRIGGER users_guard_phone_verified BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.users_guard_phone_verified();

-- the hook ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.before_user_created_phone_guard(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_provider text := nullif(event #>> '{user,app_metadata,provider}', '');
  v_meta_phone text := nullif(event #>> '{user,user_metadata,phone}', '');
  v_user_phone text := nullif(event #>> '{user,phone}', '');
  v_email text := lower(coalesce(event #>> '{user,email}', ''));
  v_challenge_text text := nullif(event #>> '{user,user_metadata,phone_verification_challenge}', '');
  v_challenge uuid;
  v_phone text;
  v_norm text;
  v_row_id uuid;
begin
  -- OAuth signups: explicit allow-list only (the providers enabled in
  -- auth config). Anything else - including anonymous - is refused.
  if v_provider is not null and v_provider <> 'email' then
    if v_provider in ('google') then
      return '{}'::jsonb;
    end if;
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'SIGNUP_PROVIDER_NOT_ALLOWED: this sign-in method is not available.',
        'http_code', 400
      )
    );
  end if;

  -- Conflicting phone fields: refuse rather than guess.
  if v_meta_phone is not null
     and v_user_phone is not null
     and public._normalize_egypt_phone(v_meta_phone) <> public._normalize_egypt_phone(v_user_phone) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_MISMATCH: conflicting phone numbers in the signup request.',
        'http_code', 400
      )
    );
  end if;

  v_phone := coalesce(v_meta_phone, v_user_phone);

  -- Email path with no phone: would bypass the phone-or-Google rule.
  if v_phone is null then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'EMAIL_SIGNUP_NOT_ALLOWED: sign up with Google or with a WhatsApp-verified phone number.',
        'http_code', 400
      )
    );
  end if;

  v_norm := public._normalize_egypt_phone(v_phone);

  -- Server-side shape enforcement: Egyptian mobile only, canonical form.
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_INVALID: enter a valid Egyptian mobile number.',
        'http_code', 400
      )
    );
  end if;

  -- The auth email must be exactly the canonical technical email for the
  -- phone being proven, so the email can never point at a different
  -- identity than the verified phone.
  if v_email <> 'phone_' || substring(v_norm from 2) || '@delwaqty.app' then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_EMAIL_MISMATCH: the account identifier does not match the verified phone.',
        'http_code', 400
      )
    );
  end if;

  -- One account per normalized phone.
  if exists (
    select 1 from public.users
     where public._normalize_egypt_phone(phone) = v_norm
  ) then
    return jsonb_build_object(
      'error', jsonb_build_object(
        'message', 'PHONE_ALREADY_REGISTERED: this phone number already has an account. Log in instead.',
        'http_code', 400
      )
    );
  end if;

  if v_challenge_text is not null then
    begin
      v_challenge := v_challenge_text::uuid;
    exception when others then
      v_challenge := null;
    end;
  end if;

  if v_challenge is not null then
    -- Atomic one-time consume: only an unconsumed, fresh, webhook-verified
    -- register row for THIS phone and THIS challenge authorizes the
    -- signup, and it can never authorize a second one.
    update public.whatsapp_otp_verifications
       set consumed_at = now()
     where challenge = v_challenge
       and phone = v_norm
       and purpose = 'register'
       and verified = true
       and verified_via = 'webhook'
       and consumed_at is null
       and created_at > now() - interval '1 hour'
    returning id into v_row_id;

    if v_row_id is not null then
      return '{}'::jsonb;
    end if;

    -- Rejection reason as a stable token the client switches on
    -- (AuthException.message). Only a row for THIS phone + purpose can
    -- produce CONSUMED/EXPIRED, so this reveals nothing about others.
    if exists (
      select 1 from public.whatsapp_otp_verifications
       where challenge = v_challenge and phone = v_norm and purpose = 'register'
         and consumed_at is not null
    ) then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'CHALLENGE_CONSUMED: this verification was already used. Request a new code.',
          'http_code', 400
        )
      );
    end if;

    if exists (
      select 1 from public.whatsapp_otp_verifications
       where challenge = v_challenge and phone = v_norm and purpose = 'register'
         and created_at <= now() - interval '1 hour'
    ) then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'CHALLENGE_EXPIRED: this verification is older than one hour. Request a new code.',
          'http_code', 400
        )
      );
    end if;
  end if;

  -- 466: with signup_phone_mode = 'password' the WhatsApp proof is not
  -- required. The account is created unconfirmed (users.phone_verified =
  -- false, set by users_set_phone_verified) and confirmed at the first
  -- order. A global breaker caps unconfirmed signups per hour.
  if public.signup_phone_mode() = 'password' then
    if (select count(*) from public.users
         where phone_verified = false
           and created_at > now() - interval '1 hour')
       >= public._signup_unverified_hourly_cap() then
      return jsonb_build_object(
        'error', jsonb_build_object(
          'message', 'SIGNUP_BUSY: too many new accounts right now. Try again later.',
          'http_code', 429
        )
      );
    end if;
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'error', jsonb_build_object(
      'message', 'PHONE_NOT_VERIFIED: verify this phone number via WhatsApp before creating the account.',
      'http_code', 400
    )
  );
end;
$function$
;
GRANT EXECUTE ON FUNCTION public.before_user_created_phone_guard(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.before_user_created_phone_guard(jsonb) FROM authenticated, anon, public;

-- limits for unconfirmed customers -----------------------------------------
CREATE OR REPLACE FUNCTION public.orders_unverified_limits()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ok boolean;
  v_open int;
BEGIN
  SELECT phone_verified INTO v_ok FROM public.users WHERE id = NEW.user_id;
  IF COALESCE(v_ok, true) THEN
    RETURN NEW;
  END IF;
  IF COALESCE(NEW.payment_method, 'cash') <> 'cash' OR COALESCE(NEW.platform_credit_applied, 0) <> 0 THEN
    RAISE EXCEPTION 'PHONE_NOT_CONFIRMED: cash only until your phone number is confirmed' USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO v_open FROM public.orders
   WHERE user_id = NEW.user_id AND status NOT IN ('delivered', 'cancelled', 'rejected', 'completed');
  IF v_open >= 2 THEN
    RAISE EXCEPTION 'PHONE_NOT_CONFIRMED: at most 2 open orders until your phone number is confirmed' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.orders_unverified_limits() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS orders_unverified_limits ON public.orders;
CREATE TRIGGER orders_unverified_limits BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.orders_unverified_limits();

-- confirm after the call -------------------------------------------------------
CREATE OR REPLACE FUNCTION public._can_confirm_customer_phone(p_user_id uuid, p_actor uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p_actor IS NOT NULL AND (
    public.is_admin(p_actor)
    OR EXISTS (
      SELECT 1 FROM public.orders o
       WHERE o.user_id = p_user_id
         AND (o.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = p_actor)
              OR public._owns_merchant_row(o.merchant_id)))
    OR EXISTS (
      SELECT 1 FROM public.rides r
       WHERE r.rider_id = p_user_id
         AND r.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = p_actor)));
$$;
REVOKE ALL ON FUNCTION public._can_confirm_customer_phone(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- true only for a caller who may confirm AND a customer who is unconfirmed:
-- drives the "number not confirmed, call the customer" banner.
CREATE OR REPLACE FUNCTION public.customer_phone_needs_confirmation(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public._can_confirm_customer_phone(p_user_id, auth.uid())
     AND EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND phone_verified = false);
$$;
REVOKE ALL ON FUNCTION public.customer_phone_needs_confirmation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.customer_phone_needs_confirmation(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_customer_phone(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF NOT public._can_confirm_customer_phone(p_user_id, v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;
  UPDATE public.users SET phone_verified = true WHERE id = p_user_id AND phone_verified = false;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'already', true);
  END IF;
  INSERT INTO public.audit_log (actor, action, resource, resource_id, after, reason)
  VALUES (v_uid, 'confirm_customer_phone', 'users', p_user_id::text,
          jsonb_build_object('phone_verified', true), 'phone confirmed after call');
  RETURN jsonb_build_object('ok', true);
END;
$$;
REVOKE ALL ON FUNCTION public.confirm_customer_phone(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_customer_phone(uuid) TO authenticated, service_role;

-- courier rides: same limits as orders for unconfirmed customers ----------------
-- Decision: courier rides are allowed but limited (cash only, at most 2 open
-- rides) until the phone is confirmed. The driver on the ride can confirm.
CREATE OR REPLACE FUNCTION public.rides_unverified_limits()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ok boolean;
  v_open int;
BEGIN
  SELECT phone_verified INTO v_ok FROM public.users WHERE id = NEW.rider_id;
  IF COALESCE(v_ok, true) THEN
    RETURN NEW;
  END IF;
  IF COALESCE(NEW.payment_method, 'cash') <> 'cash' THEN
    RAISE EXCEPTION 'PHONE_NOT_CONFIRMED: cash only until your phone number is confirmed' USING ERRCODE = 'P0001';
  END IF;
  SELECT count(*) INTO v_open FROM public.rides
   WHERE rider_id = NEW.rider_id AND status IN ('searching', 'matched', 'arrived', 'inTrip');
  IF v_open >= 2 THEN
    RAISE EXCEPTION 'PHONE_NOT_CONFIRMED: at most 2 open rides until your phone number is confirmed' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.rides_unverified_limits() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS rides_unverified_limits ON public.rides;
CREATE TRIGGER rides_unverified_limits BEFORE INSERT ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.rides_unverified_limits();

-- forgotten password while WhatsApp is blocked ----------------------------------
-- An admin who has spoken to the account holder issues a one-time 8-digit
-- code (valid 30 minutes, 5 wrong tries, at most 3 issues per account per
-- day). Only a hash is stored. The edge function recovery-code-reset consumes
-- it, sets the new password and revokes sessions. Audited, code never logged.
CREATE TABLE IF NOT EXISTS public.account_recovery_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  issued_by uuid,
  attempts int NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_recovery_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_recovery_codes FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_issue_recovery_code(p_phone text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_user uuid;
  v_n int;
  v_code text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;
  SELECT count(*) INTO v_n FROM public.users WHERE public._normalize_egypt_phone(phone) = v_norm;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NO_UNIQUE_ACCOUNT');
  END IF;
  SELECT id INTO v_user FROM public.users WHERE public._normalize_egypt_phone(phone) = v_norm;
  SELECT count(*) INTO v_n FROM public.account_recovery_codes
   WHERE user_id = v_user AND created_at > now() - interval '24 hours';
  IF v_n >= 3 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TOO_MANY_CODES');
  END IF;
  UPDATE public.account_recovery_codes SET used_at = now() WHERE user_id = v_user AND used_at IS NULL;
  v_code := lpad((floor(random() * 100000000))::bigint::text, 8, '0');
  INSERT INTO public.account_recovery_codes (user_id, code_hash, issued_by, expires_at)
  VALUES (v_user, encode(sha256(convert_to(v_user::text || ':' || v_code, 'utf8')), 'hex'), auth.uid(), now() + interval '30 minutes');
  INSERT INTO public.audit_log (actor, action, resource, resource_id, reason)
  VALUES (auth.uid(), 'issue_recovery_code', 'users', v_user::text, 'password recovery code issued');
  RETURN jsonb_build_object('ok', true, 'code', v_code, 'expires_in_minutes', 30);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_issue_recovery_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_issue_recovery_code(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.consume_recovery_code(p_phone text, p_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_user uuid;
  v_n int;
  v_row public.account_recovery_codes%rowtype;
BEGIN
  IF p_code IS NULL OR p_code !~ '^[0-9]{8}$' THEN
    RETURN NULL;
  END IF;
  SELECT count(*) INTO v_n FROM public.users WHERE public._normalize_egypt_phone(phone) = v_norm;
  IF v_n <> 1 THEN
    RETURN NULL;
  END IF;
  SELECT id INTO v_user FROM public.users WHERE public._normalize_egypt_phone(phone) = v_norm;
  SELECT * INTO v_row FROM public.account_recovery_codes
   WHERE user_id = v_user AND used_at IS NULL AND expires_at > now() AND attempts < 5
   ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF v_row.id IS NULL THEN
    RETURN NULL;
  END IF;
  IF v_row.code_hash <> encode(sha256(convert_to(v_user::text || ':' || p_code, 'utf8')), 'hex') THEN
    UPDATE public.account_recovery_codes SET attempts = attempts + 1 WHERE id = v_row.id;
    RETURN NULL;
  END IF;
  UPDATE public.account_recovery_codes SET used_at = now() WHERE id = v_row.id;
  INSERT INTO public.audit_log (actor, action, resource, resource_id, reason)
  VALUES (NULL, 'recovery_code_used', 'users', v_user::text, 'password reset with admin recovery code');
  RETURN v_user;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_recovery_code(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_recovery_code(text, text) TO service_role;
