-- Migration 121: Multi-Service / Multi-Business Provider Profiles & Admin Approval Workflow
--
-- 1. Adds `active_provider_category` to `public.users`.
-- 2. Creates `public.provider_business_profiles` so one account can operate
--    multiple business lines (restaurant, grocery, pharmacy, home_services, etc.)
--    and switch between them in the Provider App after Admin/Owner approval.
-- 3. Owner accounts automatically have all provider business lines unlocked
--    to inspect, test, and evaluate every service vertical in the Provider App.
-- 4. Updates `resolve_my_merchant()` to honor `users.active_provider_category`.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS active_provider_category text;

CREATE TABLE IF NOT EXISTS public.provider_business_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_type text NOT NULL,
  display_name text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  merchant_id uuid REFERENCES public.merchants(id) ON DELETE SET NULL,
  service_provider_id uuid REFERENCES public.service_providers(id) ON DELETE SET NULL,
  rejection_reason text,
  reviewed_by uuid REFERENCES public.users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, category_type)
);

CREATE INDEX IF NOT EXISTS idx_provider_business_profiles_user
  ON public.provider_business_profiles (user_id, status);

ALTER TABLE public.provider_business_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pbp_select_own_or_admin ON public.provider_business_profiles;
CREATE POLICY pbp_select_own_or_admin ON public.provider_business_profiles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS pbp_insert_own ON public.provider_business_profiles;
CREATE POLICY pbp_insert_own ON public.provider_business_profiles
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS pbp_update_admin ON public.provider_business_profiles;
CREATE POLICY pbp_update_admin ON public.provider_business_profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public._is_home_service_category(p_cat text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT lower(btrim(COALESCE(p_cat, ''))) IN (
    'service', 'home_services', 'homeservices', 'plumbing', 'electrical',
    'cleaning', 'handyman', 'carpentry', 'ac_maintenance', 'acmaintenance',
    'painting', 'pest_control', 'pestcontrol', 'appliance_repair',
    'appliancerepair', 'doctor', 'clinic'
  );
$$;

CREATE OR REPLACE FUNCTION public._provision_business_target(
  p_user_id uuid,
  p_category_type text,
  p_display_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
  v_cat text := lower(btrim(COALESCE(p_category_type, 'restaurant')));
  v_name text;
  v_merchant_id uuid;
  v_sp_id uuid;
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
    SELECT id INTO v_sp_id
      FROM public.service_providers
     WHERE user_id = p_user_id
       AND lower(category_type) = CASE WHEN v_cat IN ('service', 'home_services', 'homeservices') THEN 'plumbing' ELSE v_cat END
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
        CASE WHEN v_cat IN ('service', 'home_services', 'homeservices') THEN 'plumbing' ELSE v_cat END,
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
$$;

CREATE OR REPLACE FUNCTION public.get_my_provider_profiles()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_owner boolean;
  v_active text;
  v_cat text;
  v_target jsonb;
  v_m record;
  v_sp record;
  v_owner_cats text[] := ARRAY[
    'restaurant', 'grocery', 'pharmacy', 'bakery', 'home_services', 'electronics', 'fashion'
  ];
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);
  SELECT active_provider_category INTO v_active FROM public.users WHERE id = v_uid;

  IF v_is_owner THEN
    FOREACH v_cat IN ARRAY v_owner_cats LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.provider_business_profiles
         WHERE user_id = v_uid AND category_type = v_cat
      ) THEN
        v_target := public._provision_business_target(v_uid, v_cat, 'Delwaqty ' || initcap(replace(v_cat, '_', ' ')));
        INSERT INTO public.provider_business_profiles (
          user_id, category_type, display_name, status,
          merchant_id, service_provider_id, reviewed_by, reviewed_at
        )
        VALUES (
          v_uid,
          v_cat,
          'Delwaqty ' || initcap(replace(v_cat, '_', ' ')),
          'approved',
          (v_target->>'merchant_id')::uuid,
          (v_target->>'service_provider_id')::uuid,
          v_uid,
          now()
        )
        ON CONFLICT (user_id, category_type) DO UPDATE
          SET status = 'approved',
              merchant_id = COALESCE(public.provider_business_profiles.merchant_id, EXCLUDED.merchant_id),
              service_provider_id = COALESCE(public.provider_business_profiles.service_provider_id, EXCLUDED.service_provider_id);
      END IF;
    END LOOP;
    IF v_active IS NULL OR btrim(v_active) = '' THEN
      v_active := 'restaurant';
      UPDATE public.users SET active_provider_category = v_active WHERE id = v_uid;
    END IF;
  ELSE
    -- Ensure existing merchants / service_providers are synced into provider_business_profiles
    FOR v_m IN
      SELECT id, name, type FROM public.merchants WHERE owner_user_id = v_uid ORDER BY created_at ASC
    LOOP
      INSERT INTO public.provider_business_profiles (
        user_id, category_type, display_name, status, merchant_id
      )
      VALUES (
        v_uid, COALESCE(NULLIF(v_m.type, ''), 'restaurant'), COALESCE(NULLIF(v_m.name, ''), 'My Store'), 'approved', v_m.id
      )
      ON CONFLICT (user_id, category_type) DO NOTHING;
    END LOOP;

    FOR v_sp IN
      SELECT id, name, category_type FROM public.service_providers WHERE user_id = v_uid ORDER BY created_at ASC
    LOOP
      INSERT INTO public.provider_business_profiles (
        user_id, category_type, display_name, status, service_provider_id
      )
      VALUES (
        v_uid, 'home_services', COALESCE(NULLIF(v_sp.name, ''), 'My Service'), 'approved', v_sp.id
      )
      ON CONFLICT (user_id, category_type) DO NOTHING;
    END LOOP;

    IF v_active IS NULL OR btrim(v_active) = '' THEN
      SELECT category_type INTO v_active
        FROM public.provider_business_profiles
       WHERE user_id = v_uid AND status = 'approved'
       ORDER BY created_at ASC
       LIMIT 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_owner', v_is_owner,
    'active_category', COALESCE(v_active, 'restaurant'),
    'profiles', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'category_type', category_type,
          'display_name', display_name,
          'status', status,
          'merchant_id', merchant_id,
          'service_provider_id', service_provider_id,
          'rejection_reason', rejection_reason,
          'created_at', created_at
        )
        ORDER BY (status = 'approved') DESC, created_at ASC
      )
      FROM public.provider_business_profiles
      WHERE user_id = v_uid
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_provider_profiles() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.switch_active_provider_profile(p_category_type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cat text := lower(btrim(COALESCE(p_category_type, '')));
  v_is_owner boolean;
  v_profile public.provider_business_profiles%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_cat = '' THEN
    RAISE EXCEPTION 'Category is required';
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);

  SELECT * INTO v_profile
    FROM public.provider_business_profiles
   WHERE user_id = v_uid AND category_type = v_cat;

  IF NOT v_is_owner THEN
    IF NOT FOUND OR v_profile.status <> 'approved' THEN
      RAISE EXCEPTION 'This service profile is not approved for your account yet';
    END IF;
  END IF;

  UPDATE public.users
     SET active_provider_category = v_cat,
         updated_at = now()
   WHERE id = v_uid;

  RETURN jsonb_build_object(
    'ok', true,
    'active_category', v_cat,
    'merchant_id', v_profile.merchant_id,
    'service_provider_id', v_profile.service_provider_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.switch_active_provider_profile(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.request_additional_provider_profile(
  p_category_type text,
  p_display_name text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cat text := lower(btrim(COALESCE(p_category_type, '')));
  v_is_owner boolean;
  v_name text := btrim(COALESCE(p_display_name, ''));
  v_target jsonb;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_cat = '' THEN
    RAISE EXCEPTION 'Category is required';
  END IF;

  v_is_owner := public._is_owner_uid(v_uid);
  IF v_name = '' THEN
    SELECT COALESCE(NULLIF(btrim(full_name), ''), 'Delwaqty ' || initcap(v_cat))
      INTO v_name
      FROM public.users
     WHERE id = v_uid;
  END IF;

  IF v_is_owner THEN
    v_target := public._provision_business_target(v_uid, v_cat, v_name);
    INSERT INTO public.provider_business_profiles (
      user_id, category_type, display_name, status,
      merchant_id, service_provider_id, reviewed_by, reviewed_at
    )
    VALUES (
      v_uid, v_cat, v_name, 'approved',
      (v_target->>'merchant_id')::uuid,
      (v_target->>'service_provider_id')::uuid,
      v_uid, now()
    )
    ON CONFLICT (user_id, category_type) DO UPDATE
      SET status = 'approved',
          display_name = EXCLUDED.display_name,
          updated_at = now()
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('ok', true, 'id', v_id, 'status', 'approved');
  END IF;

  INSERT INTO public.provider_business_profiles (
    user_id, category_type, display_name, status
  )
  VALUES (v_uid, v_cat, v_name, 'pending')
  ON CONFLICT (user_id, category_type) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        status = CASE
          WHEN public.provider_business_profiles.status = 'approved' THEN 'approved'
          ELSE 'pending'
        END,
        rejection_reason = NULL,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'status', 'pending');
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_additional_provider_profile(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.list_provider_profile_requests(p_status text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN '[]'::jsonb;
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'user_id', p.user_id,
        'category_type', p.category_type,
        'display_name', p.display_name,
        'status', p.status,
        'rejection_reason', p.rejection_reason,
        'created_at', p.created_at,
        'user_name', u.full_name,
        'user_email', u.email,
        'user_phone', u.phone
      )
      ORDER BY p.created_at DESC
    )
    FROM public.provider_business_profiles p
    LEFT JOIN public.users u ON u.id = p.user_id
    WHERE (p_status IS NULL OR p.status = p_status)
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_provider_profile_requests(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.decide_provider_profile_request(
  p_profile_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_req public.provider_business_profiles%ROWTYPE;
  v_dec text := lower(btrim(COALESCE(p_decision, '')));
  v_target jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_dec NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Decision must be approved or rejected';
  END IF;

  SELECT * INTO v_req FROM public.provider_business_profiles WHERE id = p_profile_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile request not found';
  END IF;

  IF v_dec = 'approved' THEN
    v_target := public._provision_business_target(v_req.user_id, v_req.category_type, v_req.display_name);
    UPDATE public.provider_business_profiles
       SET status = 'approved',
           merchant_id = COALESCE((v_target->>'merchant_id')::uuid, merchant_id),
           service_provider_id = COALESCE((v_target->>'service_provider_id')::uuid, service_provider_id),
           rejection_reason = NULL,
           reviewed_by = v_actor,
           reviewed_at = now(),
           updated_at = now()
     WHERE id = p_profile_id;
  ELSE
    UPDATE public.provider_business_profiles
       SET status = 'rejected',
           rejection_reason = NULLIF(btrim(COALESCE(p_reason, '')), ''),
           reviewed_by = v_actor,
           reviewed_at = now(),
           updated_at = now()
     WHERE id = p_profile_id;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_req.user_id,
    CASE WHEN v_dec = 'approved' THEN 'Service Line Approved' ELSE 'Service Line Update' END,
    CASE
      WHEN v_dec = 'approved' THEN 'Your additional service line (' || v_req.category_type || ') is now active!'
      ELSE COALESCE(p_reason, 'Your additional service line request was rejected.')
    END,
    'provider_profile',
    jsonb_build_object('profile_id', p_profile_id, 'category_type', v_req.category_type, 'status', v_dec)
  );

  RETURN jsonb_build_object('ok', true, 'status', v_dec);
END;
$$;

GRANT EXECUTE ON FUNCTION public.decide_provider_profile_request(uuid, text, text) TO authenticated, service_role;

-- Update resolve_my_merchant() to honor users.active_provider_category
CREATE OR REPLACE FUNCTION public.resolve_my_merchant()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_active_cat text;
  v_owned uuid;
  v_user record;
  v_seeded uuid;
  v_seeded_count integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT active_provider_category INTO v_active_cat FROM public.users WHERE id = v_uid;

  -- 1. If user has an active_provider_category that is a merchant store type, match it first
  IF v_active_cat IS NOT NULL AND btrim(v_active_cat) <> '' AND NOT public._is_home_service_category(v_active_cat) THEN
    SELECT id INTO v_owned
      FROM public.merchants
     WHERE owner_user_id = v_uid AND lower(type) = lower(v_active_cat)
     ORDER BY created_at ASC
     LIMIT 1;
    IF v_owned IS NOT NULL THEN
      RETURN v_owned;
    END IF;
  END IF;

  -- 2. Otherwise check any merchant owned by this user
  SELECT id INTO v_owned
    FROM public.merchants
   WHERE owner_user_id = v_uid OR id = v_uid
   ORDER BY (owner_user_id = v_uid) DESC, created_at ASC
   LIMIT 1;

  IF v_owned IS NOT NULL THEN
    RETURN v_owned;
  END IF;

  -- 3. Auto-provision a merchant row if user is a merchant, provider, or admin/owner
  SELECT id, full_name, email, phone, role, user_type
    INTO v_user
    FROM public.users
   WHERE id = v_uid;

  IF v_user.id IS NOT NULL AND (
    v_user.role IN ('merchant', 'provider', 'owner', 'admin')
    OR v_user.user_type IN ('merchant', 'provider')
  ) THEN
    INSERT INTO public.merchants (
      owner_user_id, name, email, phone, type, status, is_open,
      delivery_fee, min_order, delivery_time_min, rating
    )
    VALUES (
      v_uid,
      COALESCE(NULLIF(btrim(v_user.full_name), ''), 'Delwaqty Store'),
      COALESCE(v_user.email, ''),
      v_user.phone,
      CASE
        WHEN v_active_cat IS NOT NULL AND NOT public._is_home_service_category(v_active_cat) THEN v_active_cat
        WHEN v_user.user_type = 'provider' OR v_user.role = 'provider' THEN 'service'
        ELSE 'restaurant'
      END,
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

  -- 4. Fallback to single unowned seeded merchant
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

NOTIFY pgrst, 'reload schema';
