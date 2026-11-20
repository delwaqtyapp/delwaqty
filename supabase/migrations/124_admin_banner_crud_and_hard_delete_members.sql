-- Migration 124: Admin Banner CRUD (Update / Delete) & Hard Delete / Hide Deactivated Members
--
-- 1. Adds `admin_update_banner` and `admin_delete_banner` SECURITY DEFINER RPCs
--    for managing promotion/banner campaigns.
-- 2. Recreates `member_ops_list`, `member_ops_count`, and `list_members` so that
--    deactivated / anonymized members (`account_status = 'deactivated'`,
--    `anonymized_at IS NOT NULL`, or `email LIKE '%@anonymized.invalid'`) never
--    appear in member lists.
-- 3. Upgrades `_member_exec_delete` to delete non-financial child rows and
--    attempt hard-deletion from `public.users` and `auth.users` inside a
--    `foreign_key_violation` exception handler.

BEGIN;

-- ============================================================
-- 1. admin_update_banner
-- ============================================================
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

REVOKE ALL ON FUNCTION public.admin_update_banner(
  uuid, text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_banner(
  uuid, text, text, text, text, uuid, text, timestamptz, timestamptz
) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_update_banner(
  uuid, text, text, text, text, uuid, text, timestamptz, timestamptz
) TO authenticated;

-- ============================================================
-- 2. admin_delete_banner
-- ============================================================
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

REVOKE ALL ON FUNCTION public.admin_delete_banner(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_delete_banner(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_delete_banner(uuid) TO authenticated;

-- ============================================================
-- 3. member_ops_list & member_ops_count (hide deactivated/anonymized)
-- ============================================================
CREATE OR REPLACE FUNCTION public.member_ops_list(
  p_search text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_verification_status text DEFAULT NULL,
  p_service_category text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_sanction_status text DEFAULT NULL,
  p_sort text DEFAULT 'newest',
  p_cursor timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_offset int DEFAULT 0,
  p_limit int DEFAULT 25
)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  phone text,
  avatar_url text,
  username text,
  role text,
  user_type text,
  account_status text,
  verification_status text,
  region_id uuid,
  region_label text,
  last_seen_at timestamptz,
  is_online boolean,
  service_types text[],
  service_categories text[],
  orders_count bigint,
  rides_count bigint,
  bookings_count bigint,
  wallet_balance numeric,
  wallet_currency text,
  active_sanctions_count bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 25), 100);
  v_offset int := GREATEST(COALESCE(p_offset, 0), 0);
  v_admin_scoped boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_uid
  ) INTO v_admin_scoped;

  RETURN QUERY
  SELECT u.id,
         u.full_name,
         u.email,
         u.phone,
         u.avatar_url,
         u.username,
         u.role,
         u.user_type,
         COALESCE(u.account_status, 'active'),
         COALESCE(u.verification_status, 'unverified'),
         up.region_id,
         CASE WHEN up.region_id IS NULL THEN NULL
              ELSE public._region_label_path(up.region_id) END,
         GREATEST(
           (SELECT MAX(lu.recorded_at) FROM public.location_updates lu WHERE lu.user_id = u.id),
           (SELECT MAX(nt.last_seen_at)   FROM public.notification_tokens nt WHERE nt.user_id = u.id)
         ),
         EXISTS (
           SELECT 1 FROM public.drivers d WHERE d.user_id = u.id AND d.is_online
         ) OR EXISTS (
           SELECT 1 FROM public.service_providers sp WHERE sp.user_id = u.id AND sp.is_available
         ),
         ARRAY(
           SELECT DISTINCT st FROM (
             SELECT UNNEST(d.service_types) AS st
               FROM public.drivers d WHERE d.user_id = u.id
             UNION
             SELECT sp.category_type
               FROM public.service_providers sp WHERE sp.user_id = u.id
           ) s WHERE st IS NOT NULL
         ),
         ARRAY(
           SELECT DISTINCT ct FROM (
             SELECT m.type AS ct FROM public.merchants m WHERE m.owner_user_id = u.id
             UNION
             SELECT sp.category_type FROM public.service_providers sp WHERE sp.user_id = u.id
           ) c WHERE ct IS NOT NULL
         ),
         (SELECT COUNT(*) FROM public.orders o WHERE o.user_id = u.id),
         (SELECT COUNT(*) FROM public.rides r WHERE r.rider_id = u.id),
         (SELECT COUNT(*) FROM public.service_bookings b WHERE b.user_id = u.id),
         (SELECT w.balance FROM public.wallets w WHERE w.user_id = u.id),
         (SELECT w.currency FROM public.wallets w WHERE w.user_id = u.id),
         (SELECT COUNT(*) FROM public.sanctions s
           WHERE s.target_user_id = u.id AND s.is_active),
         u.created_at
    FROM public.users u
    LEFT JOIN LATERAL (
      SELECT up.user_id AS user_id, up.region_id AS region_id
        FROM public.user_region_preferences up
       WHERE up.user_id = u.id
       ORDER BY up.updated_at DESC
       LIMIT 1
    ) up ON true
   WHERE COALESCE(u.account_status, 'active') <> 'deactivated'
     AND u.anonymized_at IS NULL
     AND COALESCE(u.email, '') NOT LIKE '%@anonymized.invalid'
     AND (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%'
           OR u.phone ILIKE '%' || p_search || '%'
           OR u.username ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_user_type IS NULL OR u.user_type = p_user_type)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_verification_status IS NULL
           OR COALESCE(u.verification_status, 'unverified') = p_verification_status)
     AND (p_region_id IS NULL OR up.region_id = p_region_id)
     AND (p_sanction_status IS NULL
           OR (p_sanction_status = 'active'
               AND EXISTS (SELECT 1 FROM public.sanctions s
                            WHERE s.target_user_id = u.id AND s.is_active))
           OR (p_sanction_status = 'none'
               AND NOT EXISTS (SELECT 1 FROM public.sanctions s
                                WHERE s.target_user_id = u.id AND s.is_active)))
     AND (p_service_category IS NULL
           OR EXISTS (SELECT 1 FROM public.merchants m
                       WHERE m.owner_user_id = u.id AND m.type = p_service_category)
           OR EXISTS (SELECT 1 FROM public.service_providers sp
                       WHERE sp.user_id = u.id AND sp.category_type = p_service_category)
           OR EXISTS (SELECT 1 FROM public.drivers d
                       WHERE d.user_id = u.id AND p_service_category = ANY(d.service_types)))
     AND (NOT v_admin_scoped OR up.region_id IS NULL
           OR public._region_in_scope(v_uid, up.region_id))
     AND (p_cursor IS NULL
           OR u.created_at < p_cursor
           OR (u.created_at = p_cursor AND u.id < p_cursor_id))
    ORDER BY
      CASE WHEN p_sort = 'oldest' THEN u.created_at END ASC NULLS LAST,
      CASE WHEN COALESCE(p_sort, 'newest') <> 'oldest' THEN u.created_at END
        DESC NULLS LAST,
      CASE p_sort WHEN 'name' THEN u.full_name END ASC NULLS LAST,
      CASE p_sort WHEN 'orders'
            THEN (SELECT COUNT(*)::text FROM public.orders o WHERE o.user_id = u.id)
        END DESC NULLS LAST,
      CASE p_sort WHEN 'wallet'
            THEN (SELECT w.balance::text FROM public.wallets w WHERE w.user_id = u.id)
        END DESC NULLS LAST,
      u.id DESC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.member_ops_list(
  text, text, text, text, text, text, uuid, text, text, timestamptz, uuid, int, int
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.member_ops_list(
  text, text, text, text, text, text, uuid, text, text, timestamptz, uuid, int, int
) FROM anon;
GRANT EXECUTE ON FUNCTION public.member_ops_list(
  text, text, text, text, text, text, uuid, text, text, timestamptz, uuid, int, int
) TO authenticated;

CREATE OR REPLACE FUNCTION public.member_ops_count(
  p_search text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_user_type text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_verification_status text DEFAULT NULL,
  p_service_category text DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_sanction_status text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_admin_scoped boolean;
  v_count bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN 0;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_uid
  ) INTO v_admin_scoped;

  SELECT COUNT(*) INTO v_count
    FROM public.users u
    LEFT JOIN LATERAL (
      SELECT region_id FROM public.user_region_preferences up
       WHERE up.user_id = u.id ORDER BY up.updated_at DESC LIMIT 1
    ) up ON true
   WHERE COALESCE(u.account_status, 'active') <> 'deactivated'
     AND u.anonymized_at IS NULL
     AND COALESCE(u.email, '') NOT LIKE '%@anonymized.invalid'
     AND (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%'
           OR u.phone ILIKE '%' || p_search || '%'
           OR u.username ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_user_type IS NULL OR u.user_type = p_user_type)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_verification_status IS NULL
           OR COALESCE(u.verification_status, 'unverified') = p_verification_status)
     AND (p_region_id IS NULL OR up.region_id = p_region_id)
     AND (p_sanction_status IS NULL
           OR (p_sanction_status = 'active'
               AND EXISTS (SELECT 1 FROM public.sanctions s
                            WHERE s.target_user_id = u.id AND s.is_active))
           OR (p_sanction_status = 'none'
               AND NOT EXISTS (SELECT 1 FROM public.sanctions s
                                WHERE s.target_user_id = u.id AND s.is_active)))
     AND (NOT v_admin_scoped OR up.region_id IS NULL
           OR public._region_in_scope(v_uid, up.region_id));

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.member_ops_count(
  text, text, text, text, text, text, uuid, text
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.member_ops_count(
  text, text, text, text, text, text, uuid, text
) FROM anon;
GRANT EXECUTE ON FUNCTION public.member_ops_count(
  text, text, text, text, text, text, uuid, text
) TO authenticated;

-- ============================================================
-- 4. list_members (hide deactivated/anonymized)
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_members(
  p_search         text DEFAULT NULL,
  p_role           text DEFAULT NULL,
  p_account_status text DEFAULT NULL,
  p_region_id      uuid DEFAULT NULL,
  p_cursor         timestamptz DEFAULT NULL,
  p_limit          int DEFAULT 20
)
RETURNS TABLE (
  id                  uuid,
  full_name           text,
  email               text,
  phone               text,
  role                text,
  account_status      text,
  verification_status text,
  region_id           uuid,
  created_at          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 20), 50);
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  IF NOT public.has_permission('MEMBER_VIEW', public._member_region_id(v_uid)) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT u.id,
         u.full_name,
         u.email,
         u.phone,
         u.role,
         COALESCE(u.account_status, 'active'),
         COALESCE(u.verification_status, 'unverified'),
         up.region_id,
         u.created_at
    FROM public.users u
    LEFT JOIN public.user_region_preferences up ON up.user_id = u.id
      AND up.updated_at = (
        SELECT MAX(up2.updated_at)
          FROM public.user_region_preferences up2
         WHERE up2.user_id = u.id
      )
   WHERE COALESCE(u.account_status, 'active') <> 'deactivated'
     AND u.anonymized_at IS NULL
     AND COALESCE(u.email, '') NOT LIKE '%@anonymized.invalid'
     AND (p_search IS NULL
           OR u.full_name ILIKE '%' || p_search || '%'
           OR u.email ILIKE '%' || p_search || '%')
     AND (p_role IS NULL OR u.role = p_role)
     AND (p_account_status IS NULL
           OR COALESCE(u.account_status, 'active') = p_account_status)
     AND (p_region_id IS NULL
           OR up.region_id = p_region_id
           OR up.region_id IN (
             WITH RECURSIVE region_chain AS (
               SELECT p_region_id AS rid
               UNION ALL
               SELECT r.parent_region_id
                 FROM public.regions r
                 JOIN region_chain rc ON r.id = rc.rid
                WHERE r.parent_region_id IS NOT NULL
             )
             SELECT rid FROM region_chain
           ))
     AND (p_cursor IS NULL OR u.created_at < p_cursor)
   ORDER BY u.created_at DESC
   LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int) FROM anon;
GRANT EXECUTE ON FUNCTION public.list_members(text, text, text, uuid, timestamptz, int)
  TO authenticated;

-- ============================================================
-- 5. _member_exec_delete (clean non-financial children & attempt hard delete)
-- ============================================================
CREATE OR REPLACE FUNCTION public._member_exec_delete(
  p_actor uuid,
  p_member_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
BEGIN
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;
  SELECT account_status INTO v_status FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF v_status = 'deactivated' THEN
    RAISE EXCEPTION 'Member account is already deactivated';
  END IF;

  -- 1. Soft-delete and anonymize user record (fallback if hard-delete hits historical FKs)
  UPDATE public.users SET
    account_status = 'deactivated',
    anonymized_at = now(),
    email = 'deleted-' || p_member_id::text || '@anonymized.invalid',
    full_name = NULL,
    phone = NULL,
    username = NULL,
    avatar_url = NULL,
    id_card_url = NULL,
    profile_photo_url = NULL,
    trade_license_url = NULL,
    driving_license_url = NULL
  WHERE id = p_member_id;

  -- 2. Cascade driver deactivation (if driver profile exists)
  IF EXISTS (SELECT 1 FROM public.drivers WHERE user_id = p_member_id) THEN
    UPDATE public.drivers SET
      is_online = false,
      is_active = false,
      status = 'suspended',
      updated_at = now()
    WHERE user_id = p_member_id;
  END IF;

  -- 3. Cascade merchant deactivation (if merchant profile exists)
  IF EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = p_member_id) THEN
    UPDATE public.merchants SET
      is_open = false,
      status = 'suspended',
      updated_at = now()
    WHERE owner_user_id = p_member_id;
  END IF;

  -- 4. Record audit log before attempting hard delete
  PERFORM public.write_audit(
    'MEMBER_DELETED', 'users', p_member_id::text,
    jsonb_build_object('actor', p_actor::text, 'reason', p_reason));

  -- 5. Delete non-financial child rows
  IF to_regclass('public.notification_tokens') IS NOT NULL THEN
    DELETE FROM public.notification_tokens WHERE user_id = p_member_id;
  END IF;
  IF to_regclass('public.user_region_preferences') IS NOT NULL THEN
    DELETE FROM public.user_region_preferences WHERE user_id = p_member_id;
  END IF;
  IF to_regclass('public.favorites') IS NOT NULL THEN
    DELETE FROM public.favorites WHERE user_id = p_member_id;
  END IF;
  IF to_regclass('public.cart_items') IS NOT NULL THEN
    BEGIN
      EXECUTE 'DELETE FROM public.cart_items WHERE user_id = $1' USING p_member_id;
    EXCEPTION WHEN undefined_column THEN
      NULL;
    END;
  END IF;
  IF to_regclass('public.carts') IS NOT NULL THEN
    BEGIN
      EXECUTE 'DELETE FROM public.carts WHERE user_id = $1' USING p_member_id;
    EXCEPTION WHEN undefined_column THEN
      NULL;
    END;
  END IF;

  BEGIN
    DELETE FROM public.drivers WHERE user_id = p_member_id;
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  BEGIN
    DELETE FROM public.merchants WHERE owner_user_id = p_member_id;
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  IF to_regclass('public.service_providers') IS NOT NULL THEN
    BEGIN
      DELETE FROM public.service_providers WHERE user_id = p_member_id;
    EXCEPTION WHEN foreign_key_violation THEN
      NULL;
    END;
  END IF;

  -- 6. Attempt hard-delete from public.users and auth.users; if blocked by
  --    historical financial/order FKs, keep the anonymized row (hidden from lists)
  BEGIN
    DELETE FROM public.users WHERE id = p_member_id;
    DELETE FROM auth.users WHERE id = p_member_id;
  EXCEPTION WHEN foreign_key_violation THEN
    INSERT INTO public.member_events (user_id, event_type, title, payload)
    VALUES (p_member_id, 'account_deactivated', 'Account deleted',
            jsonb_build_object('reason', p_reason));
  END;
END;
$$;

REVOKE ALL ON FUNCTION public._member_exec_delete(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._member_exec_delete(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._member_exec_delete(uuid, uuid, text) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
