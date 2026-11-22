-- 382: license_issue trial duration fixed server-side (code review HIGH #40).
-- Before: a merchant self-issuing a trial could pass any positive p_days and
-- get years of free PRO. Now: trial always 30 days; p_days honored only on
-- admin-issued paid plans and bounded to 1..400 (INVALID_DAYS outside).

CREATE OR REPLACE FUNCTION public.cashier_license_issue(p_merchant_id uuid, p_plan text, p_days integer DEFAULT NULL::integer, p_pro boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_days integer;
  v_payload text;
  v_sig text;
  v_key text;
  v_id uuid;
  v_expires timestamptz;
  v_pro boolean;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_plan NOT IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime') THEN
    RAISE EXCEPTION 'Invalid plan %', p_plan;
  END IF;
  -- Review #27: merchant owners self-issue the trial only. Paid plans are
  -- issued by an admin after payment is collected (payment gate).
  IF p_plan <> 'trial' AND NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'PAID_PLANS_REQUIRE_ADMIN';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  -- Trial runs with PRO enabled so merchants can try everything (pricing v1);
  -- paid plans get PRO only when the admin issues with p_pro = true.
  v_pro := COALESCE(p_pro, p_plan = 'trial');
  -- Serialize trial issuance per merchant: concurrent trial requests for the
  -- same merchant queue on this lock; the loser then sees the committed row
  -- in the EXISTS check below and gets TRIAL_ALREADY_USED (READ COMMITTED
  -- takes a fresh snapshot after the lock wait).
  PERFORM pg_catalog.pg_advisory_xact_lock(hashtext(p_merchant_id::text)::bigint);
  IF p_plan = 'trial' AND EXISTS (
    SELECT 1 FROM public.cashier_licenses l
    WHERE l.merchant_id = p_merchant_id AND l.plan = 'trial') THEN
    RAISE EXCEPTION 'TRIAL_ALREADY_USED';
  END IF;
  -- Review #40: the trial duration is fixed server-side at 30 days — p_days
  -- is an admin-only override (paid plans already require an admin caller)
  -- with validated bounds; it is IGNORED on the self-serve trial path so a
  -- merchant cannot self-issue years of free PRO.
  IF p_plan = 'trial' THEN
    v_days := 30;
  ELSE
    IF p_days IS NOT NULL AND (p_days < 1 OR p_days > 400) THEN
      RAISE EXCEPTION 'INVALID_DAYS';
    END IF;
    v_days := COALESCE(p_days, CASE p_plan
      WHEN 'core_monthly' THEN 30 WHEN 'core_quarterly' THEN 90
      WHEN 'core_semiannual' THEN 180 WHEN 'core_annual' THEN 365 ELSE NULL END);
  END IF;
  v_expires := CASE WHEN v_days IS NULL THEN NULL ELSE now() + (v_days || ' days')::interval END;
  v_id := gen_random_uuid();
  v_payload := v_id::text || '|' || p_merchant_id::text || '|' || p_plan || '|' ||
               COALESCE(v_expires::text, 'lifetime');
  SELECT encode(extensions.hmac(v_payload, k.license_hmac_key, 'sha256'), 'hex')
    INTO v_sig FROM public._cashier_keys k WHERE k.id;
  -- Postgres encode(...,'base64') wraps at 76 chars with newlines; strip them or the key breaks copy/paste and JSON bodies.
  v_key := 'DLWQ1.' || replace(replace(replace(encode(convert_to(v_payload, 'UTF8'), 'base64'), E'\n', ''), '+', '-'), '/', '_') || '.' || v_sig;
  INSERT INTO public.cashier_licenses (id, merchant_id, license_key, plan, pro, status, expires_at, created_by)
  VALUES (v_id, p_merchant_id, v_key, p_plan, v_pro,
          CASE WHEN p_plan = 'trial' THEN 'active' ELSE 'issued' END,
          v_expires, v_uid);
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_id, 'issued', jsonb_build_object('plan', p_plan, 'pro', v_pro, 'expires_at', v_expires));
  RETURN jsonb_build_object('ok', true, 'license_id', v_id, 'license_key', v_key,
                            'plan', p_plan, 'pro', v_pro, 'expires_at', v_expires);
END;
$function$;
