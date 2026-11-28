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
CREATE OR REPLACE FUNCTION public.confirm_customer_phone(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF public.is_admin() THEN
    v_allowed := true;
  ELSE
    v_allowed := EXISTS (
      SELECT 1 FROM public.orders o
       WHERE o.user_id = p_user_id
         AND (o.driver_id = v_uid OR public._owns_merchant_row(o.merchant_id)));
  END IF;
  IF NOT v_allowed THEN
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
