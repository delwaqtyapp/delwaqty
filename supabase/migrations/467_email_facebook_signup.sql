-- NOTE: this migration supersedes the header of 441 ("login identifiers are username or phone ONLY, email dropped"); a real email is a login identifier again (owner decision 2026-11-28). 441 itself is already applied and is not edited.
-- 467 (DRAFT, DO NOT APPLY): signup by EMAIL or FACEBOOK, behind server flags.
-- Owner decision 2026-11-28 18:07: phone-number signup is removed; email
-- (activation link from our own sender) and Facebook (when the Meta app is
-- ready) replace it; Google stays. Phone+password mode (#138) is shelved.
--
--  1. auth_methods(): anon-callable flags the client reads to show buttons.
--     feature_flags.auth_methods = {"email":bool,"facebook":bool,"google":bool}
--     Defaults (flag absent) = today: google only. Flip with no new build.
--  2. before_user_created_phone_guard becomes a wrapper:
--       * provider google  -> allowed (as before)
--       * provider facebook -> allowed only when the facebook flag is on
--       * email signup with a REAL email (not the technical @delwaqty.app
--         identifier) -> allowed only when the email flag is on, with an
--         hourly breaker; phone is NOT required.
--       * everything else -> the unchanged legacy phone/WhatsApp guard
--         (kept so build 16 and a returning WhatsApp path behave as today).
--  3. Email as a login identifier again (auth_login_resolve_email): only a
--     real, existing account email resolves; same anti-enumeration path.
-- Re-runnable.

CREATE OR REPLACE FUNCTION public.auth_methods()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT jsonb_build_object(
    'email', COALESCE(CASE WHEN feature_flags #>> '{auth_methods,email}' IN ('true','false') THEN (feature_flags #>> '{auth_methods,email}')::boolean END, false),
    'facebook', COALESCE(CASE WHEN feature_flags #>> '{auth_methods,facebook}' IN ('true','false') THEN (feature_flags #>> '{auth_methods,facebook}')::boolean END, false),
    'google', COALESCE(CASE WHEN feature_flags #>> '{auth_methods,google}' IN ('true','false') THEN (feature_flags #>> '{auth_methods,google}')::boolean END, true))
    FROM public.platform_settings WHERE id = 'default'
  UNION ALL SELECT '{"email":false,"facebook":false,"google":true}'::jsonb
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.auth_methods() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auth_methods() TO anon, authenticated, service_role, supabase_auth_admin;

CREATE OR REPLACE FUNCTION public._email_signup_hourly_cap()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT LEAST(GREATEST((feature_flags ->> 'email_signup_per_hour')::int, 1), 1000)
       FROM public.platform_settings
      WHERE id = 'default' AND (feature_flags ->> 'email_signup_per_hour') ~ '^[0-9]+$'),
    60);
$$;
REVOKE ALL ON FUNCTION public._email_signup_hourly_cap() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._email_signup_hourly_cap() TO service_role, supabase_auth_admin;

-- keep the legacy guard under a new name exactly once
DO $$
BEGIN
  IF to_regprocedure('public._legacy_phone_signup_guard(jsonb)') IS NULL THEN
    ALTER FUNCTION public.before_user_created_phone_guard(jsonb) RENAME TO _legacy_phone_signup_guard;
  END IF;
END $$;
REVOKE ALL ON FUNCTION public._legacy_phone_signup_guard(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._legacy_phone_signup_guard(jsonb) TO supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.before_user_created_phone_guard(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_provider text := nullif(event #>> '{user,app_metadata,provider}', '');
  v_email text := lower(coalesce(event #>> '{user,email}', ''));
  v_meta_phone text := nullif(event #>> '{user,user_metadata,phone}', '');
  v_user_phone text := nullif(event #>> '{user,phone}', '');
  v_methods jsonb := public.auth_methods();
  v_recent int;
BEGIN
  IF v_provider = 'facebook' THEN
    IF (v_methods ->> 'facebook')::boolean THEN
      RETURN '{}'::jsonb;
    END IF;
    RETURN jsonb_build_object('error', jsonb_build_object(
      'message', 'SIGNUP_PROVIDER_NOT_ALLOWED: this sign-in method is not available.', 'http_code', 400));
  END IF;

  IF (v_provider IS NULL OR v_provider = 'email')
     AND v_meta_phone IS NULL AND v_user_phone IS NULL
     AND v_email !~ '^phone_[0-9]+@delwaqty\.app$' THEN
    IF NOT (v_methods ->> 'email')::boolean THEN
      RETURN jsonb_build_object('error', jsonb_build_object(
        'message', 'EMAIL_SIGNUP_NOT_ALLOWED: email signup is not open yet.', 'http_code', 400));
    END IF;
    IF v_email !~ '^[a-z0-9._%+-]{1,64}@[a-z0-9.-]{1,190}\.[a-z]{2,24}$'
       OR v_email LIKE '%@delwaqty.app' OR v_email LIKE '%@anonymized.invalid' THEN
      RETURN jsonb_build_object('error', jsonb_build_object(
        'message', 'EMAIL_INVALID: enter a valid email address.', 'http_code', 400));
    END IF;
    -- #375: count only still-unconfirmed email signups, so Google/Facebook/
    -- phone users and confirmed members never use up the email budget.
    -- (GoTrue's own per-IP sign-up rate limit covers a single noisy IP.)
    SELECT count(*) INTO v_recent FROM auth.users
     WHERE created_at > now() - interval '1 hour'
       AND email_confirmed_at IS NULL
       AND COALESCE(raw_app_meta_data ->> 'provider', 'email') = 'email';
    IF v_recent >= public._email_signup_hourly_cap() THEN
      RETURN jsonb_build_object('error', jsonb_build_object(
        'message', 'SIGNUP_BUSY: too many signups right now, try again later.', 'http_code', 429));
    END IF;
    RETURN '{}'::jsonb;
  END IF;

  RETURN public._legacy_phone_signup_guard(event);
END;
$function$;
REVOKE ALL ON FUNCTION public.before_user_created_phone_guard(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.before_user_created_phone_guard(jsonb) TO supabase_auth_admin;

-- email as a login identifier (real, existing accounts only) -------------------
CREATE OR REPLACE FUNCTION public.auth_login_resolve_email(p_identifier text)
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

  IF position('@' IN v_id) > 0 THEN
    SELECT email INTO v_email
      FROM public.users
     WHERE lower(email) = lower(v_id)
       AND account_status <> 'deactivated'
       AND email NOT LIKE '%@anonymized.invalid'
       AND email NOT LIKE 'phone\_%@delwaqty.app'
     LIMIT 1;
    RETURN v_email;
  END IF;

  v_digits := regexp_replace(v_id, '[^0-9]', '', 'g');
  IF length(v_digits) >= 9 AND v_id ~ '^[+0-9 ()-]+$' THEN
    v_norm := public._normalize_egypt_phone(v_id);
    v_last10 := right(v_digits, 10);
    SELECT email INTO v_email
      FROM public.users
     WHERE account_status <> 'deactivated'
       AND email IS NOT NULL AND email <> ''
       AND email NOT LIKE '%@anonymized.invalid'
       AND (public._normalize_egypt_phone(phone) = v_norm
            OR right(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'), 10) = v_last10)
     ORDER BY created_at DESC
     LIMIT 1;
    RETURN v_email;
  END IF;

  v_uname := lower(v_id);
  SELECT email INTO v_email
    FROM public.users
   WHERE username IS NOT NULL AND lower(username) = v_uname
     AND account_status <> 'deactivated'
     AND email NOT LIKE '%@anonymized.invalid'
   LIMIT 1;
  RETURN v_email;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.auth_login_resolve_email(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auth_login_resolve_email(text) TO service_role;
