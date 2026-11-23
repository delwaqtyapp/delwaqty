-- 414: red team round 1, items (7) and (8).
-- (7) request_whatsapp_otp gains a per-IP hourly bucket cap using the same
--     primitive the lookup RPCs use (_lookup_rate_allow over
--     identifier_lookup_attempts), in its own 'otp-ip:' namespace. The
--     per-phone 3-per-10-minutes cap and the fail-closed
--     WHATSAPP_NOT_CONFIGURED gate from 403 are unchanged.
-- (8) coupons and promo_codes were readable by anon through the public
--     SELECT policies. Public read is now authenticated-only and still
--     limited to active rows; admin manage policies are untouched. The
--     customer apps read coupons as signed-in users and apply them
--     server-side through redeem_coupon (SECURITY DEFINER), so legitimate
--     coupon flows keep working.
BEGIN;

-- Precondition: 403's definition must still be live so this migration can
-- never silently undo a concurrent change.
DO $pre414$
BEGIN
  IF md5(pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)) <> 'b11340bf61ad20e0a89b0dcde0ce7ccf' THEN
    RAISE EXCEPTION '414 precondition failed: request_whatsapp_otp drifted from 403';
  END IF;
END;
$pre414$;

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
  -- Egyptian mobile only, canonical shape (same rule the signup hook
  -- enforces): no proof can ever be requested for a non-Egyptian or
  -- malformed number.
  if v_norm !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  end if;

  select nullif(btrim(support_phone), '') into v_support_phone
    from public.platform_settings where id='default';
  if v_support_phone is null or v_support_phone !~ '^\+201[0-9]{9}$' then
    return jsonb_build_object('ok', false, 'code', 'WHATSAPP_NOT_CONFIGURED');
  end if;

  select count(*) into v_recent
    from public.whatsapp_otp_verifications
   where phone = v_norm
     and created_at > now() - interval '10 minutes';
  if v_recent >= 3 then
    return jsonb_build_object('ok', false, 'code', 'RATE_LIMITED');
  end if;

  -- 414: per-IP hourly bucket, same primitive the lookup RPCs use
  -- (_lookup_rate_allow over identifier_lookup_attempts), in its own
  -- 'otp-ip:' namespace so OTP attempts share no budget with lookups.
  -- Stops a single client IP from spraying OTP requests across many
  -- phone numbers; the per-phone 3-per-10-minutes cap above is unchanged.
  if not public._lookup_rate_allow('otp-ip:' || public._lookup_caller_ip(), 30) then
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
    'whatsapp_number', v_support_phone,
    'expires_in_seconds', 600
  );
end;
$function$
;

-- (8) Public promo reads are authenticated-only; inactive rows stay hidden.
DROP POLICY IF EXISTS "Coupons are viewable by everyone" ON public.coupons;
CREATE POLICY "coupons authenticated read" ON public.coupons
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "promo public read" ON public.promo_codes;
CREATE POLICY "promo authenticated read" ON public.promo_codes
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (is_active = true);

DO $verify414$
BEGIN
  IF md5(pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)) <> '2e2f0086c65bac716c937af718debf86' THEN
    RAISE EXCEPTION '414 definition mismatch: request_whatsapp_otp';
  END IF;
END;
$verify414$;

COMMIT;
