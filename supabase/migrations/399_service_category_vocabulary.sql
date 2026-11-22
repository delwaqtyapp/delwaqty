-- P1 provider-profile: make backend provisioning recognise every real
-- service category (service_categories.type), not only the original subset.
-- Before this, approving a teacher / nurse / barber / pipe-change... profile
-- fell through to the merchant branch and tried merchants.type = 'teacher'.
-- Same signature, no data changes, no grants changed.
CREATE OR REPLACE FUNCTION public._is_home_service_category(p_cat text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT lower(btrim(COALESCE(p_cat, ''))) IN (
    'service', 'home_services', 'homeservices', 'plumbing', 'electrical',
    'cleaning', 'handyman', 'carpentry', 'ac_maintenance', 'acmaintenance',
    'painting', 'pest_control', 'pestcontrol', 'appliance_repair',
    'appliancerepair', 'doctor', 'clinic',
    -- added in 399
    'teacher', 'teachers', 'tutor', 'nurse', 'barber', 'other',
    'pipe_change', 'pipechange', 'plastering',
    'carpet_cleaning', 'carpetcleaning', 'dish_repair', 'dishrepair'
  );
$function$;

-- Home-service targets are created with the canonical category spelling.
CREATE OR REPLACE FUNCTION public._provision_business_target(p_user_id uuid, p_category_type text, p_display_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user record;
  v_cat text := lower(btrim(COALESCE(p_category_type, 'restaurant')));
  v_name text;
  v_merchant_id uuid;
  v_sp_id uuid;
  v_sp_cat text;
BEGIN
  SELECT id, full_name, email, phone, avatar_url, profile_photo_url
    INTO v_user
    FROM public.users
   WHERE id = p_user_id;

  v_name := COALESCE(
    NULLIF(btrim(p_display_name), ''),
    NULLIF(btrim(v_user.full_name), ''),
    'Delwaqty ' || initcap(v_cat)
  );

  IF public._is_home_service_category(v_cat) THEN
    -- Canonical service_categories.type spelling (camelCase for multi-word
    -- types such as acMaintenance), so customer-app category matching works.
    IF v_cat IN ('service', 'home_services', 'homeservices') THEN
      v_sp_cat := 'plumbing';
    ELSE
      SELECT type INTO v_sp_cat
        FROM public.service_categories
       WHERE lower(replace(type, '_', '')) = replace(v_cat, '_', '')
       ORDER BY is_active DESC, created_at ASC
       LIMIT 1;
      v_sp_cat := COALESCE(v_sp_cat, v_cat);
    END IF;
    SELECT id INTO v_sp_id
      FROM public.service_providers
     WHERE user_id = p_user_id
       AND lower(replace(category_type, '_', '')) = lower(replace(v_sp_cat, '_', ''))
     LIMIT 1;

    IF v_sp_id IS NULL THEN
      SELECT id INTO v_sp_id
        FROM public.service_providers
       WHERE user_id = p_user_id
       ORDER BY created_at ASC
       LIMIT 1;
    END IF;

    IF v_sp_id IS NULL THEN
      INSERT INTO public.service_providers (
        user_id, name, category_type, description, profile_image_url,
        rating, rating_count, is_verified, is_available, hourly_rate
      )
      VALUES (
        p_user_id,
        v_name,
        v_sp_cat,
        '',
        COALESCE(v_user.profile_photo_url, v_user.avatar_url),
        5.0,
        0,
        true,
        true,
        150
      )
      RETURNING id INTO v_sp_id;
    END IF;
  ELSE
    SELECT id INTO v_merchant_id
      FROM public.merchants
     WHERE owner_user_id = p_user_id AND lower(type) = v_cat
     ORDER BY created_at ASC
     LIMIT 1;

    IF v_merchant_id IS NULL THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        p_user_id,
        v_name,
        COALESCE(v_user.email, ''),
        v_user.phone,
        v_cat,
        'active',
        true,
        15,
        0,
        30,
        5.0
      )
      RETURNING id INTO v_merchant_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'merchant_id', v_merchant_id,
    'service_provider_id', v_sp_id
  );
END;
$function$
;
