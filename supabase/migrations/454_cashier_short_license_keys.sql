-- 454: short numeric cashier license keys (owner order, 2026-11-26).
-- Scope: cashier_licenses and the three cashier license RPCs only.
--
-- Before: cashier_license_issue handed out a ~220 char signed DLWQ1 token.
-- The server never verified that signature on activation (it looks the key
-- up by exact string), so the token was only an opaque lookup handle.
-- After: new licenses get a random 12 digit code, shown as 1234-5678-9012.
-- Activation stays online and server side. Existing licenses keep their
-- long key untouched (still valid) and also receive a short code.
--
-- Also adds a small failed-attempt throttle: 10 failed key lookups per user
-- per hour (unknown key, or a key that belongs to another merchant), so the
-- 10^12 code space cannot be walked by a signed-in user.

-- 1. column + backfill ------------------------------------------------------
ALTER TABLE public.cashier_licenses ADD COLUMN IF NOT EXISTS short_code text;

DO $bf$
DECLARE r record; c text;
BEGIN
  FOR r IN SELECT id FROM public.cashier_licenses WHERE short_code IS NULL LOOP
    LOOP
      c := lpad((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 14, 15))::bit(60)::bigint
                 % 1000000000000)::text, 12, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.cashier_licenses WHERE short_code = c)
            AND NOT EXISTS (SELECT 1 FROM public.cashier_licenses WHERE license_key = c);
    END LOOP;
    UPDATE public.cashier_licenses SET short_code = c WHERE id = r.id;
  END LOOP;
END
$bf$;

ALTER TABLE public.cashier_licenses
  ALTER COLUMN short_code SET NOT NULL,
  ADD CONSTRAINT cashier_licenses_short_code_format CHECK (short_code ~ '^[0-9]{12}$'),
  ADD CONSTRAINT cashier_licenses_short_code_key UNIQUE (short_code);

-- Any other insert path (admin tooling, tests, future code) that omits the
-- short code gets one generated, so NOT NULL never breaks an existing writer.
CREATE OR REPLACE FUNCTION public._cashier_license_fill_short_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c text; n integer := 0;
BEGIN
  IF NEW.short_code IS NULL THEN
    LOOP
      n := n + 1;
      c := lpad((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 14, 15))::bit(60)::bigint
                 % 1000000000000)::text, 12, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.cashier_licenses WHERE short_code = c OR license_key = c);
      IF n >= 5 THEN RAISE EXCEPTION 'KEY_GENERATION_FAILED'; END IF;
    END LOOP;
    NEW.short_code := c;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._cashier_license_fill_short_code() FROM public, anon, authenticated;
CREATE TRIGGER cashier_licenses_fill_short_code
  BEFORE INSERT ON public.cashier_licenses
  FOR EACH ROW EXECUTE FUNCTION public._cashier_license_fill_short_code();

-- 2. failed-attempt log (server only) ---------------------------------------
CREATE TABLE IF NOT EXISTS public._cashier_key_failures (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS _cashier_key_failures_user_at ON public._cashier_key_failures (user_id, at);
ALTER TABLE public._cashier_key_failures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._cashier_key_failures FROM public, anon, authenticated;
REVOKE ALL ON SEQUENCE public._cashier_key_failures_id_seq FROM public, anon, authenticated;

-- 3. helpers (not callable by clients) --------------------------------------
-- Digits typed in Arabic-Indic or Persian forms become ASCII; spaces and
-- dash variants are dropped. A 12 digit result is a short code; anything
-- else is returned trimmed so legacy DLWQ1 keys still match exactly.
CREATE OR REPLACE FUNCTION public._cashier_normalize_key(p_key text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
  SELECT CASE
           WHEN d ~ '^[0-9[:space:]\u00A0\u2010-\u2015\u2212\u200E\u200F-]+$'
            AND regexp_replace(d, '[^0-9]', '', 'g') ~ '^[0-9]{12}$'
           THEN regexp_replace(d, '[^0-9]', '', 'g')
           ELSE btrim(coalesce(p_key, ''))
         END
    FROM (SELECT translate(coalesce(p_key, ''),
                  U&'\0660\0661\0662\0663\0664\0665\0666\0667\0668\0669\06F0\06F1\06F2\06F3\06F4\06F5\06F6\06F7\06F8\06F9',
                  '01234567890123456789') AS d) s
$function$;

CREATE OR REPLACE FUNCTION public._cashier_format_code(p_code text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
  SELECT substr(p_code, 1, 4) || '-' || substr(p_code, 5, 4) || '-' || substr(p_code, 9, 4)
$function$;

CREATE OR REPLACE FUNCTION public._cashier_key_throttled(p_uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT count(*) >= 10 FROM public._cashier_key_failures
   WHERE user_id = p_uid AND at > now() - interval '1 hour'
$function$;

CREATE OR REPLACE FUNCTION public._cashier_key_fail(p_uid uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH gc AS (DELETE FROM public._cashier_key_failures WHERE at < now() - interval '1 day')
  INSERT INTO public._cashier_key_failures (user_id) VALUES (p_uid)
$function$;

REVOKE ALL ON FUNCTION public._cashier_normalize_key(text) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public._cashier_format_code(text) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public._cashier_key_throttled(uuid) FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public._cashier_key_fail(uuid) FROM public, anon, authenticated;

-- 4. issue ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cashier_license_issue(p_merchant_id uuid, p_plan text, p_days integer DEFAULT NULL::integer, p_pro boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_days integer;
  v_code text;
  v_id uuid;
  v_expires timestamptz;
  v_pro boolean;
  v_try integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_plan NOT IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime') THEN
    RAISE EXCEPTION 'Invalid plan %', p_plan;
  END IF;
  IF p_plan <> 'trial' AND NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'PAID_PLANS_REQUIRE_ADMIN';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  v_pro := COALESCE(p_pro, p_plan = 'trial');
  PERFORM pg_catalog.pg_advisory_xact_lock(hashtext(p_merchant_id::text)::bigint);
  IF p_plan = 'trial' AND EXISTS (
    SELECT 1 FROM public.cashier_licenses l
    WHERE l.merchant_id = p_merchant_id AND l.plan = 'trial') THEN
    RAISE EXCEPTION 'TRIAL_ALREADY_USED';
  END IF;
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
  -- 12 random digits from a CSPRNG-backed uuid (60 bits mod 10^12), bounded retry.
  LOOP
    v_try := v_try + 1;
    v_code := lpad((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 14, 15))::bit(60)::bigint
                    % 1000000000000)::text, 12, '0');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.cashier_licenses WHERE short_code = v_code OR license_key = v_code);
    IF v_try >= 5 THEN RAISE EXCEPTION 'KEY_GENERATION_FAILED'; END IF;
  END LOOP;
  INSERT INTO public.cashier_licenses (id, merchant_id, license_key, short_code, plan, pro, status, expires_at, created_by)
  VALUES (v_id, p_merchant_id, v_code, v_code, p_plan, v_pro,
          CASE WHEN p_plan = 'trial' THEN 'active' ELSE 'issued' END,
          v_expires, v_uid);
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_id, 'issued', jsonb_build_object('plan', p_plan, 'pro', v_pro, 'expires_at', v_expires));
  RETURN jsonb_build_object('ok', true, 'license_id', v_id,
                            'license_key', public._cashier_format_code(v_code),
                            'short_code', v_code,
                            'plan', p_plan, 'pro', v_pro, 'expires_at', v_expires);
END;
$function$;

-- 5. validate ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cashier_license_validate(p_license_key text, p_device_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_norm text;
  v_l record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._cashier_key_throttled(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TOO_MANY_ATTEMPTS');
  END IF;
  v_norm := public._cashier_normalize_key(p_license_key);
  SELECT * INTO v_l FROM public.cashier_licenses
   WHERE short_code = v_norm OR license_key = v_norm
   ORDER BY (short_code = v_norm) DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN
    PERFORM public._cashier_key_fail(v_uid);
    RETURN jsonb_build_object('ok', false, 'reason', 'UNKNOWN_KEY');
  END IF;
  IF NOT public.is_merchant_owner(v_l.merchant_id) THEN
    PERFORM public._cashier_key_fail(v_uid);
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_AUTHORIZED');
  END IF;
  IF v_l.status = 'suspended' THEN RETURN jsonb_build_object('ok', false, 'reason', 'SUSPENDED'); END IF;
  IF v_l.device_id IS NULL AND p_device_id IS NOT NULL THEN
    UPDATE public.cashier_licenses
       SET status = 'active', activated_at = COALESCE(activated_at, now()),
           device_id = p_device_id, updated_at = now()
     WHERE id = v_l.id;
    INSERT INTO public.cashier_license_events (license_id, kind, detail)
    VALUES (v_l.id, 'activated', jsonb_build_object('device_id', p_device_id));
  ELSIF p_device_id IS NOT NULL AND v_l.device_id <> p_device_id THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'BOUND_TO_OTHER_DEVICE');
  END IF;
  IF v_l.expires_at IS NOT NULL AND v_l.expires_at < now() THEN
    UPDATE public.cashier_licenses SET status = 'expired', updated_at = now() WHERE id = v_l.id;
    RETURN jsonb_build_object('ok', false, 'reason', 'EXPIRED',
      'grace_until', v_l.expires_at + (v_l.grace_days || ' days')::interval);
  END IF;
  RETURN jsonb_build_object('ok', true, 'plan', v_l.plan, 'pro', v_l.pro, 'status', 'active',
    'expires_at', v_l.expires_at, 'merchant_id', v_l.merchant_id);
END;
$function$;

-- 6. device_link ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cashier_device_link(p_license_key text, p_device_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_check jsonb;
  v_norm text;
  v_license record;
  v_merchant record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  v_check := public.cashier_license_validate(p_license_key, p_device_id);
  IF NOT (v_check->>'ok')::boolean THEN RETURN v_check; END IF;
  v_norm := public._cashier_normalize_key(p_license_key);
  SELECT * INTO v_license FROM public.cashier_licenses
   WHERE short_code = v_norm OR license_key = v_norm
   ORDER BY (short_code = v_norm) DESC LIMIT 1;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_license.merchant_id;
  INSERT INTO public.cashier_license_events (license_id, kind, detail)
  VALUES (v_license.id, 'linked', jsonb_build_object('device_id', p_device_id, 'uid', v_uid));
  RETURN jsonb_build_object(
    'ok', true,
    'plan', v_license.plan, 'pro', v_license.pro, 'status', v_license.status,
    'expires_at', v_license.expires_at,
    'grace_until', CASE WHEN v_license.expires_at IS NULL THEN NULL
                        ELSE v_license.expires_at + (v_license.grace_days || ' days')::interval END,
    'merchant', jsonb_build_object(
      'id', v_merchant.id, 'name', v_merchant.name, 'type', v_merchant.type,
      'phone', v_merchant.phone, 'address', v_merchant.address),
    'product_count', (SELECT count(*) FROM public.products p
                       WHERE p.merchant_id = v_merchant.id AND p.is_available));
END;
$function$;

-- Client-callable surface: authenticated only (service_role kept as before).
REVOKE ALL ON FUNCTION public.cashier_license_issue(uuid, text, integer, boolean) FROM public, anon;
REVOKE ALL ON FUNCTION public.cashier_license_validate(text, text) FROM public, anon;
REVOKE ALL ON FUNCTION public.cashier_device_link(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.cashier_license_issue(uuid, text, integer, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cashier_license_validate(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cashier_device_link(text, text) TO authenticated;
