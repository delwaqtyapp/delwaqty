-- 469: signup metadata can no longer pick a privileged account type.
-- handle_new_user copied raw_user_meta_data->>'user_type' into users.role and
-- users.user_type, blocking only 'merchant_staff'. The role CHECK allows
-- owner / admin / super_admin / country_admin, so anyone holding the public anon key
-- could sign up as an owner. From now on only customer, merchant, provider,
-- driver and delivery are accepted from client metadata; anything else becomes
-- customer. Elevated roles come only from the admin lifecycle RPCs.
-- Pre-image pinned (md5 of the prod 444 function). Already-patched is accepted,
-- so the file is re-runnable.

--    Pre-image pinned: prod handle_new_user md5 = 4c27ceff52867e83ead588c6951fc5c1
--    (444 version). Already-patched is accepted so the file stays re-runnable.
DO $$
DECLARE v_def text := pg_get_functiondef('public.handle_new_user()'::regprocedure);
BEGIN
  IF position('469/#374' in v_def) = 0
     AND md5(v_def) <> '4c27ceff52867e83ead588c6951fc5c1' THEN
    RAISE EXCEPTION '469 precondition failed: handle_new_user drifted from the 444 pre-image (md5 %)', md5(v_def);
  END IF;
END $$;
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  -- 469/#374: client signup metadata may only pick a public account type.
  -- Everything else (owner, admin, super_admin, merchant_staff, junk) is a
  -- customer; elevated roles come only from the admin lifecycle RPCs.
  IF v_user_type NOT IN ('customer', 'merchant', 'provider', 'driver', 'delivery') THEN
    v_user_type := 'customer';
  END IF;

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

  -- Merchant signup creates its storefront. Provider targets are created only
  -- by the category-aware business approval/provisioning flow.
  IF v_user_type = 'merchant' THEN
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
        'restaurant',
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
$function$;
