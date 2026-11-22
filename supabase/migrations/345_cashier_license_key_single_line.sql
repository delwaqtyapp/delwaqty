-- 345: license keys must be single-line. Postgres encode(...,'base64') wraps
-- at 76 chars with embedded newlines, which broke keys in JSON bodies and
-- would break manual entry. Strip newlines in cashier_license_issue.
-- (Existing multi-line keys keep working: validate compares the stored key.)

CREATE OR REPLACE FUNCTION public.cashier_license_issue(
  p_merchant_id uuid, p_plan text, p_days integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
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
BEGIN
  IF v_uid IS NULL OR NOT (public.is_admin() OR public.is_merchant_owner(p_merchant_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_plan NOT IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime') THEN
    RAISE EXCEPTION 'Invalid plan %', p_plan;
  END IF;
  v_days := COALESCE(p_days, CASE p_plan
    WHEN 'trial' THEN 30 WHEN 'core_monthly' THEN 30 WHEN 'core_quarterly' THEN 90
    WHEN 'core_semiannual' THEN 180 WHEN 'core_annual' THEN 365 ELSE NULL END);
  v_expires := CASE WHEN v_days IS NULL THEN NULL ELSE now() + (v_days || ' days')::interval END;
  v_id := gen_random_uuid();
  v_payload := v_id::text || '|' || p_merchant_id::text || '|' || p_plan || '|' ||
               COALESCE(v_expires::text, 'lifetime');
  SELECT encode(extensions.hmac(v_payload, k.license_hmac_key, 'sha256'), 'hex')
    INTO v_sig FROM public._cashier_keys k WHERE k.id;
  -- Postgres encode(...,'base64') wraps at 76 chars with newlines; strip them or the key breaks copy/paste and JSON bodies.
  v_key := 'DLWQ1.' || replace(replace(replace(encode(convert_to(v_payload, 'UTF8'), 'base64'), E'\n', ''), '+', '-'), '/', '_') || '.' || v_sig;
  INSERT INTO public.cashier_licenses (id, merchant_id, license_key, plan, status, expires_at, created_by)
  VALUES (v_id, p_merchant_id, v_key, p_plan,
          CASE WHEN p_plan = 'trial' THEN 'active' ELSE 'issued' END,
          v_expires, v_uid);
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_id, 'issued', jsonb_build_object('plan', p_plan, 'expires_at', v_expires));
  RETURN jsonb_build_object('ok', true, 'license_id', v_id, 'license_key', v_key,
                            'plan', p_plan, 'expires_at', v_expires);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.cashier_license_issue(uuid, text, integer) TO authenticated;
