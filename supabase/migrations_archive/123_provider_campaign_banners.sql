-- ============================================================
-- Migration 115: Provider Campaign Banners & Admin Direct Publish
-- ============================================================
-- Adds:
--   1. campaign_submit() update so campaign creators (merchants/providers)
--      can submit their own draft/rejected campaigns alongside admins.
--   2. provider_create_banner_campaign(...)
--   3. provider_list_my_campaigns()
--   4. admin_create_and_publish_banner(...)
--   5. Storage RLS policies on storage.objects (bucket_id = 'campaign-media')
--      allowing authenticated providers to manage providers/<auth.uid()>/...
-- ============================================================

-- 1. Allow campaign creators (merchants / service providers) to submit their
--    own draft/rejected campaigns via campaign_submit, while preserving
--    admin + region-scope enforcement for admin callers.
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

REVOKE ALL ON FUNCTION public.campaign_submit(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.campaign_submit(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.campaign_submit(uuid, text) TO authenticated;

-- 2. Provider creates a banner campaign and submits it for admin approval.
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

REVOKE ALL ON FUNCTION public.provider_create_banner_campaign(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_create_banner_campaign(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_create_banner_campaign(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) TO authenticated;

-- 3. List campaigns created by the authenticated provider/merchant.
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

REVOKE ALL ON FUNCTION public.provider_list_my_campaigns() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_list_my_campaigns() FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_list_my_campaigns() TO authenticated;

-- 4. Admin creates a banner campaign and transitions it cleanly:
--    draft -> pending_review -> approved -> published (or scheduled).
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

REVOKE ALL ON FUNCTION public.admin_create_and_publish_banner(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_create_and_publish_banner(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_create_and_publish_banner(
  text, text, text, text, uuid, text, timestamptz, timestamptz
) TO authenticated;

-- 5. Storage RLS policies on storage.objects for campaign-media bucket
--    allowing authenticated providers to upload/manage providers/<auth.uid()>/...
DROP POLICY IF EXISTS "campaign media provider upload" ON storage.objects;
CREATE POLICY "campaign media provider upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'campaign-media'
    AND auth.uid() IS NOT NULL
    AND name LIKE ('providers/' || auth.uid()::text || '/%')
  );

DROP POLICY IF EXISTS "campaign media provider select" ON storage.objects;
CREATE POLICY "campaign media provider select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'campaign-media'
    AND auth.uid() IS NOT NULL
    AND name LIKE ('providers/' || auth.uid()::text || '/%')
  );

DROP POLICY IF EXISTS "campaign media provider update" ON storage.objects;
CREATE POLICY "campaign media provider update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'campaign-media'
    AND auth.uid() IS NOT NULL
    AND name LIKE ('providers/' || auth.uid()::text || '/%')
  )
  WITH CHECK (
    bucket_id = 'campaign-media'
    AND auth.uid() IS NOT NULL
    AND name LIKE ('providers/' || auth.uid()::text || '/%')
  );

DROP POLICY IF EXISTS "campaign media provider delete" ON storage.objects;
CREATE POLICY "campaign media provider delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'campaign-media'
    AND auth.uid() IS NOT NULL
    AND name LIKE ('providers/' || auth.uid()::text || '/%')
  );
