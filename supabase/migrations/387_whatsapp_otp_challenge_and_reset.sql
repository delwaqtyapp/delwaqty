-- 387: challenge-bound WhatsApp OTP + password-reset authorization.
--
-- Review feedback on 386: whatsapp_otp_status(p_phone, p_purpose) ignored
-- the purpose, matched any latest verified row regardless of age or path,
-- and was callable by anyone who knows a phone number — usable as an
-- oracle and NOT a proof strong enough to authorize a password reset.
--
-- This migration binds every OTP request to an unguessable per-request
-- challenge (uuid) that is returned only to the requesting client:
--   1) whatsapp_otp_verifications gains challenge + consumed_at columns.
--   2) request_whatsapp_otp stores and returns the challenge.
--   3) whatsapp_otp_status is replaced with a challenge-bound, purpose-
--      filtered, freshness-checked version. The old (text, text) form is
--      dropped so no unauthenticated status oracle remains.
--   4) A verified, unconsumed challenge with purpose 'password_reset' is
--      the authorization ticket the whatsapp-password-reset edge function
--      checks before calling the admin API. One-time use via consumed_at.

ALTER TABLE public.whatsapp_otp_verifications
  ADD COLUMN IF NOT EXISTS challenge uuid,
  ADD COLUMN IF NOT EXISTS consumed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_whatsapp_otp_challenge
  ON public.whatsapp_otp_verifications (challenge);

-- (2) request: bind a per-request challenge, return it to the caller only.
CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
  v_support_phone text;
  v_recent int;
  v_challenge uuid := gen_random_uuid();
begin
  if length(v_norm) < 10 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  select count(*) into v_recent
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and created_at > now() - interval '10 minutes';
  if v_recent >= 3 then
    return jsonb_build_object('ok', false, 'code', 'RATE_LIMITED');
  end if;

  update public.whatsapp_otp_verifications
     set expires_at = now()
   where phone = v_norm
     and expires_at > now()
     and verified = false;

  v_otp := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  insert into public.whatsapp_otp_verifications (phone, otp_code, purpose, verified, expires_at, challenge)
  values (v_norm, v_otp, coalesce(nullif(btrim(p_purpose), ''), 'register'), false, now() + interval '10 minutes', v_challenge);

  select coalesce(nullif(support_phone, ''), '+201000000000')
    into v_support_phone
    from public.platform_settings
   where id = 'default';

  return jsonb_build_object(
    'ok', true,
    'phone', v_norm,
    'otp_code', v_otp,
    'challenge', v_challenge,
    'whatsapp_number', coalesce(v_support_phone, '+201000000000'),
    'expires_in_seconds', 600
  );
end;
$function$
;
REVOKE ALL ON FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text) TO postgres;
GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text) TO service_role;

-- (3) challenge-bound status. Drop the unauthenticated (text, text) form.
DROP FUNCTION IF EXISTS public.whatsapp_otp_status(text, text);

CREATE OR REPLACE FUNCTION public.whatsapp_otp_status(p_phone text, p_purpose text, p_challenge uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_purpose text := coalesce(nullif(btrim(p_purpose), ''), 'register');
  v_row public.whatsapp_otp_verifications%rowtype;
begin
  if length(v_norm) < 10 or p_challenge is null then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  -- Only the row that belongs to THIS request. No row => generic 'none',
  -- so the RPC reveals nothing about other people's verifications.
  select * into v_row
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and purpose = v_purpose
     and challenge = p_challenge
   limit 1;

  if v_row.id is null then
    return jsonb_build_object('ok', true, 'status', 'none');
  end if;

  -- Verified: must be webhook/service verified, fresh, and unconsumed.
  if v_row.verified
     and v_row.verified_via in ('webhook', 'service')
     and v_row.consumed_at is null
     and v_row.created_at > now() - interval '1 hour' then
    return jsonb_build_object('ok', true, 'status', 'verified', 'phone', v_norm);
  end if;

  if v_row.expires_at <= now() then
    return jsonb_build_object('ok', true, 'status', 'expired');
  end if;

  if v_row.verified then
    -- verified but stale or consumed: treat as expired for the client
    return jsonb_build_object('ok', true, 'status', 'expired');
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'pending',
    'expires_in_seconds', greatest(0, floor(extract(epoch from (v_row.expires_at - now())))::int)
  );
end;
$function$
;
REVOKE ALL ON FUNCTION public.whatsapp_otp_status(text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.whatsapp_otp_status(text, text, uuid) TO service_role;

-- (4) one-time ticket check for the reset edge function. Service-role only:
-- the edge function calls it; it validates and CONSUMES the challenge
-- atomically, returning the target auth user id when authorized.
CREATE OR REPLACE FUNCTION public.consume_whatsapp_reset_challenge(p_phone text, p_challenge uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_row public.whatsapp_otp_verifications%rowtype;
  v_user_id uuid;
begin
  select * into v_row
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and purpose = 'password_reset'
     and challenge = p_challenge
     and verified = true
     and verified_via in ('webhook', 'service')
     and consumed_at is null
     and created_at > now() - interval '1 hour'
   order by created_at desc
   limit 1
   for update;

  if v_row.id is null then
    return null;
  end if;

  select id into v_user_id
    from public.users
   where public._normalize_egypt_phone(phone) = v_norm
   order by created_at asc
   limit 1;

  if v_user_id is null then
    return null;
  end if;

  update public.whatsapp_otp_verifications
     set consumed_at = now()
   where id = v_row.id;

  return v_user_id;
end;
$function$
;
REVOKE ALL ON FUNCTION public.consume_whatsapp_reset_challenge(text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_whatsapp_reset_challenge(text, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.consume_whatsapp_reset_challenge(text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.consume_whatsapp_reset_challenge(text, uuid) TO service_role;
