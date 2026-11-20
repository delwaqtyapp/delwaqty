-- Migration 155: restore campaign banner, region builder and member-promotion RPCs.
--
-- Audit finding: the app calls 8 SECURITY DEFINER RPCs that exist in repo
-- migrations 123-126 but are absent from the live database (live-vs-repo
-- drift; schema_migrations is empty so objects landed out of band).
-- Broken live paths:
--   provider "My banners" page list        -> provider_list_my_campaigns
--   provider banner submission             -> provider_create_banner_campaign
--   admin banner create/edit/delete        -> admin_create_and_publish_banner,
--                                             admin_update_banner, admin_delete_banner
--   admin region builder save              -> admin_upsert_region
--   admin region assignment by id          -> admin_assign_region_by_id
--   member ops unified promote             -> admin_promote_and_configure_member
-- Also missing from 126's ALTERs: users.region_id and the expanded
-- role/user_type CHECK constraints (hierarchical admin roles).
-- Definitions below are the repo 123-126 bodies, verified against the live
-- schema (all referenced tables, columns, unique indexes and helper
-- functions confirmed present before apply).

-- ─── 1. users.region_id + expanded role checks (from 126) ───

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES public.regions(id) ON DELETE SET NULL;

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_user_type_check;
ALTER TABLE public.users ADD CONSTRAINT users_user_type_check
  CHECK (user_type IN (
    'customer', 'merchant', 'driver', 'provider', 'delivery',
    'admin', 'owner', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
  ));

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN (
    'customer', 'merchant', 'driver', 'provider', 'delivery',
    'admin', 'owner', 'super_admin',
    'country_admin', 'governorate_admin', 'center_admin', 'village_admin'
  ));

-- ─── 2. Restored RPCs (repo 123-126 definitions) ───

CREATE OR REPLACE FUNCTION public.provider_create_banner_campaign(
  p_name_ar text,
  p_name_en text,
  p_subtitle_ar text,
  p_subtitle_en text,
  p_region_id uuid DEFAULT NULL,
  p_image_path text DEFAULT NULL,
  p_starts_at timestamptz DEFAULT now(),
  p_ends_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_campaign_id uuid;
  v_request_id uuid;
  v_code text;
  v_clean_image text := NULLIF(btrim(p_image_path), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT (
    EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = v_uid)
    OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = v_uid)
    OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = v_uid)
  ) THEN
    RAISE EXCEPTION 'Not authorized: merchant or provider profile required';
  END IF;

  IF NULLIF(btrim(p_name_ar), '') IS NULL THEN
    RAISE EXCEPTION 'Arabic title is required';
  END IF;

  IF p_ends_at IS NOT NULL AND p_starts_at IS NOT NULL AND p_ends_at <= p_starts_at THEN
    RAISE EXCEPTION 'ends_at must be after starts_at';
  END IF;

  v_code := 'prv_banner_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.campaigns (
    code,
    campaign_type,
    priority,
    name_ar,
    name_en,
    subtitle_ar,
    subtitle_en,
    status,
    starts_at,
    ends_at,
    proposed_by,
    created_by
  )
  VALUES (
    v_code,
    'promotion',
    'normal',
    btrim(p_name_ar),
    NULLIF(btrim(p_name_en), ''),
    NULLIF(btrim(p_subtitle_ar), ''),
    NULLIF(btrim(p_subtitle_en), ''),
    'draft',
    COALESCE(p_starts_at, now()),
    p_ends_at,
    v_uid,
    v_uid
  )
  RETURNING id INTO v_campaign_id;

  IF v_clean_image IS NOT NULL THEN
    INSERT INTO public.campaign_banners (
      campaign_id, placement, locale, image_path
    )
    VALUES
      (v_campaign_id, 'home_carousel', 'ar', v_clean_image),
      (v_campaign_id, 'home_carousel', 'en', v_clean_image);
  END IF;

  INSERT INTO public.campaign_targets (campaign_id, region_id, created_by)
  VALUES (v_campaign_id, p_region_id, v_uid);

  v_request_id := public.campaign_submit(v_campaign_id, 'provider_banner_submission');

  RETURN jsonb_build_object(
    'campaign_id', v_campaign_id,
    'request_id', v_request_id,
    'code', v_code,
    'status', 'pending_review'
  );
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.provider_list_my_campaigns()
RETURNS TABLE (
  id uuid,
  code text,
  name_ar text,
  name_en text,
  subtitle_ar text,
  subtitle_en text,
  status text,
  region_id uuid,
  image_path text,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.code,
    c.name_ar,
    c.name_en,
    c.subtitle_ar,
    c.subtitle_en,
    c.status,
    ct.region_id,
    cb.image_path,
    c.starts_at,
    c.ends_at,
    c.created_at
  FROM public.campaigns c
  LEFT JOIN LATERAL (
    SELECT t.region_id
    FROM public.campaign_targets t
    WHERE t.campaign_id = c.id
    ORDER BY t.created_at ASC
    LIMIT 1
  ) ct ON true
  LEFT JOIN LATERAL (
    SELECT b.image_path
    FROM public.campaign_banners b
    WHERE b.campaign_id = c.id
      AND b.placement = 'home_carousel'
      AND b.is_active = true
    ORDER BY (b.locale = 'ar') DESC, b.created_at ASC
    LIMIT 1
  ) cb ON true
  WHERE c.created_by = v_uid
  ORDER BY c.created_at DESC;
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_create_and_publish_banner(
  p_name_ar text,
  p_name_en text DEFAULT NULL,
  p_subtitle_ar text DEFAULT NULL,
  p_subtitle_en text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_image_path text DEFAULT NULL,
  p_starts_at timestamptz DEFAULT now(),
  p_ends_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_campaign_id uuid;
  v_request_id uuid;
  v_code text;
  v_publish_status text;
  v_clean_image text := NULLIF(btrim(p_image_path), '');
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF NULLIF(btrim(p_name_ar), '') IS NULL THEN
    RAISE EXCEPTION 'Arabic title is required';
  END IF;

  IF p_ends_at IS NOT NULL AND p_starts_at IS NOT NULL AND p_ends_at <= p_starts_at THEN
    RAISE EXCEPTION 'ends_at must be after starts_at';
  END IF;

  IF NOT public.campaign_can_target_region(p_region_id) THEN
    RAISE EXCEPTION 'Not authorized for this target region';
  END IF;

  v_code := 'adm_banner_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO public.campaigns (
    code,
    campaign_type,
    priority,
    name_ar,
    name_en,
    subtitle_ar,
    subtitle_en,
    status,
    starts_at,
    ends_at,
    proposed_by,
    created_by
  )
  VALUES (
    v_code,
    'promotion',
    'normal',
    btrim(p_name_ar),
    NULLIF(btrim(p_name_en), ''),
    NULLIF(btrim(p_subtitle_ar), ''),
    NULLIF(btrim(p_subtitle_en), ''),
    'draft',
    COALESCE(p_starts_at, now()),
    p_ends_at,
    v_uid,
    v_uid
  )
  RETURNING id INTO v_campaign_id;

  IF v_clean_image IS NOT NULL THEN
    INSERT INTO public.campaign_banners (
      campaign_id, placement, locale, image_path
    )
    VALUES
      (v_campaign_id, 'home_carousel', 'ar', v_clean_image),
      (v_campaign_id, 'home_carousel', 'en', v_clean_image);
  END IF;

  INSERT INTO public.campaign_targets (campaign_id, region_id, created_by)
  VALUES (v_campaign_id, p_region_id, v_uid);

  -- draft -> pending_review
  v_request_id := public.campaign_submit(v_campaign_id, 'admin_direct_publish');

  -- pending_review -> approved
  UPDATE public.approval_requests
  SET state = 'approved',
      decided_by = v_uid,
      decided_at = now(),
      reason = 'admin_direct_publish'
  WHERE id = v_request_id;

  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (
    v_campaign_id, v_uid, 'approve',
    'pending_review', 'approved', 'admin_direct_publish'
  );

  UPDATE public.campaigns
  SET status = 'approved'
  WHERE id = v_campaign_id;

  -- approved -> published (or scheduled if starts_at > now())
  v_publish_status := public.campaign_publish(v_campaign_id);

  RETURN jsonb_build_object(
    'campaign_id', v_campaign_id,
    'request_id', v_request_id,
    'code', v_code,
    'status', v_publish_status
  );
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_delete_banner(
  p_campaign_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.campaigns WHERE id = p_campaign_id) THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  IF to_regclass('public.campaign_seen') IS NOT NULL THEN
    DELETE FROM public.campaign_seen WHERE campaign_id = p_campaign_id;
  END IF;
  IF to_regclass('public.campaign_banners') IS NOT NULL THEN
    DELETE FROM public.campaign_banners WHERE campaign_id = p_campaign_id;
  END IF;
  IF to_regclass('public.campaign_targets') IS NOT NULL THEN
    DELETE FROM public.campaign_targets WHERE campaign_id = p_campaign_id;
  END IF;
  IF to_regclass('public.campaign_media') IS NOT NULL THEN
    DELETE FROM public.campaign_media WHERE campaign_id = p_campaign_id;
  END IF;
  IF to_regclass('public.campaign_reviews') IS NOT NULL THEN
    DELETE FROM public.campaign_reviews WHERE campaign_id = p_campaign_id;
  END IF;
  IF to_regclass('public.approval_requests') IS NOT NULL THEN
    DELETE FROM public.approval_requests
     WHERE entity_id = p_campaign_id AND entity_type = 'campaign';
  END IF;

  DELETE FROM public.campaigns WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'campaign_id', p_campaign_id,
    'deleted', true
  );
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_update_banner(
  p_campaign_id uuid,
  p_name_ar text,
  p_name_en text DEFAULT NULL,
  p_subtitle_ar text DEFAULT NULL,
  p_subtitle_en text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_image_path text DEFAULT NULL,
  p_starts_at timestamptz DEFAULT NULL,
  p_ends_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_current_status text;
  v_existing_starts_at timestamptz;
  v_effective_starts_at timestamptz;
  v_new_status text;
  v_clean_image text := NULLIF(btrim(p_image_path), '');
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF NULLIF(btrim(p_name_ar), '') IS NULL THEN
    RAISE EXCEPTION 'Arabic title is required';
  END IF;

  IF NOT public.campaign_can_target_region(p_region_id) THEN
    RAISE EXCEPTION 'Not authorized for this target region';
  END IF;

  SELECT status, starts_at
    INTO v_current_status, v_existing_starts_at
    FROM public.campaigns
   WHERE id = p_campaign_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  v_effective_starts_at := COALESCE(p_starts_at, v_existing_starts_at, now());

  IF p_ends_at IS NOT NULL AND p_ends_at <= v_effective_starts_at THEN
    RAISE EXCEPTION 'ends_at must be after starts_at';
  END IF;

  IF v_current_status IN ('published', 'scheduled') THEN
    IF p_starts_at IS NOT NULL AND p_starts_at > now() THEN
      v_new_status := 'scheduled';
    ELSE
      v_new_status := 'published';
    END IF;
  ELSE
    v_new_status := v_current_status;
  END IF;

  UPDATE public.campaigns
     SET name_ar = btrim(p_name_ar),
         name_en = NULLIF(btrim(p_name_en), ''),
         subtitle_ar = NULLIF(btrim(p_subtitle_ar), ''),
         subtitle_en = NULLIF(btrim(p_subtitle_en), ''),
         starts_at = v_effective_starts_at,
         ends_at = p_ends_at,
         status = v_new_status,
         updated_at = now()
   WHERE id = p_campaign_id;

  DELETE FROM public.campaign_targets
   WHERE campaign_id = p_campaign_id;

  INSERT INTO public.campaign_targets (campaign_id, region_id, created_by)
  VALUES (p_campaign_id, p_region_id, v_uid);

  IF v_clean_image IS NOT NULL THEN
    INSERT INTO public.campaign_banners (
      campaign_id, placement, locale, image_path
    )
    VALUES
      (p_campaign_id, 'home_carousel', 'ar', v_clean_image),
      (p_campaign_id, 'home_carousel', 'en', v_clean_image)
    ON CONFLICT (campaign_id, placement, locale)
    DO UPDATE SET
      image_path = EXCLUDED.image_path,
      is_active = true,
      updated_at = now();
  END IF;

  RETURN jsonb_build_object(
    'campaign_id', p_campaign_id,
    'status', v_new_status
  );
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_upsert_region(
  p_id uuid DEFAULT NULL,
  p_parent_region_id uuid DEFAULT NULL,
  p_type text DEFAULT 'village',
  p_name_ar text DEFAULT '',
  p_name_en text DEFAULT NULL,
  p_lat double precision DEFAULT NULL,
  p_lon double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT 3.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_code text;
  v_level integer;
  v_radius_m double precision;
  v_meta jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_type NOT IN (
    'governorate', 'markaz', 'district', 'city', 'village', 'new_city', 'area'
  ) THEN
    RAISE EXCEPTION 'INVALID_REGION_TYPE';
  END IF;

  IF btrim(COALESCE(p_name_ar, '')) = '' THEN
    RAISE EXCEPTION 'NAME_AR_REQUIRED';
  END IF;

  v_radius_m := LEAST(GREATEST(COALESCE(p_radius_km, 3.0), 0.3), 50.0) * 1000.0;
  v_meta := jsonb_strip_nulls(jsonb_build_object(
    'lat', p_lat,
    'lon', p_lon,
    'radius_km', COALESCE(p_radius_km, 3.0),
    'source', 'admin_curated'
  ));

  IF p_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.regions WHERE id = p_id) THEN
    v_id := p_id;
    UPDATE public.regions
       SET parent_region_id = COALESCE(p_parent_region_id, parent_region_id),
           type = p_type,
           name_ar = btrim(p_name_ar),
           name_en = NULLIF(btrim(COALESCE(p_name_en, '')), ''),
           metadata = COALESCE(metadata, '{}'::jsonb) || v_meta,
           updated_at = now()
     WHERE id = v_id;
  ELSE
    v_id := COALESCE(p_id, gen_random_uuid());
    v_code := 'EG-CUSTOM-' || substr(replace(v_id::text, '-', ''), 1, 8);
    INSERT INTO public.regions (
      id, code, parent_region_id, country_code, type,
      name_ar, name_en, is_active, metadata
    ) VALUES (
      v_id,
      v_code,
      p_parent_region_id,
      'EG',
      p_type,
      btrim(p_name_ar),
      NULLIF(btrim(COALESCE(p_name_en, '')), ''),
      true,
      v_meta
    );
  END IF;

  IF p_lat IS NOT NULL AND p_lon IS NOT NULL THEN
    v_level := CASE p_type
      WHEN 'governorate' THEN 1
      WHEN 'markaz' THEN 2
      WHEN 'district' THEN 2
      WHEN 'city' THEN 3
      WHEN 'new_city' THEN 3
      WHEN 'village' THEN 3
      ELSE 4
    END;

    INSERT INTO public.geo_admin_boundaries (
      region_id, level, geometry, source, source_ref
    ) VALUES (
      v_id,
      v_level,
      ST_Multi(
        ST_Buffer(
          ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
          v_radius_m
        )::geometry
      ),
      'admin_curated',
      v_id::text
    )
    ON CONFLICT (region_id, source, source_ref) DO UPDATE
      SET level = EXCLUDED.level,
          geometry = EXCLUDED.geometry;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_assign_region_by_id(
  p_email text,
  p_region_id uuid,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid;
  v_region_name text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_scope NOT IN ('self', 'descendants') THEN
    RAISE EXCEPTION 'INVALID_SCOPE';
  END IF;

  SELECT id INTO v_admin_id
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;

  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'ADMIN_NOT_FOUND';
  END IF;

  SELECT COALESCE(name_ar, name_en) INTO v_region_name
    FROM public.regions
   WHERE id = p_region_id;

  IF v_region_name IS NULL THEN
    RAISE EXCEPTION 'REGION_NOT_FOUND';
  END IF;

  INSERT INTO public.admin_region_assignments (
    admin_id, region_id, scope, created_by
  ) VALUES (
    v_admin_id, p_region_id, p_scope, auth.uid()
  )
  ON CONFLICT (admin_id, region_id) DO UPDATE
    SET scope = EXCLUDED.scope,
        created_by = EXCLUDED.created_by;

  UPDATE public.users
     SET region_id = p_region_id,
         updated_at = now()
   WHERE id = v_admin_id;

  INSERT INTO public.user_region_preferences (
    user_id, region_id, source, updated_at
  ) VALUES (
    v_admin_id, p_region_id, 'verified', now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET region_id = EXCLUDED.region_id,
        source = 'verified',
        updated_at = now();

  IF to_regclass('public.admin_users') IS NOT NULL THEN
    BEGIN
      UPDATE public.admin_users
         SET region_id = p_region_id,
             region_name = v_region_name,
             updated_at = now()
       WHERE user_id = v_admin_id OR lower(email) = lower(btrim(p_email));
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
END;
$$;

-- =====

CREATE OR REPLACE FUNCTION public.admin_promote_and_configure_member(
  p_member_id uuid,
  p_role text,
  p_region_id uuid DEFAULT NULL,
  p_permissions text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_perm text;
BEGIN
  IF NOT (public.is_admin() OR public._is_owner_uid(auth.uid())) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  PERFORM public.assign_admin_role(p_member_id::text, p_role, 'Configured from Member Operations Center');

  IF p_region_id IS NOT NULL AND p_role NOT IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN
    PERFORM public.admin_assign_region_by_id(p_member_id::text, p_region_id, 'descendants');
  END IF;

  IF p_permissions IS NOT NULL AND p_role NOT IN ('customer', 'driver', 'merchant', 'provider', 'delivery') THEN
    DELETE FROM public.admin_permission_grants
     WHERE admin_id = p_member_id
       AND NOT (permission = ANY(p_permissions));

    FOREACH v_perm IN ARRAY p_permissions LOOP
      IF public._valid_permission(v_perm) THEN
        INSERT INTO public.admin_permission_grants (admin_id, permission, granted_by)
        VALUES (p_member_id, v_perm, auth.uid())
        ON CONFLICT (admin_id, permission) DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'member_id', p_member_id,
    'role', p_role,
    'region_id', p_region_id
  );
END;
$$;
-- ─── 3. Grants ───

GRANT EXECUTE ON FUNCTION public.provider_create_banner_campaign(text, text, text, text, uuid, text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.provider_list_my_campaigns() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_and_publish_banner(text, text, text, text, uuid, text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_banner(uuid, text, text, text, text, uuid, text, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_banner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_region(uuid, uuid, text, text, text, double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_region_by_id(text, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_promote_and_configure_member(uuid, text, uuid, text[]) TO service_role;

-- ─── 4. campaign_submit with provider-owner submission path (repo 123) ───
-- Live had the pre-123 admin-only version; this restores the designed
-- provider flow while preserving admin + region-scope enforcement.

CREATE OR REPLACE FUNCTION public.campaign_submit(p_campaign_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
  v_request_id uuid;
  v_uid uuid := auth.uid();
  v_is_admin boolean;
  v_is_owner_provider boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;

  v_is_admin := public.is_admin();
  v_is_owner_provider := (
    v_campaign.created_by = v_uid
    AND (
      EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = v_uid)
      OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = v_uid)
      OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = v_uid)
    )
  );

  IF NOT v_is_admin AND NOT v_is_owner_provider THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF v_is_admin AND NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;

  IF v_campaign.status NOT IN ('draft','rejected') THEN
    RAISE EXCEPTION 'Only draft or rejected campaigns can be submitted';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.campaign_targets t WHERE t.campaign_id = p_campaign_id
  ) THEN
    RAISE EXCEPTION 'Campaign must have at least one targeting region';
  END IF;

  IF NOT public.campaign_validate_benefit(v_campaign.benefit) THEN
    RAISE EXCEPTION 'Invalid campaign benefit';
  END IF;

  IF NOT public.campaign_validate_target_roles(v_campaign.target_roles) THEN
    RAISE EXCEPTION 'Invalid campaign audience roles';
  END IF;

  IF v_campaign.status = 'rejected' THEN
    UPDATE public.campaigns SET status = 'draft' WHERE id = p_campaign_id;
  END IF;

  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (
    p_campaign_id, v_uid, 'submit',
    v_campaign.status, 'pending_review', p_reason
  );

  UPDATE public.campaigns SET status = 'pending_review' WHERE id = p_campaign_id;

  INSERT INTO public.approval_requests
    (request_type, entity_type, entity_id, payload, requested_by, required_approver)
  VALUES (
    'campaign_approve', 'campaign', p_campaign_id,
    jsonb_build_object(
      'campaign_id', p_campaign_id,
      'code', v_campaign.code,
      'name_ar', v_campaign.name_ar,
      'name_en', v_campaign.name_en,
      'campaign_type', v_campaign.campaign_type,
      'priority', v_campaign.priority,
      'reason', p_reason,
      'targets', COALESCE((
        SELECT jsonb_agg(t.region_id ORDER BY t.created_at)
        FROM public.campaign_targets t WHERE t.campaign_id = p_campaign_id
      ), '[]'::jsonb)
    ),
    v_uid,
    NULL
  )
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.campaign_submit(uuid, text) TO authenticated;

-- ─── 5. campaigns_guard_status_change: allow provider-owner submission ───
-- 123 added the provider submit path to campaign_submit but never relaxed the
-- 039 trigger, so provider submission could never have worked. Non-admins may
-- not UPDATE campaigns at all (RLS is admin-only), so this relaxation only
-- takes effect inside the SECURITY DEFINER campaign_submit, which enforces
-- ownership + provider profile itself. Direct client writes stay impossible.

CREATE OR REPLACE FUNCTION public.campaigns_guard_status_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
      IF NOT (
        OLD.created_by = auth.uid()
        AND OLD.status IN ('draft','rejected')
        AND NEW.status IN ('draft','pending_review')
        AND (
          EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.merchant_profiles mp WHERE mp.user_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.service_providers sp WHERE sp.user_id = auth.uid())
        )
      ) THEN
        RAISE EXCEPTION 'Not authorized';
      END IF;
    END IF;
    IF NOT (OLD.status, NEW.status) IN (
      ('draft','pending_review'),('draft','cancelled'),('draft','archived'),
      ('pending_review','approved'),('pending_review','rejected'),
      ('pending_review','cancelled'),
      ('approved','scheduled'),('approved','published'),('approved','cancelled'),
      ('rejected','draft'),('rejected','archived'),
      ('scheduled','published'),('scheduled','cancelled'),
      ('published','paused'),('published','expired'),('published','archived'),
      ('paused','published'),('paused','archived'),
      ('expired','archived'),
      ('cancelled','draft'),('cancelled','archived')
    ) THEN
      RAISE EXCEPTION 'Invalid campaign status transition % -> %',
        OLD.status, NEW.status;
    END IF;
    IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
      NEW.published_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
