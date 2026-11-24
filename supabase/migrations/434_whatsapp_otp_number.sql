-- 434: dedicated WhatsApp OTP destination number, decoupled from support_phone.
--
-- request_whatsapp_otp sent customers to platform_settings.support_phone -
-- the customer SUPPORT contact. The OTP destination is infrastructure: the
-- Meta Cloud API number the whatsapp-webhook watches. The two change on
-- different schedules for different reasons (support line vs. Cloud API
-- registration), and conflating them is what left OTP pointed at a number
-- Meta cannot see.
--
-- 1) platform_settings.whatsapp_otp_number: E.164, ANY country - Meta's
--    free Cloud API test number is a +1 number, which is the interim
--    destination until the platform's dedicated Egyptian SIM is registered
--    (see docs/whatsapp-otp-inbound.md).
-- 2) request_whatsapp_otp reads ONLY the override. The 414 fallback to
--    support_phone is deliberately REMOVED: it preserved existing prod
--    behavior (414 returned support_phone as the destination), but the
--    current support_phone value is the platform's protected support
--    line, which must never be an OTP destination, and that path never
--    delivered webhook events anyway (see the runbook root cause), so
--    removing it cannot break a working login. Unset override now fails
--    closed (WHATSAPP_NOT_CONFIGURED).
-- 3) An override that is set but malformed also fails closed.
-- 4) whatsapp_otp_number joins the owner-only guard
--    (guard_platform_settings_owner_fields, 393 pattern): it steers where
--    customers send OTP codes, so country admins cannot repoint it.
--
-- Pre-image guard (A0, 414 pattern): aborts without mutation unless the
-- live request_whatsapp_otp is EXACTLY the 414 body (md5 pinned), still
-- carries the 414 per-IP guard, has the pinned owner/ACL/security
-- properties, guard_platform_settings_owner_fields is at its pinned
-- pre-image, and the column is absent.

BEGIN;

DO $a0$
DECLARE
  v_def text;
  v_proc record;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'platform_settings'
                AND column_name = 'whatsapp_otp_number') THEN
    RAISE EXCEPTION 'platform_settings.whatsapp_otp_number already exists; aborting';
  END IF;

  SELECT pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)
    INTO v_def;
  IF v_def IS NULL THEN
    RAISE EXCEPTION 'request_whatsapp_otp missing; aborting';
  END IF;
  IF md5(v_def) <> '2e2f0086c65bac716c937af718debf86' THEN
    RAISE EXCEPTION '434 precondition failed: request_whatsapp_otp drifted from the pinned 414 pre-image';
  END IF;
  IF v_def NOT LIKE '%_lookup_rate_allow%' THEN
    RAISE EXCEPTION '434 precondition failed: 414 per-IP guard missing from live body';
  END IF;
  SELECT prosecdef, proconfig::text AS proconfig, proacl,
         pg_get_userbyid(proowner) AS owner
    INTO v_proc
    FROM pg_proc WHERE oid = 'public.request_whatsapp_otp(text,text)'::regprocedure;
  IF NOT v_proc.prosecdef
     OR v_proc.proconfig <> '{search_path=public}'
     OR v_proc.owner <> 'postgres' THEN
    RAISE EXCEPTION '434 precondition failed: request_whatsapp_otp properties drifted (secdef/search_path/owner)';
  END IF;
  -- ACL as a SET (grant order differs across rebuilds; membership must not).
  IF (SELECT coalesce(array_agg(g ORDER BY g), '{}'::text[]) FROM (
        SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END AS g
          FROM aclexplode(v_proc.proacl) a WHERE a.privilege_type = 'EXECUTE') z)
     <> '{anon,authenticated,postgres,service_role}'::text[] THEN
    RAISE EXCEPTION '434 precondition failed: request_whatsapp_otp EXECUTE ACL drifted';
  END IF;

  IF md5(pg_get_functiondef('public.guard_platform_settings_owner_fields()'::regprocedure))
       <> '797da2f7a1fb8c6eaf14b33121345bb8' THEN
    RAISE EXCEPTION '434 precondition failed: guard_platform_settings_owner_fields drifted from its pinned pre-image';
  END IF;
END
$a0$;

ALTER TABLE public.platform_settings
  ADD COLUMN whatsapp_otp_number text;

COMMENT ON COLUMN public.platform_settings.whatsapp_otp_number IS
  'E.164 number that receives WhatsApp OTP codes (the Meta Cloud API number whatsapp-webhook watches). Required for WhatsApp OTP: request_whatsapp_otp fails closed (WHATSAPP_NOT_CONFIGURED) while unset. Owner-only (guard_platform_settings_owner_fields).';

CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
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

  -- 434: the OTP destination is ONLY the dedicated override. No fallback
  -- to support_phone: that line is the customer support contact and must
  -- never receive OTP codes.
  select nullif(btrim(coalesce(whatsapp_otp_number, '')), '')
    into v_number
    from public.platform_settings where id='default';

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
    'whatsapp_number', v_number,
    'expires_in_seconds', 600
  );
end;
$function$
;

-- The OTP destination steers where customers send their codes: owner-only,
-- same pattern as the 393 suspension durations.
CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND NEW.require_provider_documents IS DISTINCT FROM OLD.require_provider_documents THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    ELSIF TG_OP = 'INSERT' AND NEW.require_provider_documents IS TRUE THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    END IF;
    -- 393: cancellation/refusal suspension durations are owner-only.
    IF NEW.cancel_suspension_days IS DISTINCT FROM OLD.cancel_suspension_days THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the cancellation suspension duration';
      END IF;
    END IF;
    IF NEW.refusal_suspension_days IS DISTINCT FROM OLD.refusal_suspension_days THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the refusal suspension duration';
      END IF;
    END IF;
    -- 434: the WhatsApp OTP destination is owner-only.
    IF NEW.whatsapp_otp_number IS DISTINCT FROM OLD.whatsapp_otp_number THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the WhatsApp OTP destination';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- Post-checks: the 414 per-IP guard survived the rewrite, function
-- properties/ACL are unchanged, the column exists, the guard covers it.
DO $v434$
DECLARE
  v_def text;
  v_proc record;
BEGIN
  SELECT pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)
    INTO v_def;
  IF v_def NOT LIKE '%_lookup_rate_allow%' THEN
    RAISE EXCEPTION '434 post-check failed: per-IP guard missing from new body';
  END IF;
  IF v_def NOT LIKE '%whatsapp_otp_number%' THEN
    RAISE EXCEPTION '434 post-check failed: override not wired into new body';
  END IF;
  SELECT prosecdef, proconfig::text AS proconfig, proacl,
         pg_get_userbyid(proowner) AS owner
    INTO v_proc
    FROM pg_proc WHERE oid = 'public.request_whatsapp_otp(text,text)'::regprocedure;
  IF NOT v_proc.prosecdef
     OR v_proc.proconfig <> '{search_path=public}'
     OR v_proc.owner <> 'postgres' THEN
    RAISE EXCEPTION '434 post-check failed: function properties changed';
  END IF;
  IF (SELECT coalesce(array_agg(g ORDER BY g), '{}'::text[]) FROM (
        SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE a.grantee::regrole::text END AS g
          FROM aclexplode(v_proc.proacl) a WHERE a.privilege_type = 'EXECUTE') z)
     <> '{anon,authenticated,postgres,service_role}'::text[] THEN
    RAISE EXCEPTION '434 post-check failed: EXECUTE ACL changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'platform_settings'
                    AND column_name = 'whatsapp_otp_number') THEN
    RAISE EXCEPTION '434 post-check failed: column missing';
  END IF;
  IF pg_get_functiondef('public.guard_platform_settings_owner_fields()'::regprocedure)
       NOT LIKE '%whatsapp_otp_number%' THEN
    RAISE EXCEPTION '434 post-check failed: owner guard does not cover whatsapp_otp_number';
  END IF;
END
$v434$;

COMMIT;
