-- Migration 118: Phone/WhatsApp Verification, Owner Provider Document Toggle,
--                Auto-Provisioned Merchants, and Ride Recipient Population
--
-- 1. Adds `require_provider_documents` (default: false) to `public.platform_settings`
--    with an Owner-only modification guard trigger and `set_require_provider_documents` RPC.
-- 2. Updates `handle_new_user()` so that when `require_provider_documents` is false,
--    newly registered merchants/providers are immediately `approved` and auto-provisioned
--    in `public.merchants` (avoiding empty merchant_id crashes).
-- 3. Creates `public.whatsapp_otp_verifications` + RPCs (`request_whatsapp_otp`,
--    `verify_whatsapp_otp`, `lookup_email_by_phone`) for seamless phone registration,
--    WhatsApp OTP activation, and phone-number login.
-- 4. Fixes `resolve_my_merchant()`, `provider_get_availability()`, and
--    `provider_set_availability()` so all merchant/provider operations resolve
--    via `resolve_my_merchant()` and auto-provision a merchant row if missing.
-- 5. Populates `recipient_name` and `recipient_phone` on `public.rides` automatically
--    from `public.users` so drivers always have customer contact details.

-- ─── 1. Platform Settings: Owner-Controlled Provider Documents Toggle ─────────

ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS require_provider_documents BOOLEAN NOT NULL DEFAULT false;

UPDATE public.platform_settings
   SET require_provider_documents = false,
       updated_at = now()
 WHERE id = 'default';

-- Approve any currently pending provider/merchant accounts while document requirement is disabled
UPDATE public.users
   SET verification_status = 'approved',
       updated_at = now()
 WHERE (role IN ('merchant', 'provider') OR user_type IN ('merchant', 'provider'))
   AND verification_status = 'pending';

CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_platform_settings_owner_fields ON public.platform_settings;
CREATE TRIGGER trg_guard_platform_settings_owner_fields
  BEFORE INSERT OR UPDATE ON public.platform_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_platform_settings_owner_fields();

CREATE OR REPLACE FUNCTION public.set_require_provider_documents(p_required boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
  END IF;

  INSERT INTO public.platform_settings (id, require_provider_documents, updated_at)
  VALUES ('default', COALESCE(p_required, false), now())
  ON CONFLICT (id) DO UPDATE
    SET require_provider_documents = COALESCE(p_required, false),
        updated_at = now();

  -- When requirement is disabled, unlock pending merchants/providers automatically
  IF NOT COALESCE(p_required, false) THEN
    UPDATE public.users
       SET verification_status = 'approved',
           updated_at = now()
     WHERE (role IN ('merchant', 'provider') OR user_type IN ('merchant', 'provider'))
       AND verification_status = 'pending';
  END IF;

  PERFORM public.write_audit(
    'SET_REQUIRE_PROVIDER_DOCUMENTS',
    'platform_settings',
    'default',
    jsonb_build_object('require_provider_documents', COALESCE(p_required, false))
  );

  RETURN jsonb_build_object(
    'ok', true,
    'require_provider_documents', COALESCE(p_required, false)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_require_provider_documents(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_require_provider_documents(boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_require_provider_documents(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_require_provider_documents(boolean) TO service_role;

-- ─── 2. Phone Normalization, Lookup & WhatsApp OTP Verification ──────────────

CREATE OR REPLACE FUNCTION public._normalize_egypt_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_digits text;
BEGIN
  IF p_phone IS NULL THEN
    RETURN '';
  END IF;
  v_digits := regexp_replace(btrim(p_phone), '[^0-9]', '', 'g');
  IF v_digits = '' THEN
    RETURN '';
  END IF;
  -- 00201xxxxxxxxx -> +201xxxxxxxxx
  IF v_digits LIKE '0020%' AND length(v_digits) = 14 THEN
    RETURN '+' || substring(v_digits FROM 3);
  END IF;
  -- 201xxxxxxxxx -> +201xxxxxxxxx
  IF v_digits LIKE '201%' AND length(v_digits) = 12 THEN
    RETURN '+' || v_digits;
  END IF;
  -- 01xxxxxxxxx (11 digits Egyptian mobile) -> +201xxxxxxxxx
  IF v_digits LIKE '01%' AND length(v_digits) = 11 THEN
    RETURN '+2' || v_digits;
  END IF;
  -- 1xxxxxxxxx (10 digits without leading 0) -> +201xxxxxxxxx
  IF v_digits LIKE '1%' AND length(v_digits) = 10 THEN
    RETURN '+20' || v_digits;
  END IF;
  RETURN '+' || v_digits;
END;
$$;

CREATE OR REPLACE FUNCTION public.lookup_email_by_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_digits text := regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g');
  v_last10 text;
  v_email text;
BEGIN
  IF length(v_digits) < 9 THEN
    RETURN NULL;
  END IF;
  v_last10 := right(v_digits, 10);

  SELECT email INTO v_email
    FROM public.users
   WHERE account_status <> 'deactivated'
     AND email IS NOT NULL
     AND email <> ''
     AND email NOT LIKE '%@anonymized.invalid'
     AND (
       public._normalize_egypt_phone(phone) = v_norm
       OR right(regexp_replace(COALESCE(phone, ''), '[^0-9]', '', 'g'), 10) = v_last10
     )
   ORDER BY created_at DESC
   LIMIT 1;

  RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_email_by_phone(text) TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.whatsapp_otp_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  otp_code text NOT NULL,
  purpose text NOT NULL DEFAULT 'register',
  verified boolean NOT NULL DEFAULT false,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '10 minutes'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_otp_phone_created
  ON public.whatsapp_otp_verifications (phone, created_at DESC);

ALTER TABLE public.whatsapp_otp_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS whatsapp_otp_service_only ON public.whatsapp_otp_verifications;
CREATE POLICY whatsapp_otp_service_only
  ON public.whatsapp_otp_verifications
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(
  p_phone text,
  p_purpose text DEFAULT 'register'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_otp text;
  v_support_phone text;
BEGIN
  IF length(v_norm) < 10 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_PHONE');
  END IF;

  -- Generate 6-digit numeric OTP
  v_otp := lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');

  INSERT INTO public.whatsapp_otp_verifications (phone, otp_code, purpose, verified, expires_at)
  VALUES (v_norm, v_otp, COALESCE(NULLIF(btrim(p_purpose), ''), 'register'), false, now() + interval '10 minutes');

  SELECT COALESCE(NULLIF(support_phone, ''), '+201000000000')
    INTO v_support_phone
    FROM public.platform_settings
   WHERE id = 'default';

  RETURN jsonb_build_object(
    'ok', true,
    'phone', v_norm,
    'otp_code', v_otp,
    'whatsapp_number', COALESCE(v_support_phone, '+201000000000'),
    'expires_in_seconds', 600
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_whatsapp_otp(text, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.verify_whatsapp_otp(
  p_phone text,
  p_otp_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm text := public._normalize_egypt_phone(p_phone);
  v_code text := btrim(COALESCE(p_otp_code, ''));
  v_row_id uuid;
BEGIN
  IF length(v_norm) < 10 OR length(v_code) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  END IF;

  SELECT id INTO v_row_id
    FROM public.whatsapp_otp_verifications
   WHERE phone = v_norm
     AND otp_code = v_code
     AND expires_at > now()
   ORDER BY created_at DESC
   LIMIT 1;

  IF v_row_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_OR_EXPIRED_OTP');
  END IF;

  UPDATE public.whatsapp_otp_verifications
     SET verified = true
   WHERE id = v_row_id;

  IF auth.uid() IS NOT NULL THEN
    UPDATE public.users
       SET phone = v_norm,
           updated_at = now()
     WHERE id = auth.uid();
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'verified', true,
    'phone', v_norm
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_whatsapp_otp(text, text) TO anon, authenticated, service_role;

-- ─── 3. Auto-Provisioning & Verification Bypass in handle_new_user ───────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_type TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'user_type', ''),
    'customer'
  );
  v_require_docs BOOLEAN := false;
  v_verification TEXT;
  v_full_name TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    'User'
  );
  v_phone TEXT := COALESCE(
    NULLIF(NEW.phone, ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', '')
  );
  v_language TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'language', ''),
    'ar'
  );
BEGIN
  SELECT COALESCE(require_provider_documents, false)
    INTO v_require_docs
    FROM public.platform_settings
   WHERE id = 'default';

  v_verification := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'verification_status', ''),
    CASE
      WHEN v_user_type = 'customer' THEN 'approved'
      WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false) THEN 'approved'
      ELSE 'pending'
    END
  );

  INSERT INTO public.users (
    id, email, full_name, phone, language, is_onboarded,
    role, user_type, verification_status, created_at, updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_full_name,
    v_phone,
    v_language,
    true,
    v_user_type,
    v_user_type,
    v_verification,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET phone = COALESCE(EXCLUDED.phone, public.users.phone),
        full_name = CASE
          WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name = 'User'
          THEN EXCLUDED.full_name
          ELSE public.users.full_name
        END,
        verification_status = CASE
          WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false)
          THEN 'approved'
          ELSE public.users.verification_status
        END,
        updated_at = NOW();

  -- Auto-provision a merchant storefront row for merchant/provider accounts
  IF v_user_type IN ('merchant', 'provider') THEN
    IF NOT EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = NEW.id) THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        NEW.id,
        v_full_name,
        COALESCE(NEW.email, ''),
        v_phone,
        CASE WHEN v_user_type = 'provider' THEN 'service' ELSE 'restaurant' END,
        'active',
        true,
        15,
        0,
        30,
        5.0
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ─── 4. Fix resolve_my_merchant & Provider Availability RPCs ─────────────────

CREATE OR REPLACE FUNCTION public.resolve_my_merchant()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owned uuid;
  v_user record;
  v_seeded uuid;
  v_seeded_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  -- 1. Check merchant owned by this user (or matching id directly)
  SELECT id INTO v_owned
    FROM public.merchants
   WHERE owner_user_id = v_uid OR id = v_uid
   ORDER BY (owner_user_id = v_uid) DESC, created_at ASC
   LIMIT 1;

  IF v_owned IS NOT NULL THEN
    RETURN v_owned;
  END IF;

  -- 2. Auto-provision a merchant row if user is a merchant, provider, or admin/owner
  SELECT id, full_name, email, phone, role, user_type
    INTO v_user
    FROM public.users
   WHERE id = v_uid;

  IF v_user.id IS NOT NULL AND (
    v_user.role IN ('merchant', 'provider', 'owner', 'admin')
    OR v_user.user_type IN ('merchant', 'provider')
  ) THEN
    INSERT INTO public.merchants (
      owner_user_id,
      name,
      email,
      phone,
      type,
      status,
      is_open,
      delivery_fee,
      min_order,
      delivery_time_min,
      rating
    )
    VALUES (
      v_uid,
      COALESCE(NULLIF(btrim(v_user.full_name), ''), 'Delwaqty Store'),
      COALESCE(v_user.email, ''),
      v_user.phone,
      CASE WHEN v_user.user_type = 'provider' OR v_user.role = 'provider' THEN 'service' ELSE 'restaurant' END,
      'active',
      true,
      15,
      0,
      30,
      5.0
    )
    RETURNING id INTO v_owned;

    RETURN v_owned;
  END IF;

  -- 3. Fallback to single unowned seeded merchant
  SELECT count(*) INTO v_seeded_count
    FROM public.merchants
   WHERE owner_user_id IS NULL;

  IF v_seeded_count = 1 THEN
    SELECT id INTO v_seeded
      FROM public.merchants
     WHERE owner_user_id IS NULL
     LIMIT 1;
    RETURN v_seeded;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.provider_get_availability()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_merchant_id uuid;
  v_merchant    record;
  v_sp          record;
  v_category    text;
  v_is_open     boolean;
  v_schedule    jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  v_merchant_id := public.resolve_my_merchant();

  IF v_merchant_id IS NOT NULL THEN
    SELECT id, type, is_open INTO v_merchant
      FROM public.merchants
     WHERE id = v_merchant_id;

    IF v_merchant.id IS NOT NULL THEN
      v_category := v_merchant.type;
      v_is_open := v_merchant.is_open;
      SELECT COALESCE(
        jsonb_agg(jsonb_build_object(
          'day_of_week', day_of_week,
          'open_time', open_time,
          'close_time', close_time,
          'is_closed', is_closed
        ) ORDER BY day_of_week),
        '[]'::jsonb)
      INTO v_schedule
      FROM public.working_hours
      WHERE merchant_id = v_merchant_id;
    END IF;
  END IF;

  IF v_category IS NULL THEN
    SELECT id, category_type, is_available INTO v_sp
      FROM public.service_providers
     WHERE user_id = v_uid;
    IF v_sp.id IS NOT NULL THEN
      v_category := v_sp.category_type;
      v_is_open := v_sp.is_available;
      v_schedule := '[]'::jsonb;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'category', COALESCE(v_category, 'restaurant'),
    'is_open', COALESCE(v_is_open, true),
    'schedule', COALESCE(v_schedule, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.provider_set_availability(p_is_open boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_merchant_id uuid;
  v_updated     boolean := false;
  v_category    text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_is_open IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID');
  END IF;

  v_merchant_id := public.resolve_my_merchant();

  IF v_merchant_id IS NOT NULL THEN
    UPDATE public.merchants
       SET is_open = p_is_open,
           updated_at = now()
     WHERE id = v_merchant_id
    RETURNING type INTO v_category;
    IF FOUND THEN
      v_updated := true;
    END IF;
  END IF;

  IF NOT v_updated THEN
    UPDATE public.service_providers
       SET is_available = p_is_open
     WHERE user_id = v_uid
    RETURNING category_type INTO v_category;
    IF FOUND THEN
      v_updated := true;
    END IF;
  END IF;

  IF NOT v_updated THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_PROVIDER');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'code', 'OK',
    'is_open', p_is_open,
    'category', COALESCE(v_category, 'restaurant')
  );
END;
$$;

-- ─── 5. Populate Customer Contact Info on Rides Automatically ────────────────

CREATE OR REPLACE FUNCTION public.populate_ride_recipient_info()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rider record;
BEGIN
  IF NEW.rider_id IS NOT NULL AND (NEW.recipient_name IS NULL OR NEW.recipient_phone IS NULL) THEN
    SELECT full_name, phone INTO v_rider
      FROM public.users
     WHERE id = NEW.rider_id;
    IF FOUND THEN
      NEW.recipient_name := COALESCE(NULLIF(btrim(NEW.recipient_name), ''), v_rider.full_name);
      NEW.recipient_phone := COALESCE(NULLIF(btrim(NEW.recipient_phone), ''), v_rider.phone);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_populate_ride_recipient_info ON public.rides;
CREATE TRIGGER trg_populate_ride_recipient_info
  BEFORE INSERT OR UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.populate_ride_recipient_info();

-- Backfill existing active rides missing recipient_name / recipient_phone
UPDATE public.rides r
   SET recipient_name = COALESCE(NULLIF(btrim(r.recipient_name), ''), u.full_name),
       recipient_phone = COALESCE(NULLIF(btrim(r.recipient_phone), ''), u.phone)
  FROM public.users u
 WHERE r.rider_id = u.id
   AND (r.recipient_name IS NULL OR r.recipient_phone IS NULL);

NOTIFY pgrst, 'reload schema';
