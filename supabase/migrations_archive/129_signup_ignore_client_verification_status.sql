-- 129: handle_new_user must not trust client-supplied verification_status.
-- Before: a driver/provider could sign up with user_metadata.verification_status
-- = 'approved' and skip document verification. Body is migration 118's with
-- only the verification derivation changed.

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

  -- SECURITY: never trust verification_status from client-supplied signup
  -- metadata (anyone with the public anon key can set it). Derive it here.
  v_verification := CASE
    WHEN v_user_type = 'customer' THEN 'approved'
    WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false) THEN 'approved'
    ELSE 'pending'
  END;

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
