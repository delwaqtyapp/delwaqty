-- 429: dedicated WhatsApp OTP destination number, decoupled from support_phone.
--
-- request_whatsapp_otp sent customers to platform_settings.support_phone —
-- the customer SUPPORT contact. The OTP destination is infrastructure: the
-- Meta Cloud API number the whatsapp-webhook watches. The two change on
-- different schedules for different reasons (support line vs. Cloud API
-- registration), and conflating them is what left OTP pointed at a number
-- Meta cannot see.
--
-- 1) platform_settings.whatsapp_otp_number: E.164, ANY country — Meta's
--    free Cloud API test number is a +1 number, which is the interim
--    destination until the platform's dedicated Egyptian SIM is registered
--    (see docs/whatsapp-otp-inbound.md).
-- 2) request_whatsapp_otp prefers the override and falls back to
--    support_phone, so installs keep working while the override is unset.
-- 3) An override that is set but malformed fails closed
--    (WHATSAPP_NOT_CONFIGURED): silently falling back would send
--    customers' codes to a phone nobody watches.

ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS whatsapp_otp_number text;

COMMENT ON COLUMN public.platform_settings.whatsapp_otp_number IS
  'E.164 number that receives WhatsApp OTP codes (the Meta Cloud API number whatsapp-webhook watches). NULL falls back to support_phone.';

CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
  v_override text;
  v_support_phone text;
  v_number text;
  v_recent int;
  v_challenge uuid := gen_random_uuid();
begin
  -- Egyptian mobile only, canonical shape (same rule the signup hook
  -- enforces): no proof can ever be requested for a non-Egyptian or
  -- malformed number.
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  select nullif(btrim(coalesce(whatsapp_otp_number, '')), ''),
         nullif(btrim(coalesce(support_phone, '')), '')
    into v_override, v_support_phone
    from public.platform_settings where id='default';

  -- Override wins; NULL override falls back to the support contact.
  v_number := coalesce(v_override, v_support_phone);

  -- E.164 shape. An Egyptian-only rule would reject Meta's interim +1
  -- Cloud API test number; the sender's phone above stays Egyptian-only.
  if v_number is null or v_number !~ '^\+[1-9][0-9]{7,14}$' then
    return jsonb_build_object('ok', false, 'code', 'WHATSAPP_NOT_CONFIGURED');
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


  return jsonb_build_object(
    'ok', true,
    'phone', v_norm,
    'otp_code', v_otp,
    'challenge', v_challenge,
    'whatsapp_number', v_number,
    'expires_in_seconds', 600
  );
end;
$function$
;
