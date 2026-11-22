-- 361: LAB-F-06 / F-07 / F-08 regional isolation hardening (read + write).
-- F-06: has_permission no longer skips the geographic gate for unassigned
--       admins when p_region_id IS NULL; member-ops read RPCs scope rows and
--       treat NULL member region as owner/country-level only.
-- F-07: cashier / POS / pharmacy / order / chat / live-share SECURITY DEFINER
--       RPCs no longer admit any active admin via bare is_admin() or the
--       is_merchant_owner pass-through; admin paths are region-scoped through
--       _admin_write_scope (or country-level for platform-global operations).
-- F-08: is_merchant_owner's OR is_admin() pass-through replaced by a
--       region-scoped admin check; orders merchant-owner policies are
--       self-only (_is_merchant_owner_only) with the scoped admin policies
--       carrying admin access; orders admin SELECT policy region-scoped.

CREATE OR REPLACE FUNCTION public._ops_scope_region(p_region uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- NULL entity region: scope-check against the root region, which only the
  -- owner and country-level admins cover.
  SELECT COALESCE(p_region, (
    SELECT r.id FROM public.regions r
    WHERE r.parent_region_id IS NULL ORDER BY r.created_at LIMIT 1));
$function$;

GRANT EXECUTE ON FUNCTION public._ops_scope_region(uuid) TO authenticated;

-- ===== is_merchant_owner (F-08 root: admin pass-through now region-scoped) =====
CREATE OR REPLACE FUNCTION public.is_merchant_owner(merchant_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.merchants m
     WHERE m.id = merchant_uuid
       AND (m.owner_user_id = auth.uid() OR m.id = auth.uid())
  ) OR public._admin_write_scope(
         public._ops_scope_region(public._merchant_region_id(merchant_uuid)));
$function$;


-- ===== has_permission (F-06 root: NULL-region unassigned deny) =====
CREATE OR REPLACE FUNCTION public.has_permission(p_permission text, p_region_id uuid DEFAULT NULL::uuid, p_target_admin_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_granted boolean;
  v_default_in_scope boolean;
BEGIN
  IF v_actor IS NULL OR p_permission IS NULL OR btrim(p_permission) = '' THEN
    RETURN false;
  END IF;

  -- Owner has absolute, universal authority across every permission
  IF public._is_owner_uid(v_actor) THEN
    RETURN true;
  END IF;

  -- Validate permission vocabulary for non-owner admins
  IF NOT public._valid_permission(p_permission) THEN
    RETURN false;
  END IF;

  IF NOT public._is_active_admin_uid(v_actor) THEN
    RETURN false;
  END IF;

  -- Geographic scope gate
  IF p_region_id IS NOT NULL AND NOT public._region_in_scope(v_actor, p_region_id) THEN
    RETURN false;
  END IF;

  -- Unassigned admins have no regional footprint: with a NULL region there is
  -- nothing to scope-check against, so deny (the owner returned above).
  IF p_region_id IS NULL AND NOT EXISTS (
    SELECT 1 FROM public.admin_region_assignments a WHERE a.admin_id = v_actor
  ) THEN
    RETURN false;
  END IF;

  -- Target-admin gate (ADMIN_* actions are always supervisor-scoped)
  IF p_target_admin_id IS NOT NULL
     AND NOT public.is_supervisor_of(v_actor, p_target_admin_id) THEN
    RETURN false;
  END IF;

  -- Explicit grant check
  SELECT EXISTS (
    SELECT 1 FROM public.admin_permission_grants g
    WHERE g.admin_id = v_actor AND g.permission = p_permission
  ) INTO v_granted;
  IF v_granted THEN
    RETURN true;
  END IF;

  -- Default in-scope matrix for subordinate admins
  SELECT p_permission IN (
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'EMERGENCY_VIEW','OFFER_CREATE','OFFER_REVIEW',
    'ORDER_VIEW', 'MERCHANT_VIEW', 'DRIVER_VIEW', 'ANALYTICS_VIEW', 'AUDIT_LOG_VIEW'
  ) INTO v_default_in_scope;
  RETURN v_default_in_scope;
END;
$function$;


-- ===== _admin_scope_allows =====
CREATE OR REPLACE FUNCTION public._admin_scope_allows(p_region_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_role text;
begin
  if not public.is_admin() then
    return false;
  end if;
  select role into v_role from public.users where id = auth.uid();
  if v_role = 'owner' then
    return true;
  end if;
  -- Unassigned admins are nobody's fallback: no assignments, no access.
  if not exists (select 1 from public.admin_region_assignments a where a.admin_id = auth.uid()) then
    return false;
  end if;
  if p_region_id is null then
    return false;
  end if;
  return public._admin_covers_region(auth.uid(), p_region_id);
end;
$function$;


-- ===== _appeals_admin_read_allowed =====
CREATE OR REPLACE FUNCTION public._appeals_admin_read_allowed(p_region_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_role text;
begin
  if not public.is_admin() then
    return false;
  end if;
  select role into v_role from public.users where id = auth.uid();
  -- Owner sees all (final fallback of the duty chain).
  if v_role = 'owner' then
    return true;
  end if;
  -- Unassigned admins are nobody's fallback: no assignments, no access.
  if not exists (
    select 1 from public.admin_region_assignments a where a.admin_id = auth.uid()
  ) then
    return false;
  end if;
  -- Region-assigned admins read only appeals inside their coverage; NULL-region
  -- appeals route to the fallbacks only, like _duty_admin_for_region does.
  if p_region_id is null then
    return false;
  end if;
  return public._admin_covers_region(auth.uid(), p_region_id);
end;
$function$;


-- ===== campaign_can_target_region =====
CREATE OR REPLACE FUNCTION public.campaign_can_target_region(p_region_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._admin_write_scope(p_region_id);
$function$;


-- ===== campaign_scoped_for_storage =====
CREATE OR REPLACE FUNCTION public.campaign_scoped_for_storage(p_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._is_active_admin_uid(auth.uid())
    AND public.campaign_id_from_storage_path(p_name) IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.campaigns c
      WHERE c.id = public.campaign_id_from_storage_path(p_name)
    )
    AND public.campaign_targets_authorized(public.campaign_id_from_storage_path(p_name));
$function$;


-- ===== member_ops_count =====
CREATE OR REPLACE FUNCTION public.member_ops_count(p_search text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_user_type text DEFAULT NULL::text, p_account_status text DEFAULT NULL::text, p_verification_status text DEFAULT NULL::text, p_service_category text DEFAULT NULL::text, p_region_id uuid DEFAULT NULL::uuid, p_sanction_status text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_count bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*) INTO v_count
    FROM public.users u
    LEFT JOIN LATERAL (
      SELECT region_id FROM public.user_region_preferences up
       WHERE up.user_id = u.id ORDER BY up.updated_at DESC LIMIT 1
    ) up ON true
   WHERE (p_search IS NULL
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
     AND (public._is_owner_uid(v_uid)
           OR public._is_country_admin_uid(v_uid)
           OR (up.region_id IS NOT NULL
               AND public._region_in_scope(v_uid, up.region_id)));

  RETURN v_count;
END;
$function$;


-- ===== member_ops_list =====
CREATE OR REPLACE FUNCTION public.member_ops_list(p_search text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_user_type text DEFAULT NULL::text, p_account_status text DEFAULT NULL::text, p_verification_status text DEFAULT NULL::text, p_service_category text DEFAULT NULL::text, p_region_id uuid DEFAULT NULL::uuid, p_sanction_status text DEFAULT NULL::text, p_sort text DEFAULT 'newest'::text, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_cursor_id uuid DEFAULT NULL::uuid, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25)
 RETURNS TABLE(id uuid, full_name text, email text, phone text, avatar_url text, username text, role text, user_type text, account_status text, verification_status text, region_id uuid, region_label text, last_seen_at timestamp with time zone, is_online boolean, service_types text[], service_categories text[], orders_count bigint, rides_count bigint, bookings_count bigint, wallet_balance numeric, wallet_currency text, active_sanctions_count bigint, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 25), 100);
  v_offset int := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  IF NOT (public._is_owner_uid(v_uid) OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN;
  END IF;

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
   WHERE (p_search IS NULL
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
     AND (public._is_owner_uid(v_uid)
          OR public._is_country_admin_uid(v_uid)
          OR (up.region_id IS NOT NULL
              AND public._region_in_scope(v_uid, up.region_id)))
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
$function$;


-- ===== get_member_ops_profile =====
CREATE OR REPLACE FUNCTION public.get_member_ops_profile(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE
  v_uid          uuid := auth.uid();
  v_member_regid uuid;
  v_can_loc      boolean;
  v_can_chat     boolean;
  v_can_docs     boolean;
  v_can_mod      boolean;
  v_exists       boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT region_id INTO v_member_regid
    FROM public.user_region_preferences
   WHERE user_id = p_member_id
   ORDER BY updated_at DESC LIMIT 1;

  -- NULL member region: scope-check against the root region so only the
  -- owner / country-level admins pass the permission gates below.
  v_member_regid := public._ops_scope_region(v_member_regid);

  IF NOT public.has_permission('MEMBER_VIEW', v_member_regid) THEN
    RETURN NULL;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_member_id
  ) INTO v_exists;
  IF NOT v_exists THEN
    RETURN NULL;
  END IF;

  v_can_loc  := public.has_permission('MEMBER_VIEW_LOCATION', v_member_regid);
  v_can_chat := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_member_regid);
  v_can_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_member_regid);
  v_can_mod  := public.has_permission('MEMBER_MODERATE', v_member_regid);

  RETURN jsonb_build_object(
    'member', (
      SELECT jsonb_build_object(
        'id', u.id, 'full_name', u.full_name, 'email', u.email, 'phone', u.phone,
        'avatar_url', u.avatar_url, 'username', u.username,
        'role', u.role, 'user_type', u.user_type,
        'account_status', COALESCE(u.account_status, 'active'),
        'verification_status', COALESCE(u.verification_status, 'unverified'),
        'language', u.language, 'is_onboarded', u.is_onboarded,
        'date_of_birth', u.date_of_birth,
        'created_at', u.created_at, 'updated_at', u.updated_at)
        FROM public.users u WHERE u.id = p_member_id
    ),
    'region', (
      SELECT jsonb_build_object(
        'region_id', up.region_id,
        'label', public._region_label_path(up.region_id))
        FROM public.user_region_preferences up
       WHERE up.user_id = p_member_id ORDER BY up.updated_at DESC LIMIT 1
    ),
    'location', CASE WHEN v_can_loc THEN (
      SELECT jsonb_build_object(
        'latitude', l.latitude, 'longitude', l.longitude,
        'accuracy', l.accuracy, 'recorded_at', l.recorded_at,
        'is_moving', l.is_moving)
        FROM public.location_updates l
       WHERE l.user_id = p_member_id
       ORDER BY l.recorded_at DESC LIMIT 1)
      ELSE NULL END,
    'last_seen', (
      SELECT GREATEST(
        (SELECT MAX(recorded_at) FROM public.location_updates lu WHERE lu.user_id = p_member_id),
        (SELECT MAX(last_seen_at) FROM public.notification_tokens nt WHERE nt.user_id = p_member_id))
    ),
    'driver', (
      SELECT jsonb_build_object(
        'id', id, 'vehicle_type', vehicle_type, 'vehicle_plate', vehicle_plate,
        'is_online', is_online, 'is_verified', is_verified,
        'verification_status', verification_status,
        'status', status, 'rating', rating, 'total_deliveries', total_deliveries,
        'total_trips', total_trips, 'earnings_balance', earnings_balance,
        'background_check_status', background_check_status,
        'service_types', service_types)
        FROM public.drivers WHERE user_id = p_member_id
    ),
    'merchants', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'type', type, 'status', status,
        'rating', rating, 'total_orders', total_orders,
        'delivery_fee', delivery_fee, 'min_order', min_order,
        'is_featured', is_featured))
        FROM public.merchants WHERE owner_user_id = p_member_id)
    , '[]'::jsonb),
    'providers', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'category_type', category_type,
        'is_verified', is_verified, 'is_available', is_available,
        'rating', rating, 'rating_count', rating_count,
        'hourly_rate', hourly_rate, 'fixed_price_min', fixed_price_min,
        'fixed_price_max', fixed_price_max, 'city', city))
        FROM public.service_providers WHERE user_id = p_member_id)
    , '[]'::jsonb),
    'orders', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'merchant_id', merchant_id, 'driver_id', driver_id,
            'status', status, 'payment_status', payment_status,
            'total_amount', total_amount, 'created_at', created_at) AS j
          FROM public.orders WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'rides', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'service_type', service_type, 'status', status,
            'fare', fare, 'driver_rating', driver_rating, 'created_at', created_at) AS j
          FROM public.rides WHERE rider_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'bookings', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'category_type', category_type, 'status', status,
            'provider_name', provider_name, 'final_price', final_price,
            'created_at', created_at) AS j
          FROM public.service_bookings WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 10) s)
    , '[]'::jsonb),
    'wallet', (
      SELECT jsonb_build_object(
        'balance', w.balance, 'currency', w.currency,
        'transactions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', t.id, 'type', t.type, 'amount', t.amount,
                'reference_type', t.reference_type, 'balance_after', t.balance_after,
                'created_at', t.created_at) AS j
              FROM public.wallet_transactions t WHERE t.wallet_id = w.id
              ORDER BY t.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.wallets w WHERE w.user_id = p_member_id
    ),
    'financials', (
      SELECT jsonb_build_object(
        'gross_orders', COALESCE(SUM(o.total_amount), 0),
        'orders_count', COUNT(o.id),
        'commission_rate', public.get_commission_rate(u.user_type::text, NULL::text),
        'commission_estimated', ROUND(COALESCE(SUM(o.total_amount), 0)
                                  * COALESCE(public.get_commission_rate(u.user_type::text, NULL::text), 0) / 100.0, 2),
        'commissions', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'reference_type', c.reference_type, 'gross_amount', c.gross_amount,
                'commission_rate', c.commission_rate, 'commission_amount', c.commission_amount,
                'net_amount', c.net_amount, 'status', c.status, 'created_at', c.created_at) AS j
              FROM public.platform_commissions c WHERE c.member_id = p_member_id
              ORDER BY c.created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
        FROM public.users u
        LEFT JOIN public.orders o ON o.user_id = u.id
       WHERE u.id = p_member_id
       GROUP BY u.user_type
    ),
    'active_sanctions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', id, 'sanction_type', sanction_type, 'reason', reason,
        'amount', amount, 'start_date', start_date, 'end_date', end_date,
        'is_active', is_active, 'issued_by', issued_by, 'created_at', created_at))
        FROM public.sanctions
       WHERE target_user_id = p_member_id AND is_active)
    , '[]'::jsonb),
    'complaints', (
      SELECT jsonb_build_object(
        'filed_count', (SELECT COUNT(*) FROM public.complaints WHERE complainant_id = p_member_id),
        'received_count', (SELECT COUNT(*) FROM public.complaints WHERE respondent_id = p_member_id),
        'related', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'complaint_type', complaint_type, 'category', category,
                'status', status, 'priority', priority, 'subject', subject, 'created_at', created_at) AS j
              FROM public.complaints
             WHERE complainant_id = p_member_id OR respondent_id = p_member_id
             ORDER BY created_at DESC LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'support', (
      SELECT jsonb_build_object(
        'rooms_count', (SELECT COUNT(*) FROM public.chat_rooms
                         WHERE p_member_id = ANY(participant_ids)),
        'rooms', COALESCE((
          SELECT jsonb_agg(j)
            FROM (
              SELECT jsonb_build_object(
                'id', id, 'room_type', room_type, 'status', status,
                'priority', priority, 'last_message_at', last_message_at, 'created_at', created_at) AS j
              FROM public.chat_rooms
             WHERE p_member_id = ANY(participant_ids)
             ORDER BY last_message_at DESC NULLS LAST LIMIT 10) s)
        , '[]'::jsonb))
    ),
    'timeline', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'event_type', event_type, 'title', title,
            'payload', payload, 'created_at', created_at) AS j
          FROM public.member_events WHERE user_id = p_member_id
          ORDER BY created_at DESC LIMIT 20) s)
    , '[]'::jsonb),
    'permissions', jsonb_build_object(
      'can_view_location',   v_can_loc,
      'can_view_chat',       v_can_chat,
      'can_view_documents',  v_can_docs,
      'can_moderate',        v_can_mod
    )
  );
END;
$function$;


-- ===== get_member_profile =====
CREATE OR REPLACE FUNCTION public.get_member_profile(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row record;
  v_region uuid;
  v_loc boolean;
  v_docs boolean;
  v_support boolean;
  v_mod boolean;
  v_tl boolean;
  v_em boolean;
  v_region_name text;
  v_docs_row record;
  v_support_rows jsonb;
  v_mods jsonb;
  v_events jsonb;
  v_sos jsonb;
  v_result jsonb;
BEGIN
  SELECT role, user_type, verification_status, account_status, language, created_at, updated_at
  INTO v_row
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  v_region := public._ops_scope_region(public._member_region_id(p_member_id));
  IF NOT public.has_permission('MEMBER_VIEW', v_region) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  v_loc := public.has_permission('MEMBER_VIEW_LOCATION', v_region);
  v_docs := public.has_permission('MEMBER_VIEW_DOCUMENTS', v_region);
  v_support := public.has_permission('MEMBER_VIEW_CHAT_HISTORY', v_region);
  v_mod := public.has_permission('MEMBER_VIEW_COMPLAINTS', v_region)
           OR public.has_permission('MEMBER_MODERATE', v_region);
  v_tl := public.has_permission('MEMBER_VIEW_TIMELINE', v_region);
  v_em := public.has_permission('EMERGENCY_VIEW', v_region);

  v_result := jsonb_build_object(
    'member_id', p_member_id::text,
    'basic', jsonb_build_object(
      'role', v_row.role, 'user_type', v_row.user_type,
      'verification_status', v_row.verification_status,
      'account_status', v_row.account_status,
      'language', v_row.language,
      'created_at', v_row.created_at,
      'updated_at', v_row.updated_at));

  IF v_loc THEN
    SELECT r.name_en INTO v_region_name
    FROM public.user_region_preferences p
    LEFT JOIN public.regions r ON r.id = p.region_id
    WHERE p.user_id = p_member_id
    ORDER BY p.updated_at DESC
    LIMIT 1;
    v_result := v_result || jsonb_build_object(
      'location', jsonb_build_object('region_id', v_region, 'region_name', v_region_name));
  END IF;

  IF v_docs THEN
    SELECT id_card_url, trade_license_url, driving_license_url, profile_photo_url
    INTO v_docs_row
    FROM public.users WHERE id = p_member_id;
    v_result := v_result || jsonb_build_object(
      'documents', jsonb_build_object(
        'id_card_url', v_docs_row.id_card_url,
        'trade_license_url', v_docs_row.trade_license_url,
        'driving_license_url', v_docs_row.driving_license_url,
        'profile_photo_url', v_docs_row.profile_photo_url));
  END IF;

  -- Support-chat section lights up when support_rooms lands (master schema).
  IF v_support AND to_regclass('public.support_rooms') IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(
             jsonb_build_object('room_id', sr.id::text, 'created_at', sr.created_at)
             ORDER BY sr.created_at DESC), '[]'::jsonb)
    INTO v_support_rows
    FROM public.support_rooms sr
    WHERE sr.customer_id = p_member_id;
    v_result := v_result || jsonb_build_object('support', v_support_rows);
  END IF;

  IF v_mod THEN
    v_mods := jsonb_build_object(
      'complaints',
      (SELECT count(*) FROM public.complaints c
       WHERE c.respondent_id = p_member_id OR c.complainant_id = p_member_id),
      'sanctions',
      (SELECT COALESCE(jsonb_agg(
               jsonb_build_object('sanction_type', s.sanction_type, 'reason', s.reason,
                                  'start_date', s.start_date, 'end_date', s.end_date,
                                  'action_status', s.action_status)
               ORDER BY s.created_at DESC), '[]'::jsonb)
       FROM public.sanctions s WHERE s.target_user_id = p_member_id));
    v_result := v_result || jsonb_build_object('moderation', v_mods);
  END IF;

  IF v_tl THEN
    v_events := (SELECT COALESCE(jsonb_agg(
                   jsonb_build_object('event_type', e.event_type, 'created_at', e.created_at)
                   ORDER BY e.created_at DESC), '[]'::jsonb)
                 FROM (SELECT e.event_type, e.created_at
                       FROM public.member_events e
                       WHERE e.user_id = p_member_id
                       ORDER BY e.created_at DESC LIMIT 10) e);
    v_result := v_result || jsonb_build_object('timeline_summary', v_events);
  END IF;

  IF v_em THEN
    v_sos := (SELECT COALESCE(jsonb_agg(
                jsonb_build_object('id', a.id::text, 'alert_type', a.alert_type,
                                   'status', a.status, 'created_at', a.created_at)
                ORDER BY a.created_at DESC), '[]'::jsonb)
              FROM (SELECT a.id, a.alert_type, a.status, a.created_at
                    FROM public.sos_alerts a
                    WHERE a.user_id = p_member_id
                    ORDER BY a.created_at DESC LIMIT 10) a);
    v_result := v_result || jsonb_build_object('emergency', v_sos);
  END IF;

  v_result := v_result || jsonb_build_object('access', jsonb_build_object(
    'location', v_loc, 'documents', v_docs, 'support', v_support,
    'moderation', v_mod, 'timeline', v_tl, 'emergency', v_em));
  RETURN v_result;
END;
$function$;


-- ===== get_member_status =====
CREATE OR REPLACE FUNCTION public.get_member_status(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row record;
  v_ok boolean;
  v_sanctions jsonb;
BEGIN
  SELECT role, user_type, verification_status, account_status, created_at, updated_at
  INTO v_row
  FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  v_ok := (auth.uid() = p_member_id)
          OR public.has_permission('MEMBER_VIEW', public._ops_scope_region(public._member_region_id(p_member_id)));
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('id', s.id::text, 'sanction_type', s.sanction_type,
                              'reason', s.reason, 'start_date', s.start_date,
                              'end_date', s.end_date)
           ORDER BY s.created_at DESC), '[]'::jsonb)
  INTO v_sanctions
  FROM public.sanctions s
  WHERE s.target_user_id = p_member_id
    AND s.is_active
    AND s.action_status = 'active';

  RETURN jsonb_build_object(
    'member_id', p_member_id::text,
    'role', v_row.role,
    'user_type', v_row.user_type,
    'verification_status', v_row.verification_status,
    'account_status', v_row.account_status,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at,
    'active_sanctions', v_sanctions);
END;
$function$;


-- ===== get_member_timeline =====
CREATE OR REPLACE FUNCTION public.get_member_timeline(p_member_id uuid, p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_self boolean;
  v_admin boolean;
  v_rows jsonb;
BEGIN
  IF p_limit < 1 OR p_limit > 50 THEN
    RAISE EXCEPTION 'Invalid limit';
  END IF;
  v_self := auth.uid() = p_member_id;
  v_admin := public.has_permission('MEMBER_VIEW_TIMELINE', public._ops_scope_region(public._member_region_id(p_member_id)));
  IF NOT (v_self OR v_admin) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('event_type', e.event_type, 'title', e.title,
                              'payload', e.payload, 'created_at', e.created_at)
           ORDER BY e.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT e.event_type, e.title, e.payload, e.created_at
    FROM public.member_events e
    WHERE e.user_id = p_member_id
      AND (p_before IS NULL OR e.created_at < p_before)
      AND (v_self = false OR e.event_type IN (
            'account_created','login',
            'support_opened','support_resolved',
            'complaint_created','complaint_resolved',
            'moderation_action','suspension','ban',
            'sos','emergency_opened','emergency_resolved',
            'document_verified','birthday_reward','anniversary_reward',
            'account_deactivated'))
    ORDER BY e.created_at DESC
    LIMIT p_limit
  ) e;

  RETURN v_rows;
END;
$function$;


-- ===== member_financial_summary =====
CREATE OR REPLACE FUNCTION public.member_financial_summary(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_member_regid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT region_id INTO v_member_regid
    FROM public.user_region_preferences
   WHERE user_id = p_member_id ORDER BY updated_at DESC LIMIT 1;
  IF NOT public.has_permission('MEMBER_VIEW', public._ops_scope_region(v_member_regid)) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'wallet', (
      SELECT jsonb_build_object('balance', balance, 'currency', currency)
        FROM public.wallets WHERE user_id = p_member_id
    ),
    'ledger', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'id', t.id, 'type', t.type, 'amount', t.amount,
            'reference_type', t.reference_type, 'reference_id', t.reference_id,
            'balance_after', t.balance_after, 'description', t.description, 'created_at', t.created_at) AS j
          FROM public.wallet_transactions t
          JOIN public.wallets w ON w.id = t.wallet_id
         WHERE w.user_id = p_member_id
         ORDER BY t.created_at DESC LIMIT 25) s)
    , '[]'::jsonb),
    'riders_driver', (
      SELECT jsonb_build_object(
        'earnings_balance', earnings_balance,
        'gross_rides', COALESCE(SUM(r.gross), 0),
        'rides_count', COUNT(r.ride_id))
        FROM public.drivers d
        LEFT JOIN LATERAL (
          SELECT r.id AS ride_id, COALESCE(r.fare, r.base_fare, 0) AS gross
            FROM public.rides r
           WHERE r.driver_id = d.id AND r.status = 'completed'
        ) r ON true
       WHERE d.user_id = p_member_id
       GROUP BY earnings_balance
    ),
    'commissions', COALESCE((
      SELECT jsonb_agg(j)
        FROM (
          SELECT jsonb_build_object(
            'reference_type', c.reference_type, 'reference_id', c.reference_id,
            'gross_amount', c.gross_amount, 'commission_rate', c.commission_rate,
            'commission_amount', c.commission_amount, 'net_amount', c.net_amount,
            'status', c.status, 'created_at', c.created_at) AS j
          FROM public.platform_commissions c WHERE c.member_id = p_member_id
          ORDER BY c.created_at DESC LIMIT 25) s)
    , '[]'::jsonb)
  );
END;
$function$;


-- ===== list_members =====
CREATE OR REPLACE FUNCTION public.list_members(p_search text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_account_status text DEFAULT NULL::text, p_region_id uuid DEFAULT NULL::uuid, p_cursor timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, full_name text, email text, phone text, role text, account_status text, verification_status text, region_id uuid, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid    uuid := auth.uid();
  v_limit  int := LEAST(COALESCE(p_limit, 20), 50);
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  IF NOT public.has_permission('MEMBER_VIEW', NULL) THEN
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
   WHERE (p_search IS NULL
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
     AND (public._is_owner_uid(v_uid)
          OR public._is_country_admin_uid(v_uid)
          OR (up.region_id IS NOT NULL
              AND public._region_in_scope(v_uid, up.region_id)))
     AND (p_cursor IS NULL OR u.created_at < p_cursor)
   ORDER BY u.created_at DESC
   LIMIT v_limit;
END;
$function$;


-- ===== admin_update_member_profile =====
CREATE OR REPLACE FUNCTION public.admin_update_member_profile(p_member_id uuid, p_full_name text DEFAULT NULL::text, p_phone text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_target_role text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT role INTO v_target_role FROM public.users WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF public._is_active_admin_uid(p_member_id) THEN
    RAISE EXCEPTION 'Admins are managed through the admin lifecycle';
  END IF;
  IF NOT public.has_permission('MEMBER_MODERATE', public._ops_scope_region(public._member_region_id(p_member_id))) THEN
    RAISE EXCEPTION 'Not authorized for this member';
  END IF;
  IF p_full_name IS NULL AND p_phone IS NULL THEN
    RAISE EXCEPTION 'Nothing to update';
  END IF;

  UPDATE public.users
     SET full_name = COALESCE(NULLIF(btrim(p_full_name), ''), full_name),
         phone = COALESCE(NULLIF(btrim(p_phone), ''), phone),
         updated_at = now()
   WHERE id = p_member_id;

  PERFORM public.write_audit(
    'MEMBER_PROFILE_UPDATED',
    'users',
    p_member_id::text,
    jsonb_build_object(
      'full_name', p_full_name,
      'phone', p_phone
    )
  );
END;
$function$;


-- ===== decide_user_verification =====
CREATE OR REPLACE FUNCTION public.decide_user_verification(p_user_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_current text;
  v_new text;
  v_has_docs boolean;
  v_target_regid uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  IF p_decision = 'reject'
     AND btrim(COALESCE(p_reason, '')) = '' THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  SELECT region_id INTO v_target_regid
    FROM public.user_region_preferences
   WHERE user_id = p_user_id
   ORDER BY updated_at DESC
   LIMIT 1;

  IF NOT (public._is_owner_uid(auth.uid())
          OR (v_target_regid IS NOT NULL
              AND public.has_permission('MEMBER_MODERATE', public._ops_scope_region(v_target_regid)))) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT verification_status,
         id_card_url IS NOT NULL AND profile_photo_url IS NOT NULL
    INTO v_current, v_has_docs
    FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_current NOT IN ('pending', 'rejected') THEN
    RAISE EXCEPTION 'Verification already decided';
  END IF;

  v_new := CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END;

  UPDATE public.users
    SET verification_status = v_new,
        rejection_reason = CASE
          WHEN p_decision = 'reject' THEN btrim(p_reason)
          ELSE NULL
        END,
        rejection_reason_at = CASE
          WHEN p_decision = 'reject' THEN now()
          ELSE NULL
        END,
        updated_at = now()
    WHERE id = p_user_id;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_user_id,
    CASE WHEN p_decision = 'approve' THEN 'Verification approved'
         ELSE 'Verification rejected' END,
    CASE WHEN p_decision = 'approve'
         THEN 'You can now use the platform.'
         ELSE COALESCE(btrim(p_reason), 'Please review your documents.') END,
    'verification',
    jsonb_build_object(
      'status', v_new,
      'reason', p_reason
    ),
    CASE WHEN p_decision = 'approve' THEN '/profile' ELSE '/pending-verification' END,
    'verification-decide-' || p_user_id::text || '-' || gen_random_uuid()::text
  );

  PERFORM public.write_audit(
    'VERIFICATION_DECIDED',
    'users',
    p_user_id::text,
    jsonb_build_object(
      'decision', p_decision,
      'reason', p_reason,
      'had_documents', v_has_docs
    )
  );
END;
$function$;


-- ===== escalate_complaint =====
CREATE OR REPLACE FUNCTION public.escalate_complaint(p_complaint_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_complaint public.complaints%ROWTYPE;
  v_region uuid;
  v_current uuid;
  v_next uuid;
  v_prev_scope text;
  v_new_scope text;
  v_assignee uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Escalation requires a reason';
  END IF;

  -- Prove server-origin to complaints_fixup_update (RPC path marker).
  PERFORM set_config('app.escalation_rpc', 'true', true);

  SELECT * INTO v_complaint
    FROM public.complaints WHERE id = p_complaint_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complaint not found';
  END IF;
  IF v_complaint.status IN ('resolved','rejected','dismissed') THEN
    RAISE EXCEPTION 'Complaint is already closed';
  END IF;

  v_region := public._member_region_id(v_complaint.complainant_id);
  IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', public._ops_scope_region(v_region)) THEN
    RAISE EXCEPTION 'Not authorized for this complaint region';
  END IF;

  v_current := v_complaint.assigned_admin_id;
  v_prev_scope := CASE
    WHEN v_current IS NULL THEN 'unassigned'
    WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner') THEN 'owner'
    WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current) THEN 'scoped'
    ELSE 'global'
  END;

  -- Owner/escalator terminal -> owner queue.
  IF v_current IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner'
  ) THEN
    UPDATE public.complaints
       SET status = 'escalated',
           assigned_admin_id = NULL,
           escalated_at = now(),
           escalated_from_admin_id = auth.uid(),
           updated_at = now()
     WHERE id = p_complaint_id;
    INSERT INTO public.escalation_events
      (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
       previous_scope, new_scope)
    VALUES ('complaint', p_complaint_id, v_current, NULL, auth.uid(), p_reason,
            v_prev_scope, 'owner');
    PERFORM public.write_audit(
      'COMPLAINT_ESCALATED', 'complaints', p_complaint_id::text,
      jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                         'to_admin_id', NULL, 'terminal', true)
    );
    RETURN;
  END IF;

  -- Strict upward routing: an already-owner-queued complaint is terminal.
  IF v_current IS NULL AND EXISTS (
    SELECT 1 FROM public.escalation_events e
     WHERE e.entity_type = 'complaint'
       AND e.entity_id = p_complaint_id
       AND e.new_scope = 'owner'
  ) THEN
    RETURN;
  END IF;

  -- Route to the NEXT HIGHER tier from the current assignee (never down):
  --   unassigned -> best regional (else global/owner)
  --   scoped     -> global tier (else owner)
  --   global     -> owner queue (terminal)
  IF v_current IS NULL THEN
    v_next := public.resolve_support_admin(v_region, true, NULL);
  ELSIF EXISTS (
    SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current
  ) THEN
    v_next := public.resolve_support_admin(v_region, false, v_current);
  ELSE
    v_next := NULL;
  END IF;
  IF v_next IS NULL OR v_next = v_current THEN
    v_assignee := NULL;
    v_new_scope := 'owner';
  ELSE
    v_assignee := v_next;
    v_new_scope := CASE
      WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_next AND role = 'owner') THEN 'owner'
      WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_next) THEN 'scoped'
      ELSE 'global'
    END;
  END IF;

  UPDATE public.complaints
     SET status = 'escalated',
         assigned_admin_id = v_assignee,
         escalated_at = now(),
         escalated_from_admin_id = auth.uid(),
         updated_at = now()
   WHERE id = p_complaint_id;

  INSERT INTO public.escalation_events
    (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES ('complaint', p_complaint_id, v_current, v_next, auth.uid(), p_reason,
          v_prev_scope, v_new_scope);

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_complaint.complainant_id, 'complaint_escalated',
          jsonb_build_object('complaint_id', p_complaint_id::text,
                             'escalated_by', auth.uid()::text))
  ON CONFLICT DO NOTHING;

  IF v_assignee IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES (
      v_assignee,
      'Escalated complaint assigned',
      'An escalated complaint requires your review.',
      'complaint_escalated',
      jsonb_build_object('entity_type', 'complaint',
                         'entity_id', p_complaint_id::text,
                         'action', 'escalated'),
      '/admin/complaints',
      'complaint-escalated-' || p_complaint_id::text || '-' || v_assignee::text,
      auth.uid(), 'high', true
    )
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
  END IF;

  PERFORM public.write_audit(
    'COMPLAINT_ESCALATED', 'complaints', p_complaint_id::text,
    jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                       'to_admin_id', v_next, 'previous_scope', v_prev_scope,
                       'new_scope', v_new_scope)
  );
END;
$function$;


-- ===== assign_complaint =====
CREATE OR REPLACE FUNCTION public.assign_complaint(p_complaint_id uuid, p_admin_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_complaint public.complaints%ROWTYPE;
  v_region uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Prove server-origin to complaints_fixup_update (RPC path marker).
  PERFORM set_config('app.escalation_rpc', 'true', true);

  SELECT * INTO v_complaint
    FROM public.complaints WHERE id = p_complaint_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complaint not found';
  END IF;
  IF v_complaint.status IN ('resolved','rejected','dismissed') THEN
    RAISE EXCEPTION 'Complaint is already closed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_admin_id AND role IN ('admin','owner')
  ) THEN
    RAISE EXCEPTION 'Assignee must be an admin';
  END IF;

  v_region := public._member_region_id(v_complaint.complainant_id);
  IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', public._ops_scope_region(v_region)) THEN
    RAISE EXCEPTION 'Not authorized for this complaint region';
  END IF;
  IF p_admin_id <> auth.uid()
     AND NOT public.is_admin_for_region(v_region) THEN
    RAISE EXCEPTION 'Assignee must be in scope for the complaint region';
  END IF;

  UPDATE public.complaints
     SET status = 'escalated',
         assigned_admin_id = p_admin_id,
         escalated_at = now(),
         escalated_from_admin_id = auth.uid(),
         updated_at = now()
   WHERE id = p_complaint_id;

  INSERT INTO public.escalation_events
    (entity_type, entity_id, from_admin_id, to_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES ('complaint', p_complaint_id,
          v_complaint.assigned_admin_id, p_admin_id, auth.uid(),
          'Assigned to admin',
          CASE WHEN v_complaint.assigned_admin_id IS NULL THEN 'unassigned'
               ELSE 'assigned' END,
          CASE WHEN EXISTS (SELECT 1 FROM public.users
                            WHERE id = p_admin_id AND role = 'owner')
               THEN 'owner' ELSE 'scoped' END);

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_complaint.complainant_id, 'complaint_assigned',
          jsonb_build_object('complaint_id', p_complaint_id::text,
                             'assigned_to', p_admin_id::text))
  ON CONFLICT DO NOTHING;

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key,
     sender_id, priority, send_push)
  VALUES (
    p_admin_id,
    'Complaint assigned to you',
    'A complaint has been assigned to you for review.',
    'complaint_assigned',
    jsonb_build_object('entity_type', 'complaint',
                       'entity_id', p_complaint_id::text,
                       'action', 'assigned'),
    '/admin/complaints',
    'complaint-assigned-' || p_complaint_id::text || '-' || p_admin_id::text,
    auth.uid(), 'high', true
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

  PERFORM public.write_audit(
    'COMPLAINT_ASSIGNED', 'complaints', p_complaint_id::text,
    jsonb_build_object('from_admin_id', auth.uid(),
                       'to_admin_id', p_admin_id)
  );
END;
$function$;


-- ===== get_escalation_events =====
CREATE OR REPLACE FUNCTION public.get_escalation_events(p_complaint_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows jsonb;
  v_region uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_complaint_id IS NOT NULL THEN
    SELECT public._member_region_id(c.complainant_id)
      INTO v_region FROM public.complaints c WHERE c.id = p_complaint_id;
    IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', public._ops_scope_region(v_region)) THEN
      RAISE EXCEPTION 'Not authorized for this complaint region';
    END IF;
    SELECT jsonb_agg(to_jsonb(e) ORDER BY e.created_at DESC)
      INTO v_rows
      FROM public.escalation_events e
     WHERE e.entity_type = 'complaint' AND e.entity_id = p_complaint_id;
  ELSE
    SELECT jsonb_agg(to_jsonb(e) ORDER BY e.created_at DESC)
      INTO v_rows
      FROM public.escalation_events e
     WHERE e.entity_type = 'complaint'
       AND (
         public.has_permission('MEMBER_VIEW_COMPLAINTS', public._ops_scope_region(NULL))
         OR EXISTS (
           SELECT 1 FROM public.complaints c
           WHERE c.id = e.entity_id
             AND public.has_permission(
                   'MEMBER_VIEW_COMPLAINTS',
                   public._member_region_id(c.complainant_id))
         )
       );
  END IF;

  RETURN COALESCE(v_rows, '[]'::jsonb);
END;
$function$;


-- ===== cashier_apply_moh_prices =====
CREATE OR REPLACE FUNCTION public.cashier_apply_moh_prices(p_merchant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
  SELECT p.merchant_id, p.id, p.price, d.official_price_egp, 'moh_update', v_uid
    FROM public.products p
    JOIN public.drug_catalog d ON d.barcode IS NOT NULL AND d.barcode = p.barcode
   WHERE p.merchant_id = p_merchant_id
     AND d.official_price_egp IS NOT NULL
     AND p.price IS DISTINCT FROM d.official_price_egp;
  UPDATE public.products p
     SET price = d.official_price_egp, updated_at = now()
    FROM public.drug_catalog d
   WHERE p.merchant_id = p_merchant_id
     AND d.barcode IS NOT NULL AND d.barcode = p.barcode
     AND d.official_price_egp IS NOT NULL
     AND p.price IS DISTINCT FROM d.official_price_egp;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'updated', v_count);
END;
$function$;


-- ===== cashier_daily_close =====
CREATE OR REPLACE FUNCTION public.cashier_daily_close(p_merchant_id uuid, p_shift_id uuid, p_closing_cash numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_shift record;
  v_cash numeric; v_sales numeric; v_count integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_shift FROM public.pos_shifts
   WHERE id = p_shift_id AND merchant_id = p_merchant_id AND closed_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', 'SHIFT_NOT_OPEN'); END IF;
  SELECT COALESCE(sum(s.total_amount), 0), count(*) INTO v_sales, v_count
    FROM public.pos_sales s WHERE s.shift_id = p_shift_id AND s.status = 'completed';
  SELECT COALESCE(sum(p.amount), 0) INTO v_cash
    FROM public.pos_sale_payments p JOIN public.pos_sales s ON s.id = p.sale_id
   WHERE s.shift_id = p_shift_id AND s.status = 'completed' AND p.method = 'cash';
  -- Sales synced from the web POS have no pos_sale_payments rows; count their
  -- cash through the single payment_method column.
  v_cash := v_cash + COALESCE((SELECT sum(s.total_amount) FROM public.pos_sales s
    WHERE s.shift_id = p_shift_id AND s.status = 'completed' AND s.payment_method = 'cash'
      AND NOT EXISTS (SELECT 1 FROM public.pos_sale_payments p WHERE p.sale_id = s.id)), 0);
  UPDATE public.pos_shifts
     SET closed_at = now(), closing_cash = p_closing_cash,
         expected_cash = v_shift.opening_float + v_cash,
         totals = jsonb_build_object('sales_total', v_sales, 'sale_count', v_count,
                                     'cash_in', v_cash, 'opening_float', v_shift.opening_float)
   WHERE id = p_shift_id;
  RETURN jsonb_build_object('ok', true, 'expected_cash', v_shift.opening_float + v_cash,
                            'sales_total', v_sales, 'sale_count', v_count);
END;
$function$;


-- ===== cashier_set_reorder_level =====
CREATE OR REPLACE FUNCTION public.cashier_set_reorder_level(p_merchant_id uuid, p_product_id uuid, p_level integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  UPDATE public.products SET reorder_level = p_level, updated_at = now()
   WHERE id = p_product_id AND merchant_id = p_merchant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
  RETURN jsonb_build_object('ok', true);
END;
$function$;


-- ===== cashier_shortage_list =====
CREATE OR REPLACE FUNCTION public.cashier_shortage_list(p_merchant_id uuid, p_default_level integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'items', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.name, 'name_ar', p.name_ar, 'barcode', p.barcode,
               'stock', p.stock_quantity,
               'reorder_level', COALESCE(p.reorder_level, p_default_level))
               ORDER BY p.stock_quantity ASC, p.name), '[]'::jsonb)
             FROM public.products p
             WHERE p.merchant_id = p_merchant_id AND p.is_available
               AND p.stock_quantity <= COALESCE(p.reorder_level, p_default_level)));
END;
$function$;


-- ===== cashier_sync_pull =====
CREATE OR REPLACE FUNCTION public.cashier_sync_pull(p_merchant_id uuid, p_since timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'server_time', now(),
    'products', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'name_ar', p.name_ar, 'price', p.price,
        'stock', p.stock_quantity, 'reorder_level', p.reorder_level, 'barcode', p.barcode, 'updated_at', p.updated_at)), '[]'::jsonb)
       FROM public.products p
      WHERE p.merchant_id = p_merchant_id
        AND (p_since IS NULL OR p.updated_at > p_since)),
    'customers', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'phone', c.phone,
        'balance', COALESCE((SELECT sum(CASE WHEN l.kind='charge' THEN l.amount ELSE -l.amount END)
                              FROM public.pos_debt_ledger l WHERE l.customer_id = c.id), 0))), '[]'::jsonb)
       FROM public.pos_customers c WHERE c.merchant_id = p_merchant_id AND c.is_active),
    'open_shift', (SELECT jsonb_build_object('id', s.id, 'opened_at', s.opened_at, 'opening_float', s.opening_float)
       FROM public.pos_shifts s WHERE s.merchant_id = p_merchant_id AND s.closed_at IS NULL
       ORDER BY s.opened_at DESC LIMIT 1)
  );
END;
$function$;


-- ===== cashier_sync_push =====
CREATE OR REPLACE FUNCTION public.cashier_sync_push(p_merchant_id uuid, p_ops jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_op jsonb;
  v_type text;
  v_op_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_sale_id uuid;
  v_shift_id uuid;
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_pay jsonb;
  v_deferred numeric;
  v_prod uuid;
  v_qty numeric;
  v_old_price numeric;
  v_new_price numeric;
  v_pct numeric;
  v_lines jsonb;
  v_subtotal numeric;
  v_rate numeric;
  v_primary_method text;
  v_company uuid;
  v_server_price numeric;
  v_unit numeric;
  v_line_disc numeric;
  v_discount numeric;
  v_total numeric;
  v_applied numeric;
  v_prev_stock integer;
  v_cp boolean;
  v_line_repriced boolean;
  v_client_priced integer;
  v_repriced integer;
  v_server_total numeric;
  v_mismatch boolean;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF jsonb_typeof(p_ops) <> 'array' THEN RAISE EXCEPTION 'ops must be an array'; END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;

  FOR v_op IN SELECT * FROM jsonb_array_elements(p_ops) LOOP
    v_type := v_op->>'type';
    v_op_id := (v_op->>'op_id')::uuid;
    BEGIN
      CASE v_type
      WHEN 'customer' THEN
        INSERT INTO public.pos_customers (merchant_id, client_op_id, name, phone, notes)
        VALUES (p_merchant_id, v_op_id, v_op->'payload'->>'name', v_op->'payload'->>'phone', v_op->'payload'->>'notes')
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'shift_open' THEN
        v_shift_id := NULL;
        INSERT INTO public.pos_shifts (merchant_id, client_op_id, opened_by, opening_float, created_offline_at)
        VALUES (p_merchant_id, v_op_id, v_uid, COALESCE((v_op->'payload'->>'opening_float')::numeric, 0),
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING
        RETURNING id INTO v_shift_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'shift_id', v_shift_id);
      WHEN 'sale' THEN
        -- Offline sale recorded as fact into the shared pos_sales table, but
        -- money is repriced SERVER-SIDE (review #26): any line whose
        -- product_id resolves is priced from public.products (through the
        -- shared _price_order_line helper for whole-number quantities), and
        -- commission is charged on the server total. Lines only the client
        -- could price (catalog-only offline drugs) are flagged client_priced
        -- and counted in the result for quarantine review.
        v_sale_id := NULL;
        v_lines := '[]'::jsonb;
        v_subtotal := 0;
        v_deferred := 0;
        v_primary_method := NULL;
        v_client_priced := 0;
        v_repriced := 0;
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          v_unit := NULL;
          v_cp := false;
          v_line_repriced := false;
          IF v_prod IS NOT NULL THEN
            SELECT p.price INTO v_server_price
              FROM public.products p
             WHERE p.id = v_prod AND p.merchant_id = p_merchant_id;
            IF FOUND THEN
              v_unit := v_server_price;
              IF v_qty = trunc(v_qty) AND v_qty BETWEEN 1 AND 50 THEN
                BEGIN
                  v_unit := (public._price_order_line(p_merchant_id,
                    jsonb_build_object('product_id', v_prod, 'quantity', v_qty::int),
                    false)->>'unit_price')::numeric;
                EXCEPTION WHEN OTHERS THEN
                  -- Delisted or edge product: fall back to its last known price.
                  v_unit := v_server_price;
                END;
              END IF;
              IF v_unit IS DISTINCT FROM (v_item->>'unit_price')::numeric THEN
                v_line_repriced := true;
                v_repriced := v_repriced + 1;
              END IF;
            END IF;
          END IF;
          IF v_unit IS NULL THEN
            -- Offline-only drug with no store product row: only the client
            -- could price it. Keep the claimed price, flag the line.
            v_unit := (v_item->>'unit_price')::numeric;
            v_cp := true;
            v_client_priced := v_client_priced + 1;
          END IF;
          v_line_disc := LEAST(GREATEST(COALESCE((v_item->>'discount_amount')::numeric, 0), 0),
                               v_unit * v_qty);
          v_lines := v_lines || jsonb_build_object(
            'product_id', v_prod,
            'drug_catalog_id', NULLIF(v_item->>'drug_catalog_id','')::uuid,
            'name', v_item->>'name',
            'qty', v_qty,
            'unit_price', v_unit,
            'discount', v_line_disc,
            'line_total', v_unit * v_qty - v_line_disc,
            'is_weight_based', COALESCE((v_item->>'is_weight_based')::boolean, false),
            'client_priced', v_cp,
            'repriced', v_line_repriced);
          v_subtotal := v_subtotal + (v_unit * v_qty - v_line_disc);
        END LOOP;
        v_discount := LEAST(GREATEST(COALESCE((v_op->'payload'->>'discount_amount')::numeric, 0), 0),
                            v_subtotal);
        v_total := v_subtotal - v_discount;
        INSERT INTO public.pos_sales
          (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
           payment_method, customer_name, notes, idempotency_key,
           shift_id, pos_customer_id, created_offline_at, created_at,
           client_priced_lines)
        VALUES
          (p_merchant_id, v_uid, v_lines,
           v_subtotal, v_discount, v_total,
           COALESCE(v_op->'payload'->'payments'->0->>'method', 'cash'),
           v_op->'payload'->>'customer_name',
           v_op->'payload'->>'notes', v_op_id::text,
           NULLIF(v_op->'payload'->>'shift_id','')::uuid,
           NULLIF(v_op->'payload'->>'customer_id','')::uuid,
           (v_op->>'created_offline_at')::timestamptz,
           now(),
           v_client_priced)
        ON CONFLICT (idempotency_key) DO NOTHING
        RETURNING id INTO v_sale_id;
        IF v_sale_id IS NULL THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'duplicate', true);
          CONTINUE;
        END IF;
        -- Stock: best-effort decrement for tracked products. The APPLIED
        -- (clamped) decrement goes into the move so جرد reconciles, and the
        -- line carries stock_applied so a later void can't over-restore
        -- (review #31).
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'items') LOOP
          v_prod := NULLIF(v_item->>'product_id','')::uuid;
          v_qty := (v_item->>'qty')::numeric;
          IF v_prod IS NOT NULL THEN
            SELECT p.stock_quantity INTO v_prev_stock FROM public.products p
             WHERE p.id = v_prod;
            IF v_prev_stock IS NOT NULL THEN
              v_applied := LEAST(v_prev_stock, v_qty);
              UPDATE public.products
                 SET stock_quantity = GREATEST(0, stock_quantity - v_qty::int), updated_at = now()
               WHERE id = v_prod;
              INSERT INTO public.pos_stock_moves (merchant_id, product_id, kind, qty, created_by, created_offline_at)
              VALUES (p_merchant_id, v_prod, 'sale', -v_applied, v_uid, (v_op->>'created_offline_at')::timestamptz);
              UPDATE public.pos_sales s
                 SET items = (SELECT jsonb_agg(CASE WHEN NULLIF(l->>'product_id','')::uuid IS NOT DISTINCT FROM v_prod
                                                    AND (l->>'stock_applied') IS NULL
                                                    THEN l || jsonb_build_object('stock_applied', v_applied)
                                                    ELSE l END)
                                FROM jsonb_array_elements(s.items) l)
               WHERE s.id = v_sale_id;
            END IF;
          END IF;
        END LOOP;
        FOR v_pay IN SELECT * FROM jsonb_array_elements(v_op->'payload'->'payments') LOOP
          INSERT INTO public.pos_sale_payments (sale_id, method, amount)
          VALUES (v_sale_id, v_pay->>'method', (v_pay->>'amount')::numeric);
          IF v_pay->>'method' = 'deferred' THEN v_deferred := v_deferred + (v_pay->>'amount')::numeric; END IF;
        END LOOP;
        IF v_deferred > 0 AND NULLIF(v_op->'payload'->>'customer_id','') IS NOT NULL THEN
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, created_by, created_offline_at)
          VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid,
                  v_sale_id, 'charge', v_deferred, v_uid, (v_op->>'created_offline_at')::timestamptz);
        END IF;
        -- Same commission posting as pos_create_sale, on the SERVER total.
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
        IF v_rate > 0 THEN
          INSERT INTO public.platform_commissions
            (member_id, reference_type, reference_id, gross_amount, commission_rate,
             commission_amount, net_amount, currency, status)
          VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id,
                  v_total, v_rate,
                  public.calculate_commission(v_total, v_rate),
                  v_total - public.calculate_commission(v_total, v_rate),
                  'EGP', 'computed')
          ON CONFLICT (reference_type, reference_id) DO NOTHING;
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'sale_id', v_sale_id, 'total', v_total,
          'repriced', v_repriced, 'client_priced', v_client_priced);
      WHEN 'sale_void' THEN
        SELECT id INTO v_sale_id FROM public.pos_sales
         WHERE merchant_id = p_merchant_id AND idempotency_key = (v_op->'payload'->>'sale_op_id')
           AND status = 'completed';
        IF v_sale_id IS NOT NULL THEN
          PERFORM public.pos_void_sale(v_sale_id, v_op->'payload'->>'reason');
          -- #28: reverse أجل charges with explicit reversal entries (the old
          -- code flipped charges to payments, driving the balance negative).
          INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, sale_id, kind, amount, note, created_by)
          SELECT d.merchant_id, d.customer_id, d.sale_id, 'reversal', d.amount,
                 'عكس مديونية لإلغاء العملية', v_uid
            FROM public.pos_debt_ledger d
           WHERE d.sale_id = v_sale_id AND d.kind = 'charge'
             AND NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger r
                              WHERE r.sale_id = d.sale_id AND r.kind = 'reversal');
          -- #31: pos_void_sale restores the FULL line qty, but the sale only
          -- decremented the clamped amount. Correct the over-restore.
          FOR v_item IN SELECT * FROM jsonb_array_elements(
                (SELECT items FROM public.pos_sales WHERE id = v_sale_id)) LOOP
            v_prod := NULLIF(v_item->>'product_id','')::uuid;
            v_qty := COALESCE((v_item->>'qty')::numeric, 0);
            v_applied := COALESCE((v_item->>'stock_applied')::numeric, v_qty);
            IF v_prod IS NOT NULL AND v_qty > v_applied THEN
              UPDATE public.products
                 SET stock_quantity = GREATEST(0, stock_quantity - (v_qty - v_applied)::int),
                     updated_at = now()
               WHERE id = v_prod AND stock_quantity IS NOT NULL;
              INSERT INTO public.pos_stock_moves (merchant_id, product_id, kind, qty, note, created_by)
              VALUES (p_merchant_id, v_prod, 'count_adjustment', -(v_qty - v_applied),
                      'تصحيح استرجاع الإلغاء', v_uid);
            END IF;
          END LOOP;
          INSERT INTO public.pos_stock_moves (merchant_id, kind, qty, note, created_by)
          VALUES (p_merchant_id, 'void_restore', 0, 'void of sale ' || v_sale_id::text, v_uid);
        END IF;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true, 'sale_id', v_sale_id);
      WHEN 'debt_payment' THEN
        INSERT INTO public.pos_debt_ledger (merchant_id, customer_id, client_op_id, kind, amount, note, created_by, created_offline_at)
        VALUES (p_merchant_id, (v_op->'payload'->>'customer_id')::uuid, v_op_id, 'payment',
                (v_op->'payload'->>'amount')::numeric, v_op->'payload'->>'note', v_uid,
                (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'stock_count' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_qty := (v_op->'payload'->>'counted')::numeric;
        INSERT INTO public.pos_stock_moves (merchant_id, product_id, client_op_id, kind, qty, note, created_by, created_offline_at)
        VALUES (p_merchant_id, v_prod, v_op_id, 'count_adjustment',
                v_qty - COALESCE((SELECT stock_quantity FROM public.products WHERE id = v_prod), 0),
                v_op->'payload'->>'note', v_uid, (v_op->>'created_offline_at')::timestamptz)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        UPDATE public.products SET stock_quantity = v_qty::int, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'price_change' THEN
        v_prod := (v_op->'payload'->>'product_id')::uuid;
        v_new_price := (v_op->'payload'->>'new_price')::numeric;
        SELECT price INTO v_old_price FROM public.products WHERE id = v_prod AND merchant_id = p_merchant_id;
        UPDATE public.products SET price = v_new_price, updated_at = now()
         WHERE id = v_prod AND merchant_id = p_merchant_id;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        VALUES (p_merchant_id, v_prod, v_old_price, v_new_price, COALESCE(v_op->'payload'->>'source','manual'), v_uid);
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'bulk_price_pct' THEN
        v_pct := (v_op->'payload'->>'pct')::numeric;
        INSERT INTO public.pos_price_history (merchant_id, product_id, old_price, new_price, source, changed_by)
        SELECT p_merchant_id, id, price, round(price * (1 + v_pct / 100), 2), 'bulk_pct', v_uid
          FROM public.products WHERE merchant_id = p_merchant_id AND is_available;
        UPDATE public.products
           SET price = round(price * (1 + v_pct / 100), 2), updated_at = now()
         WHERE merchant_id = p_merchant_id AND is_available;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true);
      WHEN 'insurance_sale' THEN
        -- Insured sale (تأمين): the insured part is billed to the company,
        -- the patient pays their share. Idempotent on the client op id.
        v_company := (v_op->'payload'->>'company_id')::uuid;
        v_sale_id := NULL;
        IF NULLIF(v_op->'payload'->>'sale_op_id','') IS NOT NULL THEN
          SELECT id INTO v_sale_id FROM public.pos_sales
           WHERE merchant_id = p_merchant_id
             AND idempotency_key = (v_op->'payload'->>'sale_op_id');
        END IF;
        -- Review #32: the shares are client-claimed and feed
        -- pos_insurance_statement. They must at least sum to the claimed
        -- total; otherwise the op is rejected.
        IF abs(COALESCE((v_op->'payload'->>'company_share')::numeric, 0)
             + COALESCE((v_op->'payload'->>'patient_share')::numeric, 0)
             - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
          v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false,
            'reason', 'INSURANCE_SHARE_MISMATCH');
          CONTINUE;
        END IF;
        -- Review #32: when the linked sale resolved, compare the claimed
        -- total with the SERVER-repriced pos_sales total. A mismatch is
        -- quarantined (recorded with total_mismatch + the server total),
        -- same pattern as client_priced, never silently trusted.
        v_server_total := NULL;
        v_mismatch := false;
        IF v_sale_id IS NOT NULL THEN
          SELECT s.total_amount INTO v_server_total
            FROM public.pos_sales s WHERE s.id = v_sale_id;
          IF v_server_total IS NOT NULL
             AND abs(v_server_total - (v_op->'payload'->>'total')::numeric) > 0.01 THEN
            v_mismatch := true;
          END IF;
        END IF;
        INSERT INTO public.pos_insurance_sales
          (merchant_id, company_id, sale_id, client_op_id, member_name, member_card_no,
           total, company_share, patient_share, created_by, created_offline_at,
           server_total, total_mismatch)
        VALUES
          (p_merchant_id, v_company, v_sale_id, v_op_id,
           v_op->'payload'->>'member_name', v_op->'payload'->>'member_card_no',
           (v_op->'payload'->>'total')::numeric,
           (v_op->'payload'->>'company_share')::numeric,
           (v_op->'payload'->>'patient_share')::numeric,
           v_uid, (v_op->>'created_offline_at')::timestamptz,
           v_server_total, v_mismatch)
        ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', true,
          'server_total', v_server_total, 'total_mismatch', v_mismatch);
      ELSE
        v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', 'UNKNOWN_OP');
      END CASE;
    EXCEPTION WHEN OTHERS THEN
      v_results := v_results || jsonb_build_object('op_id', v_op_id, 'ok', false, 'reason', SQLERRM);
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$function$;


-- ===== pharmacy_directory =====
CREATE OR REPLACE FUNCTION public.pharmacy_directory(p_merchant_id uuid)
 RETURNS TABLE(merchant_id uuid, name text, name_ar text, address text, phone text, link_id uuid, link_status text, balance numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN QUERY
    SELECT m.id, m.name, NULLIF('', ''), m.address, m.phone,
           k.id, k.status,
           COALESCE((SELECT sum(CASE
               WHEN (k.pharmacy_a = p_merchant_id) THEN l.cash_amount
               ELSE -l.cash_amount END)
             FROM public.pharmacy_transfer_ledger l WHERE l.link_id = k.id), 0)
      FROM public.pharmacy_links k
      JOIN public.merchants m ON m.id = CASE WHEN k.pharmacy_a = p_merchant_id THEN k.pharmacy_b ELSE k.pharmacy_a END
     WHERE (k.pharmacy_a = p_merchant_id OR k.pharmacy_b = p_merchant_id)
       AND k.status = 'active';
END;
$function$;


-- ===== pharmacy_link_create =====
CREATE OR REPLACE FUNCTION public.pharmacy_link_create(p_merchant_id uuid, p_other_merchant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_a uuid; v_b uuid; v_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_merchant_id = p_other_merchant_id THEN RAISE EXCEPTION 'cannot link self'; END IF;
  v_a := LEAST(p_merchant_id, p_other_merchant_id);
  v_b := GREATEST(p_merchant_id, p_other_merchant_id);
  INSERT INTO public.pharmacy_links (pharmacy_a, pharmacy_b, created_by)
  VALUES (v_a, v_b, v_uid)
  ON CONFLICT (pharmacy_a, pharmacy_b) DO UPDATE SET status = 'active'
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'link_id', v_id);
END;
$function$;


-- ===== pos_insurance_statement =====
CREATE OR REPLACE FUNCTION public.pos_insurance_statement(p_merchant_id uuid, p_company_id uuid, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  RETURN jsonb_build_object(
    'ok', true,
    'company_id', p_company_id,
    'from', p_from, 'to', p_to,
    'count', (SELECT count(*) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'total', (SELECT COALESCE(sum(s.total), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'company_share', (SELECT COALESCE(sum(s.company_share), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'patient_share', (SELECT COALESCE(sum(s.patient_share), 0) FROM public.pos_insurance_sales s
               WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
                 AND s.created_at >= p_from AND s.created_at < p_to),
    'rows', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', s.id, 'sale_id', s.sale_id, 'member_name', s.member_name,
               'member_card_no', s.member_card_no, 'total', s.total,
               'company_share', s.company_share, 'patient_share', s.patient_share,
               'created_at', s.created_at) ORDER BY s.created_at), '[]'::jsonb)
             FROM public.pos_insurance_sales s
             WHERE s.merchant_id = p_merchant_id AND s.company_id = p_company_id
               AND s.created_at >= p_from AND s.created_at < p_to));
END;
$function$;


-- ===== cashier_license_validate =====
CREATE OR REPLACE FUNCTION public.cashier_license_validate(p_license_key text, p_device_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_l record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_l FROM public.cashier_licenses WHERE license_key = p_license_key FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', 'UNKNOWN_KEY'); END IF;
  IF NOT public.is_merchant_owner(v_l.merchant_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_AUTHORIZED');
  END IF;
  IF v_l.status = 'suspended' THEN RETURN jsonb_build_object('ok', false, 'reason', 'SUSPENDED'); END IF;
  IF v_l.device_id IS NULL AND p_device_id IS NOT NULL THEN
    -- First contact binds the device, whatever the starting status was
    -- (trial keys start active, paid keys start issued).
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
  RETURN jsonb_build_object('ok', true, 'plan', v_l.plan, 'status', 'active',
    'expires_at', v_l.expires_at, 'merchant_id', v_l.merchant_id);
END;
$function$;


-- ===== cashier_license_issue =====
CREATE OR REPLACE FUNCTION public.cashier_license_issue(p_merchant_id uuid, p_plan text, p_days integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_plan NOT IN ('trial','core_monthly','core_quarterly','core_semiannual','core_annual','core_lifetime') THEN
    RAISE EXCEPTION 'Invalid plan %', p_plan;
  END IF;
  -- Review #27: merchant owners self-issue the trial only. Paid plans are
  -- issued by an admin after payment is collected (payment gate).
  IF p_plan <> 'trial' AND NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'PAID_PLANS_REQUIRE_ADMIN';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'Not authorized';
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


-- ===== pharmacy_transfer_handover =====
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_handover(p_transfer_id uuid, p_cash_value numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
  v_sign integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT public.is_merchant_owner(v_t.lending_merchant) THEN
    RAISE EXCEPTION 'Only the lending pharmacy logs the handover';
  END IF;
  IF v_t.status <> 'accepted' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ACCEPTED'); END IF;
  UPDATE public.pharmacy_transfer_requests SET status = 'handed_over',
         agreed_cash_value = COALESCE(p_cash_value, agreed_cash_value), updated_at = now()
   WHERE id = p_transfer_id;
  -- Borrow: requester owes lender. cash_amount positive = pharmacy_a owes b.
  SELECT CASE WHEN v_t.requesting_merchant = k.pharmacy_a THEN 1 ELSE -1 END
    INTO v_sign FROM public.pharmacy_links k WHERE k.id = v_t.link_id;
  INSERT INTO public.pharmacy_transfer_ledger
    (link_id, transfer_id, entry_type, item_desc, qty, cash_amount, created_by)
  VALUES (v_t.link_id, p_transfer_id, 'borrow', v_t.item_name, v_t.qty,
          v_sign * COALESCE(p_cash_value, v_t.agreed_cash_value, 0), v_uid);
  RETURN jsonb_build_object('ok', true, 'status', 'handed_over');
END;
$function$;


-- ===== pharmacy_transfer_request =====
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_request(p_link_id uuid, p_item_name text, p_qty numeric, p_drug_catalog_id uuid DEFAULT NULL::uuid, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_link record;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_link FROM public.pharmacy_links WHERE id = p_link_id AND status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'LINK_NOT_FOUND'; END IF;
  IF NOT (public.is_merchant_owner(v_link.pharmacy_a) OR public.is_merchant_owner(v_link.pharmacy_b)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  INSERT INTO public.pharmacy_transfer_requests
    (link_id, requesting_merchant, lending_merchant, drug_catalog_id, item_name, qty, request_note)
  SELECT p_link_id, m.id,
         CASE WHEN m.id = v_link.pharmacy_a THEN v_link.pharmacy_b ELSE v_link.pharmacy_a END,
         p_drug_catalog_id, p_item_name, p_qty, p_note
    FROM public.merchants m
   WHERE (m.id = v_link.pharmacy_a OR m.id = v_link.pharmacy_b)
     AND public.is_merchant_owner(m.id)
   ORDER BY m.id LIMIT 1
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'transfer_id', v_id);
END;
$function$;


-- ===== pharmacy_transfer_respond =====
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_respond(p_transfer_id uuid, p_accept boolean, p_cash_value numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT public.is_merchant_owner(v_t.lending_merchant) THEN
    RAISE EXCEPTION 'Only the lending pharmacy responds';
  END IF;
  IF v_t.status <> 'requested' THEN RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_ANSWERED'); END IF;
  UPDATE public.pharmacy_transfer_requests
     SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
         agreed_cash_value = CASE WHEN p_accept THEN COALESCE(p_cash_value, agreed_cash_value) END,
         updated_at = now()
   WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END);
END;
$function$;


-- ===== pharmacy_transfer_settle =====
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_settle(p_transfer_id uuid, p_mode text, p_cash_amount numeric DEFAULT NULL::numeric, p_swap_desc text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_mode NOT IN ('swap','cash') THEN RAISE EXCEPTION 'mode must be swap or cash'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_merchant_owner(v_t.requesting_merchant) OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_t.status <> 'handed_over' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NOT_HANDED_OVER'); END IF;
  -- Review #29: settlement is proposed by one side and only lands in the
  -- ledger after the OTHER side confirms (pharmacy_transfer_settle_confirm).
  UPDATE public.pharmacy_transfer_requests
     SET status = 'settlement_pending',
         settle_mode = p_mode,
         settle_cash_amount = COALESCE(p_cash_amount, agreed_cash_value),
         settle_swap_desc = p_swap_desc,
         settle_proposed_by = v_uid,
         updated_at = now()
   WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', 'settlement_pending');
END;
$function$;


-- ===== pharmacy_transfer_settle_confirm =====
CREATE OR REPLACE FUNCTION public.pharmacy_transfer_settle_confirm(p_transfer_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_t record;
  v_sign integer;
  v_proposer_side uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_t FROM public.pharmacy_transfer_requests WHERE id = p_transfer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND'; END IF;
  IF NOT (public.is_merchant_owner(v_t.requesting_merchant) OR public.is_merchant_owner(v_t.lending_merchant)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_t.status <> 'settlement_pending' THEN RETURN jsonb_build_object('ok', false, 'reason', 'NO_PENDING_SETTLEMENT'); END IF;
  -- The OTHER side must confirm: proposer's merchant vs confirmer's.
  IF v_t.settle_proposed_by IS NOT NULL AND v_t.settle_proposed_by = v_uid AND NOT public._is_country_admin_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'OTHER_SIDE_MUST_CONFIRM');
  END IF;
  IF NOT p_accept THEN
    UPDATE public.pharmacy_transfer_requests
       SET status = 'handed_over', settle_mode = NULL, settle_cash_amount = NULL,
           settle_swap_desc = NULL, settle_proposed_by = NULL, updated_at = now()
     WHERE id = p_transfer_id;
    RETURN jsonb_build_object('ok', true, 'status', 'handed_over');
  END IF;
  SELECT CASE WHEN v_t.requesting_merchant = k.pharmacy_a THEN 1 ELSE -1 END
    INTO v_sign FROM public.pharmacy_links k WHERE k.id = v_t.link_id;
  INSERT INTO public.pharmacy_transfer_ledger
    (link_id, transfer_id, entry_type, item_desc, cash_amount, note, created_by)
  VALUES (v_t.link_id, p_transfer_id,
          CASE WHEN v_t.settle_mode = 'swap' THEN 'settle_swap' ELSE 'settle_cash' END,
          COALESCE(v_t.settle_swap_desc, v_t.item_name),
          -v_sign * COALESCE(v_t.settle_cash_amount, 0),
          CASE WHEN v_t.settle_mode = 'swap' THEN 'تسوية بدل' ELSE 'تسوية نقدية' END, v_uid);
  UPDATE public.pharmacy_transfer_requests SET status = 'settled', updated_at = now() WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'status', 'settled');
END;
$function$;


-- ===== pharmacy_message_send =====
CREATE OR REPLACE FUNCTION public.pharmacy_message_send(p_link_id uuid, p_body text, p_transfer_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sender uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF btrim(COALESCE(p_body,'')) = '' THEN RAISE EXCEPTION 'EMPTY_MESSAGE'; END IF;
  SELECT k.pharmacy_a INTO v_sender FROM public.pharmacy_links k
   WHERE k.id = p_link_id AND public.is_merchant_owner(k.pharmacy_a);
  IF v_sender IS NULL THEN
    SELECT k.pharmacy_b INTO v_sender FROM public.pharmacy_links k
     WHERE k.id = p_link_id AND public.is_merchant_owner(k.pharmacy_b);
  END IF;
  IF v_sender IS NULL AND NOT public._is_country_admin_uid(v_uid) THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.pharmacy_messages (link_id, transfer_id, sender_merchant, body)
  VALUES (p_link_id, p_transfer_id, v_sender, p_body);
  RETURN jsonb_build_object('ok', true);
END;
$function$;


-- ===== dispatch_delivery =====
CREATE OR REPLACE FUNCTION public.dispatch_delivery(p_ride_id uuid, p_radius_km numeric DEFAULT 10, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;
  IF NOT (COALESCE(v_ride.rider_id = auth.uid(),false)
      OR (v_ride.merchant_id IS NOT NULL AND public.is_merchant_owner(v_ride.merchant_id))
      OR (v_ride.merchant_id IS NULL AND public._is_country_admin_uid(auth.uid()))) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  RETURN public._dispatch_delivery_internal(p_ride_id, p_radius_km, p_limit);
END;
$function$;


-- ===== redispatch_delayed_order =====
CREATE OR REPLACE FUNCTION public.redispatch_delayed_order(p_ride_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_ride public.rides%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  select * into v_ride from public.rides where id = p_ride_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'RIDE_NOT_FOUND');
  end if;
  if not ((v_ride.merchant_id is not null and public.is_merchant_owner(v_ride.merchant_id))
          or (v_ride.merchant_id is null and public._is_country_admin_uid(auth.uid()))) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  return public._driver_delay_redispatch(p_ride_id, p_reason, 'merchant');
end;
$function$;


-- ===== pos_create_sale =====
CREATE OR REPLACE FUNCTION public.pos_create_sale(p_merchant_id uuid, p_items jsonb, p_discount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_customer_name text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_qty int;
  v_subtotal numeric := 0;
  v_total numeric;
  v_discount numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_sale_id uuid;
  v_existing uuid;
  v_rate numeric;
  v_commission numeric;
  v_touched int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_payment_method NOT IN ('cash', 'instapay', 'vodafone_cash') THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing FROM public.pos_sales
      WHERE idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN (
        SELECT jsonb_build_object(
          'ok', true, 'sale_id', s.id, 'idempotent', true,
          'subtotal', s.subtotal, 'discount', s.discount,
          'total', s.total_amount, 'items', s.items)
        FROM public.pos_sales s WHERE s.id = v_existing);
    END IF;
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'EMPTY_CART';
  END IF;

  -- Price every line from the live products table; stock-check and decrement
  -- atomically so two tills cannot sell the same last unit.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := COALESCE((v_item->>'qty')::int, 0);
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'INVALID_QTY';
    END IF;
    -- #21: same shared pricing as the order flow (modifiers priced and
    -- group-validated when the till sends modifier_option_ids).
    v_line := public._price_order_line(
      p_merchant_id,
      jsonb_build_object(
        'product_id', v_item->>'product_id',
        'quantity', v_qty,
        'modifier_option_ids', COALESCE(v_item->'modifier_option_ids', '[]'::jsonb)),
      true);
    v_subtotal := v_subtotal + (v_line->>'total_price')::numeric;
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_line->>'product_id',
      'name', v_line->>'name',
      'name_ar', v_line->>'name_ar',
      'qty', v_qty,
      'unit_price', (v_line->>'unit_price')::numeric,
      'line_total', (v_line->>'total_price')::numeric,
      'modifiers', v_line->'modifiers'
    );
  END LOOP;

  v_discount := LEAST(GREATEST(COALESCE(p_discount, 0), 0), v_subtotal);
  v_total := v_subtotal - v_discount;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, customer_name, notes, idempotency_key)
  VALUES
    (p_merchant_id, v_uid, v_lines, v_subtotal, v_discount, v_total,
     p_payment_method, NULLIF(btrim(COALESCE(p_customer_name, '')), ''),
     p_notes, p_idempotency_key)
  RETURNING id INTO v_sale_id;

  -- Same commission posting as orders/bookings: merchant owes the platform
  -- its rate on the walk-in gross, once.
  v_rate := COALESCE(
    public.get_commission_rate('merchant', v_merchant.type, v_merchant.owner_user_id), 0);
  IF v_rate > 0 THEN
    v_commission := public.calculate_commission(v_total, v_rate);
    INSERT INTO public.platform_commissions
      (member_id, reference_type, reference_id, gross_amount, commission_rate,
       commission_amount, net_amount, currency, status)
    VALUES (v_merchant.owner_user_id, 'pos_sale', v_sale_id, v_total, v_rate,
            v_commission, v_total - v_commission, 'EGP', 'computed')
    ON CONFLICT (reference_type, reference_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'sale_id', v_sale_id,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total', v_total,
    'items', v_lines
  );
END;
$function$;


-- ===== pharmacy_import_drug =====
CREATE OR REPLACE FUNCTION public.pharmacy_import_drug(p_drug_id uuid, p_merchant_id uuid, p_price numeric DEFAULT NULL::numeric, p_stock integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_drug public.drug_catalog%ROWTYPE;
  v_product_id uuid;
  v_price numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_stock IS NULL OR p_stock < 0 THEN
    RAISE EXCEPTION 'INVALID_STOCK';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  SELECT * INTO v_drug FROM public.drug_catalog
    WHERE id = p_drug_id AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRUG_NOT_FOUND';
  END IF;

  -- Default to the official retail price when the caller does not set one.
  v_price := COALESCE(p_price, v_drug.official_price_egp);
  IF v_price IS NULL OR v_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;

  -- Duplicate guard: re-importing the same drug returns the existing product.
  SELECT id INTO v_product_id FROM public.products
   WHERE merchant_id = p_merchant_id
     AND ((v_drug.barcode IS NOT NULL AND barcode = v_drug.barcode)
          OR (v_drug.barcode IS NULL
              AND name = v_drug.name_en || COALESCE(' ' || v_drug.strength, '')))
   ORDER BY created_at
   LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'product_id', v_product_id, 'duplicate', true);
  END IF;

  INSERT INTO public.products (
    merchant_id, name, name_ar, description, description_ar, price,
    category, stock_quantity, is_available, barcode
  ) VALUES (
    p_merchant_id,
    v_drug.name_en || COALESCE(' ' || v_drug.strength, ''),
    v_drug.name_ar,
    concat_ws(' · ', v_drug.active_ingredient, v_drug.strength,
              v_drug.dosage_form, v_drug.manufacturer),
    NULL,
    v_price,
    'pharmacy',
    p_stock,
    true,
    v_drug.barcode
  )
  RETURNING id INTO v_product_id;

  RETURN jsonb_build_object('ok', true, 'product_id', v_product_id);
END;
$function$;


-- ===== pos_void_sale =====
CREATE OR REPLACE FUNCTION public.pos_void_sale(p_sale_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sale public.pos_sales%ROWTYPE;
  v_merchant public.merchants%ROWTYPE;
  v_line jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  SELECT * INTO v_sale FROM public.pos_sales WHERE id = p_sale_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SALE_NOT_FOUND';
  END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_sale.merchant_id;
  IF v_sale.cashier_user_id <> v_uid
     AND v_merchant.owner_user_id <> v_uid
     AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_sale.merchant_id))) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;
  IF v_sale.status = 'voided' THEN
    RETURN jsonb_build_object('ok', true, 'sale_id', v_sale.id, 'already_voided', true);
  END IF;

  -- Restore stock for tracked items only (NULL stock = untracked).
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_sale.items) LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity + COALESCE((v_line->>'qty')::int, 0),
           updated_at = now()
     WHERE id = (v_line->>'product_id')::uuid
       AND stock_quantity IS NOT NULL;
  END LOOP;

  -- Reverse the still-open platform commission posting, if any.
  UPDATE public.platform_commissions
     SET status = 'reversed'
   WHERE reference_type = 'pos_sale'
     AND reference_id = v_sale.id
     AND status = 'computed';

  UPDATE public.pos_sales
     SET status = 'voided', voided_at = now(), voided_by = v_uid,
         void_reason = NULLIF(btrim(COALESCE(p_reason, '')), '')
   WHERE id = v_sale.id;

  RETURN jsonb_build_object('ok', true, 'sale_id', v_sale.id);
END;
$function$;


-- ===== update_order_status =====
CREATE OR REPLACE FUNCTION public.update_order_status(p_order_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid      uuid := auth.uid();
  v_order    public.orders;
  v_is_admin boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;

  -- Authorize: merchant owner of the order, OR admin
  IF NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.merchants m
       WHERE m.id = v_order.merchant_id AND m.owner_user_id = v_uid
    ) THEN
      RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
    END IF;
  END IF;

  IF p_status NOT IN ('confirmed','preparing','ready','delivering','delivered','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS');
  END IF;

  -- Merchants are limited to fulfillment statuses (delivering is admin-only)
  IF NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) AND p_status IN ('confirmed','delivering') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MERCHANT_STATUS_FORBIDDEN');
  END IF;

  -- Terminal states cannot be changed
  IF v_order.status IN ('delivered','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'TERMINAL_STATE', 'status', v_order.status);
  END IF;

  UPDATE public.orders
     SET status = p_status, updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', p_status);
END;
$function$;


-- ===== cancel_order =====
CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_suspend_after boolean := false;
  v_refunded boolean := false;
  v_actor uuid;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_short text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;

  if v_order.user_id is distinct from v_uid and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;

  if v_order.status in ('delivered', 'cancelled') then
    return jsonb_build_object('ok', false, 'code', 'NOT_CANCELLABLE', 'status', v_order.status);
  end if;

  -- Customer self-cancel policy (owner-confirmed 2026-11-21, mig 185):
  -- no solo-cancel once the order is out for delivery, and a MONTHLY
  -- allowance of 2 customer cancels (calendar month, UTC; further cancels
  -- go through merchant/support).
  if v_uid = v_order.user_id and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    if v_order.status = 'delivering' then
      return jsonb_build_object('ok', false, 'code', 'OUT_FOR_DELIVERY', 'status', v_order.status);
    end if;
    -- 188: the 3rd monthly cancel EXECUTES and triggers a 5-day suspension
    -- (appealable); it is no longer blocked.
    if (select count(*) from public.orders
         where user_id = v_uid and cancelled_by = 'customer'
           and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 2 then
      v_suspend_after := true;
    end if;
  end if;

  -- 194: shared finalizer owns stock/coupon/refund/order+ride cancellation.
  v_refunded := v_order.payment_status = 'paid';
  perform public._finalize_order_cancel(
    p_order_id,
    case when v_uid = v_order.user_id then 'customer' else 'admin' end,
    coalesce(p_reason, v_order.cancelled_reason, 'Order cancelled'),
    true, true, true,
    case when v_uid is distinct from v_order.user_id then 'system' else 'rider' end);

  -- Notify the assigned driver: stop heading to pickup.
  if v_order.driver_id is not null then
    select user_id into v_driver_uid from public.drivers where id = v_order.driver_id;
    if v_driver_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_driver_uid,
              'تم إلغاء الطلب',
              'ألغى العميل الطلب. لا تتوجه للاستلام.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- Notify the merchant owner.
  if v_order.merchant_id is not null then
    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      v_short := right(v_order.id::text, 6);
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'تم إلغاء طلب',
              'ألغى العميل الطلب رقم ' || v_short || '.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- 188: suspension after the 3rd monthly cancel (moderation engine owns
  -- account_status; appeal via submit_appeal routes to the region duty admin).
  if v_suspend_after then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'تجاوز سماحية الإلغاء الشهرية (إلغاء ثالث خلال شهر واحد)', 5);
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك 5 أيام',
            'تم تنفيذ إلغاء الطلب، لكن ده ثالث إلغاء ليك هذا الشهر (السماحية: 2). اتوقف حسابك 5 أيام. لو عندك ظرف، قدّم التماس من التطبيق والمسؤول عن منطقتك هيراجعه.',
            'account',
            jsonb_build_object('event', 'cancel_suspension', 'order_id', v_order.id,
                               'duration_days', 5),
            true);
    return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled',
                              'refunded', v_refunded, 'suspended', true,
                              'suspension_days', 5);
  end if;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;


$function$;


-- ===== add_order_items =====
CREATE OR REPLACE FUNCTION public.add_order_items(p_order_id uuid, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_added numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_stock_touched boolean := false;
  v_coupon public.coupons%rowtype;
  v_new_subtotal numeric;
  v_discount numeric := 0;
  v_total numeric;
  v_merchant_uid uuid;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.user_id is distinct from v_uid and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    raise exception 'FORBIDDEN';
  end if;
  if v_order.status not in ('pending','confirmed','preparing') then
    raise exception 'ORDER_NOT_EDITABLE %', v_order.status;
  end if;
  if v_order.payment_status = 'paid' then
    raise exception 'ORDER_ALREADY_PAID';
  end if;
  -- Monthly edit allowance (mig 185): 3 edits per calendar month (UTC).
  if v_uid = v_order.user_id and not public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_order.merchant_id))) then
    if (select count(*) from public.order_edit_events
         where user_id = v_uid
           and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 3 then
      raise exception 'EDIT_ALLOWANCE_EXHAUSTED';
    end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_ITEMS';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    -- #21: same shared pricing as create_order; modifier selections are
    -- now priced, validated against group rules and recorded on the item.
    v_line := public._price_order_line(v_order.merchant_id, v_item, true);
    v_stock_touched := v_stock_touched or (v_line->>'stock_decremented')::boolean;
    v_added := v_added + (v_line->>'total_price')::numeric;
    v_lines := v_lines || (v_line - 'stock_decremented' - 'name' - 'name_ar');
  end loop;

  v_new_subtotal := v_order.subtotal + v_added;

  if v_order.coupon_id is not null then
    select * into v_coupon from public.coupons where id = v_order.coupon_id;
    if found then
      if v_coupon.discount_type = 'percentage' then
        v_discount := round(v_new_subtotal * v_coupon.discount_value / 100.0, 2);
      else
        v_discount := v_coupon.discount_value;
      end if;
      if v_coupon.maximum_discount is not null then
        v_discount := least(v_discount, v_coupon.maximum_discount);
      end if;
      v_discount := least(v_discount, v_new_subtotal);
    else
      v_discount := v_order.discount;
    end if;
  else
    v_discount := coalesce(v_order.discount, 0);
  end if;

  v_total := greatest(v_new_subtotal + coalesce(v_order.delivery_fee,0) - v_discount, 0);

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, modifiers)
  select p_order_id, (l->>'product_id')::uuid, l->>'product_name',
         (l->>'quantity')::int, (l->>'unit_price')::numeric, (l->>'total_price')::numeric,
         coalesce(l->'modifiers', '[]'::jsonb)
    from jsonb_array_elements(v_lines) l;

  update public.orders
     set subtotal = v_new_subtotal,
         discount = v_discount,
         total_amount = v_total,
         items = coalesce(items, '[]'::jsonb) || v_lines,
         stock_decremented = stock_decremented or v_stock_touched,
         updated_at = now()
   where id = p_order_id;

  insert into public.order_edit_events (order_id, user_id, added_subtotal)
  values (p_order_id, v_order.user_id, v_added);

  select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
  if v_merchant_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_merchant_uid,
            'تعديل على طلب قيد التجهيز',
            'أضاف العميل منتجات إلى الطلب رقم ' || right(p_order_id::text, 6) ||
              '. الإجمالي الجديد: ' || v_total::text || ' جنيه.',
            'order',
            jsonb_build_object('order_id', p_order_id, 'event', 'items_added',
                               'added_subtotal', v_added, 'total_amount', v_total),
            true);
  end if;

  return jsonb_build_object(
    'ok', true, 'order_id', p_order_id,
    'added_subtotal', v_added,
    'subtotal', v_new_subtotal,
    'discount', v_discount,
    'total_amount', v_total);
end;
$function$;


-- ===== dispatch_order =====
CREATE OR REPLACE FUNCTION public.dispatch_order(p_order_id uuid, p_region_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order orders%ROWTYPE;
  v_best uuid;
  v_score numeric;
  v_cfg dispatch_config%ROWTYPE;
  v_cat text;
BEGIN
  -- Authorization FIRST: only owner or admin can manually trigger dispatch
  -- (service_role with NULL auth.uid() is allowed for cron jobs)
  IF auth.uid() IS NOT NULL
     AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id((SELECT o.merchant_id FROM public.orders o WHERE o.id = p_order_id)))) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO v_cfg FROM public.dispatch_config WHERE region_id IS NOT DISTINCT FROM p_region_id;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_PENDING', 'dispatch_status', v_order.dispatch_status);
  END IF;
   v_cat := 'food';

  SELECT driver_id, score INTO v_best, v_score
  FROM (
    SELECT d.id AS driver_id,
      (1.0 / (1.0 + public.driver_distance_km(
        v_order.delivery_latitude, v_order.delivery_longitude,
        dl.latitude, dl.longitude))) AS score
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.id
    WHERE d.is_online
      AND d.is_verified
      AND d.accepts_deliveries
      AND (d.max_delivery_distance_km IS NULL OR
           public.driver_distance_km(v_order.delivery_latitude, v_order.delivery_longitude, dl.latitude, dl.longitude)
            <= d.max_delivery_distance_km)
      AND (d.service_types IS NULL OR d.service_types && ARRAY[v_cat])
    ORDER BY score DESC
    LIMIT 1
  ) ranked;

  IF v_best IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NO_AVAILABLE_DRIVER');
  END IF;

  INSERT INTO public.order_dispatch (order_id, candidate_driver_id, score, status, region_id)
  VALUES (p_order_id, v_best, v_score, 'pending', p_region_id)
  ON CONFLICT (order_id) DO UPDATE
    SET candidate_driver_id = EXCLUDED.candidate_driver_id,
        score = EXCLUDED.score,
        status = 'pending',
        region_id = EXCLUDED.region_id,
        updated_at = now();

  PERFORM public.log_admin_action('DISPATCH_AUTO', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', v_best, 'score', v_score), NULL, 'GLOBAL');

  RETURN jsonb_build_object('ok', true, 'driver_id', v_best, 'score', v_score);
END;
$function$;


-- ===== driver_order_contacts =====
CREATE OR REPLACE FUNCTION public.driver_order_contacts()
 RETURNS TABLE(order_id uuid, full_name text, phone text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT d.id INTO v_driver
    FROM public.drivers d
   WHERE d.user_id = v_uid;

  IF v_driver IS NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT o.id, u.full_name, u.phone
  FROM public.orders o
  JOIN public.users u ON u.id = o.user_id
  WHERE o.driver_id = v_driver
     OR public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(o.merchant_id)));
END;
$function$;


-- ===== merchant_order_contacts =====
CREATE OR REPLACE FUNCTION public.merchant_order_contacts(p_merchant_id uuid)
 RETURNS TABLE(order_id uuid, full_name text, phone text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF NOT (
    public.is_merchant_owner(p_merchant_id)
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT o.id, u.full_name, u.phone
  FROM public.orders o
  JOIN public.users u ON u.id = o.user_id
  WHERE o.merchant_id = p_merchant_id;
END;
$function$;


-- ===== merchant_ready_for_dispatch =====
CREATE OR REPLACE FUNCTION public.merchant_ready_for_dispatch(p_ride_id uuid, p_merchant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.merchants m
         WHERE m.id = p_merchant_id AND m.owner_user_id = auth.uid()
      ) OR public.is_merchant_owner(p_merchant_id)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id AND merchant_id = p_merchant_id;
  IF v_ride IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'order_not_found');
  END IF;
  IF v_ride.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_dispatched');
  END IF;

  -- The merchant confirms the order is ready; dispatch engine takes over
  RETURN jsonb_build_object('success', true, 'ride_id', p_ride_id);
END;
$function$;


-- ===== get_merchant_deliveries =====
CREATE OR REPLACE FUNCTION public.get_merchant_deliveries(p_merchant_id uuid, p_status text DEFAULT NULL::text)
 RETURNS SETOF rides
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM rides
  WHERE merchant_id = p_merchant_id
    AND service_type != 'ride'
    AND (p_status IS NULL OR status = p_status)
    AND (EXISTS (
      SELECT 1 FROM public.merchants m
       WHERE m.id = p_merchant_id AND m.owner_user_id = auth.uid()
    ) OR public.is_merchant_owner(p_merchant_id))
  ORDER BY created_at DESC
  LIMIT 50;
$function$;


-- ===== modify_reservation =====
CREATE OR REPLACE FUNCTION public.modify_reservation(p_reservation_id uuid, p_party_size integer DEFAULT NULL::integer, p_reservation_time timestamp with time zone DEFAULT NULL::timestamp with time zone, p_special_requests text DEFAULT NULL::text, p_table_number text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_r public.reservations; v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  SELECT * INTO v_r FROM public.reservations WHERE id = p_reservation_id FOR UPDATE;
  IF v_r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF v_r.user_id IS DISTINCT FROM v_uid AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_r.merchant_id))) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  UPDATE public.reservations SET
     party_size       = COALESCE(p_party_size, v_r.party_size),
     reservation_time = COALESCE(p_reservation_time, v_r.reservation_time),
     special_requests = CASE WHEN p_special_requests IS NULL THEN v_r.special_requests ELSE p_special_requests END,
     table_number     = CASE WHEN p_table_number IS NULL THEN v_r.table_number ELSE p_table_number END
   WHERE id = v_r.id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK');
END;
$function$;


-- ===== update_reservation_status =====
CREATE OR REPLACE FUNCTION public.update_reservation_status(p_reservation_id uuid, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_r public.reservations;
  v_uid uuid := auth.uid();
  v_merchant_ok boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','confirmed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATUS');
  END IF;
  SELECT * INTO v_r FROM public.reservations WHERE id = p_reservation_id FOR UPDATE;
  IF v_r IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.merchants m
     WHERE m.id = v_r.merchant_id AND m.owner_user_id = v_uid
  ) INTO v_merchant_ok;
  IF v_r.user_id IS DISTINCT FROM v_uid AND NOT v_merchant_ok AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_r.merchant_id))) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  -- Customers may only cancel their own reservation; confirming is the
  -- merchant's (or platform's) call.
  IF NOT v_merchant_ok AND NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id(v_r.merchant_id))) AND p_status <> 'cancelled' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MERCHANT_ONLY_STATUS');
  END IF;
  IF p_status = 'cancelled' AND v_r.status = 'cancelled' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_CANCELLED');
  END IF;
  UPDATE public.reservations SET status = p_status WHERE id = v_r.id;
  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'status', p_status);
END;
$function$;


-- ===== report_delivery_refusal =====
CREATE OR REPLACE FUNCTION public.report_delivery_refusal(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_driver public.drivers%rowtype;
  v_count int;
  v_merchant_uid uuid;
  v_short text;
  v_actor uuid;
  v_ride_id uuid;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  select * into v_driver from public.drivers where id = v_order.driver_id;
  if v_driver.user_id is distinct from v_uid and not public._is_country_admin_uid(v_uid) then
    raise exception 'FORBIDDEN';
  end if;
  if v_order.status <> 'delivering' then
    raise exception 'NOT_OUT_FOR_DELIVERY %', v_order.status;
  end if;

  -- One refusal report per order. The 3rd-refusal branch below intentionally
  -- leaves the order in 'delivering'; without this guard every retried report
  -- stacked another refusal_event and re-executed the 5-day suspension.
  if exists (select 1 from public.refusal_events where order_id = p_order_id) then
    return jsonb_build_object('ok', true, 'action', 'already_reported',
                              'order_id', p_order_id);
  end if;

  -- Lifetime stat kept for records; the policy window is MONTHLY (mig 185),
  -- counted from refusal_events (188) so that refused-but-uncancelled orders
  -- on the 3rd-refusal path still count.
  update public.users set refusal_count = refusal_count + 1
   where id = v_order.user_id;
  insert into public.refusal_events (user_id, order_id)
  values (v_order.user_id, v_order.id);
  select count(*) into v_count
    from public.refusal_events
   where user_id = v_order.user_id
     and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';

  -- 188: the 3rd monthly refusal is NOT processed as a cancellation - the
  -- order must still be received. The 5-day suspension executes at the
  -- driver's report; ops resolves the in-flight order via the incident flow.
  if v_count >= 3 then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'رفض استلام الطلب للمرة الثالثة خلال شهر واحد', 5);

    select id into v_ride_id from public.rides
     where order_id = v_order.id and status not in ('completed', 'cancelled')
     order by created_at desc limit 1;
    if v_ride_id is not null then
      insert into public.delivery_incidents (ride_id, order_id, reporter_user_id, reporter_role, kind, note)
      values (v_ride_id, v_order.id, v_uid, 'driver', 'final_refusal_suspension',
              coalesce(p_reason, 'رفض الاستلام للمرة الثالثة - العميل موقوف 5 أيام والطلب يحتاج حسم'));
    end if;

    v_short := right(v_order.id::text, 6);
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك 5 أيام',
            'ده تالت رفض استلام منك هذا الشهر. اتوقف حسابك 5 أيام من لحظة بلاغ الكابتن. طلبك رقم ' || v_short || ' لازم يتسلم، والدعم هيحسم الموضوع معاك. تقدر تقدّم التماس من التطبيق والمسؤول عن منطقتك هيراجعه.',
            'account',
            jsonb_build_object('event', 'refusal_suspension', 'refusal_count', v_count,
                               'order_id', v_order.id, 'duration_days', 5),
            true);

    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'العميل رفض الاستلام للمرة الثالثة',
              'الطلب رقم ' || v_short || ': تم إيقاف العميل 5 أيام، والدعم هيحسم الطلب (استلام إجباري أو إرجاع للمطعم).',
              'order',
              jsonb_build_object('order_id', v_order.id, 'event', 'final_refusal'),
              true);
    end if;

    return jsonb_build_object('ok', true, 'action', 'account_suspended',
                              'refusal_count', v_count, 'suspension_days', 5,
                              'order_cancelled', false);
  end if;

  -- 194: shared finalizer (coupon release included since 193's policy).
  perform public._finalize_order_cancel(
    p_order_id, 'customer_refusal', coalesce(p_reason, 'رفض الاستلام'),
    true, true, true, 'system');

  v_short := right(v_order.id::text, 6);
  select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
  if v_merchant_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_merchant_uid,
            'العميل رفض استلام الطلب',
            'تم إلغاء الطلب رقم ' || v_short || ' بسبب رفض العميل الاستلام.',
            'order',
            jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                               'reason', 'customer_refusal'),
            true);
  end if;

  insert into public.notifications (user_id, title, body, type, data, send_push)
  values (v_order.user_id,
          'تحذير ' || v_count || ' من 2 هذا الشهر: رفض استلام الطلب',
          'تم تسجيل رفضك استلام الطلب رقم ' || v_short || '. رفض الاستلام مرة أخرى بعد تحذيرين يؤدي إلى إيقاف الحساب 5 أيام، وطلبك القادم لازم يتسلم.',
          'account',
          jsonb_build_object('event', 'refusal_warning', 'refusal_count', v_count),
          true);
  return jsonb_build_object('ok', true, 'action', 'warning', 'refusal_count', v_count);
end;
$function$;


-- ===== report_driver_delay =====
CREATE OR REPLACE FUNCTION public.report_driver_delay(p_ride_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_driver_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  select id into v_driver_id from public.drivers where user_id = v_uid;
  if v_driver_id is null then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  if not public._is_country_admin_uid(v_uid)
     and not exists (select 1 from public.rides
                      where id = p_ride_id and driver_id = v_driver_id) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  return public._driver_delay_redispatch(p_ride_id, p_reason, 'driver');
end;
$function$;


-- ===== get_or_create_grace =====
CREATE OR REPLACE FUNCTION public.get_or_create_grace(p_user_id uuid)
 RETURNS grace_accounts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.grace_accounts;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;
  IF auth.uid() <> p_user_id
     AND NOT public.has_permission('MEMBER_MODERATE', public._ops_scope_region(public._member_region_id(p_user_id))) THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_row FROM public.grace_accounts WHERE user_id = p_user_id;
  IF v_row IS NULL THEN
    INSERT INTO public.grace_accounts (user_id) VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    SELECT * INTO v_row FROM public.grace_accounts WHERE user_id = p_user_id;
  END IF;
  RETURN v_row;
END;
$function$;


-- ===== get_unread_notification_count =====
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cnt integer;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 0;
  END IF;
  -- SECURITY DEFINER: current_user is always postgres, so authz must key off
  -- auth.uid(): NULL (service_role / server-side) bypasses; otherwise enforce
  -- own-user-or-admin.
  IF auth.uid() IS NOT NULL
     AND p_user_id <> auth.uid()
     AND NOT public.has_permission('MEMBER_VIEW', public._ops_scope_region(public._member_region_id(p_user_id))) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_cnt
    FROM public.notifications
   WHERE user_id = p_user_id AND is_read = false;
  RETURN COALESCE(v_cnt, 0);
END;
$function$;


-- ===== request_member_deletion =====
CREATE OR REPLACE FUNCTION public.request_member_deletion(p_member_id uuid, p_confirmation_email text, p_reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_email text; v_token text; BEGIN IF auth.uid() IS NOT NULL AND p_member_id <> auth.uid() AND NOT public.has_permission('MEMBER_MODERATE', public._ops_scope_region(public._member_region_id(p_member_id))) THEN RAISE EXCEPTION 'Not authorized'; END IF; SELECT email INTO v_email FROM public.users WHERE id = p_member_id; IF NOT FOUND THEN RAISE EXCEPTION 'Member not found'; END IF; IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN IF lower(btrim(COALESCE(p_confirmation_email, ''))) <> lower(btrim(v_email)) THEN RAISE EXCEPTION 'Email does not match this member'; END IF; v_token := 'DELETE-' || encode(sha256(lower(btrim(v_email))::bytea), 'hex'); ELSE v_token := 'DELETE-' || encode(sha256(p_member_id::text::bytea), 'hex'); END IF; IF p_reason IS NULL OR btrim(p_reason) = '' THEN RAISE EXCEPTION 'Reason is required'; END IF; RETURN public.delete_member_account(p_member_id, v_token, p_reason); END; $function$;


-- ===== get_live_share_session =====
CREATE OR REPLACE FUNCTION public.get_live_share_session(p_ride_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_session RECORD;
  v_ride RECORD;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Authorization: rider, driver, or admin/owner
  IF NOT (
    v_ride.rider_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.drivers d WHERE d.id = v_ride.driver_id AND d.user_id = auth.uid())
    OR public._is_owner_uid(auth.uid())
    OR public.has_permission('MEMBER_VIEW_LOCATION', public._ops_scope_region(public._member_region_id(v_ride.rider_id)))
  ) THEN
    RETURN NULL;
  END IF;

  SELECT id, share_token, expires_at, is_active, created_at
  INTO v_session
  FROM live_share_sessions
  WHERE ride_id = p_ride_id AND is_active = true AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'session_id', v_session.id,
    'share_token', v_session.share_token,
    'expires_at', v_session.expires_at,
    'is_active', v_session.is_active
  );
END;
$function$;


-- ===== start_live_share =====
CREATE OR REPLACE FUNCTION public.start_live_share(p_ride_id uuid, p_duration_minutes integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
  v_token uuid;
  v_expires timestamptz;
BEGIN
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;

  IF NOT (
    v_ride.rider_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.drivers d WHERE d.id = v_ride.driver_id AND d.user_id = auth.uid())
    OR public._is_owner_uid(auth.uid())
    OR public.has_permission('MEMBER_VIEW_LOCATION', public._ops_scope_region(public._member_region_id(v_ride.rider_id)))
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;

  v_token := gen_random_uuid();
  v_expires := NOW() + (p_duration_minutes || ' minutes')::interval;

  INSERT INTO live_share_sessions (ride_id, user_id, share_token, expires_at, is_active)
  VALUES (p_ride_id, auth.uid(), v_token, v_expires, true);

  RETURN jsonb_build_object('success', true, 'share_token', v_token, 'expires_at', v_expires);
END;
$function$;


-- ===== stop_live_share =====
CREATE OR REPLACE FUNCTION public.stop_live_share(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_session RECORD;
BEGIN
  SELECT * INTO v_session FROM live_share_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'session_not_found');
  END IF;

  IF NOT (
    v_session.user_id = auth.uid()
    OR public._is_owner_uid(auth.uid())
    OR public.has_permission('MEMBER_VIEW_LOCATION', public._ops_scope_region(public._member_region_id(v_session.user_id)))
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;

  UPDATE live_share_sessions SET is_active = false WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true);
END;
$function$;


-- ===== review_driver_application =====
CREATE OR REPLACE FUNCTION public.review_driver_application(p_driver_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'reason','DRIVER_NOT_FOUND'); END IF;
 IF NOT public._admin_write_scope(public._ops_scope_region(public._member_region_id(d.user_id))) THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 IF p_approve IS NULL THEN RETURN jsonb_build_object('success',false,'reason','INVALID_DECISION'); END IF;
 IF p_approve THEN
  IF NOT public.driver_application_documents_ready(p_driver_id) THEN
   RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active) THEN
   RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
  END IF;
 ELSE
  IF btrim(COALESCE(p_reason,''))='' THEN RETURN jsonb_build_object('success',false,'reason','REASON_REQUIRED'); END IF;
 END IF;
 IF p_approve THEN
  UPDATE public.driver_documents SET status='verified',
    reviewed_at=now(), rejection_reason=NULL
    WHERE driver_id=p_driver_id AND status='pending';
 ELSE
  UPDATE public.driver_documents SET status='rejected',
    reviewed_at=now(), rejection_reason=p_reason
    WHERE driver_id=p_driver_id AND status='pending'
      AND doc_type IN ('driving_license','vehicle_registration');
 END IF;
 UPDATE public.drivers SET is_verified=p_approve,
   verification_status=CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,updated_at=now()
   WHERE id=p_driver_id;
 IF p_approve THEN UPDATE public.vehicles SET is_verified=true WHERE driver_id=p_driver_id AND is_active; END IF;
 INSERT INTO public.notifications(user_id,title,body,type,data,deep_link,send_push)
 VALUES(d.user_id,CASE WHEN p_approve THEN 'تمت مراجعة حساب السائق' ELSE 'مستندات السائق محتاجة مراجعة' END,
 CASE WHEN p_approve THEN 'تم قبول المستندات وتفعيل حساب السائق' ELSE p_reason END,
 'verification',jsonb_build_object('driver_id',p_driver_id,'approved',p_approve),'/driver/documents',true);
 RETURN jsonb_build_object('success',true);
END; $function$;


-- ===== add_admin_note =====
CREATE OR REPLACE FUNCTION public.add_admin_note(p_complaint_id uuid, p_note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_admin       uuid := auth.uid();
  v_complainant uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT complainant_id INTO v_complainant
    FROM public.complaints
   WHERE id = p_complaint_id;

  IF NOT public.has_permission('MEMBER_VIEW_COMPLAINTS', public._ops_scope_region(public._member_region_id(v_complainant))) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE complaints
  SET admin_notes = array_append(COALESCE(admin_notes, '{}'), p_note),
      updated_at = NOW()
  WHERE id = p_complaint_id;

  IF v_complainant IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES
      (v_complainant,
       'Admin Note Added',
       'An administrator has added a note to your complaint.',
       'complaint_note',
       jsonb_build_object('entity_type', 'complaint', 'entity_id', p_complaint_id::text, 'action', 'admin_note'),
       '/my-complaints',
       'complaint-note-' || p_complaint_id::text || '-' || now()::text,
       v_admin, 'normal', true)
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO public.member_events (user_id, event_type, payload)
    VALUES (v_complainant, 'complaint_created',
            jsonb_build_object('complaint_id', p_complaint_id::text, 'action', 'admin_note'))
    ON CONFLICT DO NOTHING;
  END IF;
END;
$function$;


-- ===== admin_delete_merchant_review =====
CREATE OR REPLACE FUNCTION public.admin_delete_merchant_review(p_review_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._admin_write_scope(public._ops_scope_region(public._merchant_region_id((
    SELECT r.merchant_id FROM public.reviews r WHERE r.id = p_review_id)))) THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.reviews WHERE id = p_review_id;
  RETURN FOUND;
END; $function$;


-- ===== admin_delete_service_review =====
CREATE OR REPLACE FUNCTION public.admin_delete_service_review(p_review_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._admin_write_scope(public._ops_scope_region(public._member_region_id((
    SELECT sp.user_id FROM public.service_reviews sr
    JOIN public.service_providers sp ON sp.id = sr.provider_id
    WHERE sr.id = p_review_id)))) THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;
  DELETE FROM public.service_reviews WHERE id = p_review_id;
  -- trg_service_reviews_sync_provider (AFTER DELETE) recomputes the provider rating.
  RETURN FOUND;
END; $function$;


-- ===== escalate_support_chat =====
CREATE OR REPLACE FUNCTION public.escalate_support_chat(p_room_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
  v_current uuid;
  v_next uuid;
  v_prev_scope text;
  v_new_scope text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Escalation requires a reason';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;
  IF NOT public._admin_write_scope(public._ops_scope_region(v_room.region_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_current := v_room.assigned_admin_id;
  v_prev_scope := CASE
    WHEN v_current IS NULL THEN 'unassigned'
    WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner') THEN 'owner'
    WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_current) THEN 'scoped'
    ELSE 'global'
  END;

  UPDATE public.chat_rooms
     SET escalated_at = now(),
         escalated_from_admin_id = auth.uid()
   WHERE id = p_room_id;

  -- Owner/escalator terminal -> owner queue.
  IF v_current IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.users WHERE id = v_current AND role = 'owner'
  ) THEN
    UPDATE public.chat_rooms
       SET status = 'escalated', assigned_admin_id = NULL
     WHERE id = p_room_id;
    INSERT INTO public.chat_escalations
      (room_id, previous_admin_id, new_admin_id, actor_id, reason,
       previous_scope, new_scope)
    VALUES (p_room_id, v_current, NULL, auth.uid(), p_reason,
            v_prev_scope, 'owner');
    PERFORM public.write_audit(
      'SUPPORT_ESCALATED', 'chat_rooms', p_room_id::text,
      jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                         'to_admin_id', NULL, 'terminal', true)
    );
    RETURN;
  END IF;

  v_next := public.resolve_support_admin(v_room.region_id, true, v_current);
  IF v_next IS NULL OR v_next = v_current THEN
    UPDATE public.chat_rooms
       SET status = 'escalated', assigned_admin_id = NULL
     WHERE id = p_room_id;
    v_new_scope := 'owner';
  ELSE
    PERFORM public._assign_chat_to_admin(p_room_id, v_next, 'assigned');
    v_new_scope := CASE
      WHEN EXISTS (SELECT 1 FROM public.users WHERE id = v_next AND role = 'owner') THEN 'owner'
      WHEN EXISTS (SELECT 1 FROM public.admin_region_assignments WHERE admin_id = v_next) THEN 'scoped'
      ELSE 'global'
    END;
  END IF;

  INSERT INTO public.chat_escalations
    (room_id, previous_admin_id, new_admin_id, actor_id, reason,
     previous_scope, new_scope)
  VALUES (p_room_id, v_current, v_next, auth.uid(), p_reason,
          v_prev_scope, v_new_scope);

  PERFORM public.write_audit(
    'SUPPORT_ESCALATED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('reason', p_reason, 'from_admin_id', auth.uid(),
                       'to_admin_id', v_next, 'previous_scope', v_prev_scope,
                       'new_scope', v_new_scope)
  );

  INSERT INTO public.notifications
    (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    (SELECT participant_ids[1] FROM public.chat_rooms WHERE id = p_room_id),
    'Support chat escalated',
    'Your chat has been escalated to the next support level.',
    'chat_escalated',
    jsonb_build_object('room_id', p_room_id::text),
    '/support/room/' || p_room_id::text,
    'chat-escalated-customer-' || p_room_id::text
  );
END;
$function$;


-- ===== route_support_chat =====
CREATE OR REPLACE FUNCTION public.route_support_chat(p_room_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
  v_admin_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;
  IF NOT public._admin_write_scope(public._ops_scope_region(v_room.region_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF v_room.assigned_admin_id IS NOT NULL THEN
    RETURN v_room.assigned_admin_id;
  END IF;

  v_admin_id := public.resolve_support_admin(v_room.region_id, true);
  IF v_admin_id IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM public._assign_chat_to_admin(p_room_id, v_admin_id, 'assigned');
  PERFORM public.write_audit(
    'SUPPORT_ASSIGNED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('admin_id', v_admin_id, 'priority', v_room.priority)
  );
  RETURN v_admin_id;
END;
$function$;


-- ===== assign_support_chat =====
CREATE OR REPLACE FUNCTION public.assign_support_chat(p_room_id uuid, p_admin_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_room public.chat_rooms%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;
  IF v_room.status = 'closed' THEN
    RAISE EXCEPTION 'Room is closed';
  END IF;
  IF NOT public._admin_write_scope(public._ops_scope_region(v_room.region_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_admin_id AND role IN ('admin','owner')
  ) THEN
    RAISE EXCEPTION 'Assignee must be an admin';
  END IF;

  PERFORM public._assign_chat_to_admin(p_room_id, p_admin_id, 'assigned');
  PERFORM public.write_audit(
    'SUPPORT_ASSIGNED', 'chat_rooms', p_room_id::text,
    jsonb_build_object(
      'admin_id', p_admin_id,
      'from_admin_id', auth.uid(),
      'manual', true,
      'priority', v_room.priority
    )
  );
END;
$function$;


-- ===== close_support_chat =====
CREATE OR REPLACE FUNCTION public.close_support_chat(p_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_admin    uuid := auth.uid();
  v_customer uuid;
  v_room     public.chat_rooms%ROWTYPE;
BEGIN
  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF NOT (public._admin_write_scope(public._ops_scope_region(v_room.region_id))
          OR v_admin = ANY (v_room.participant_ids)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT cp.user_id INTO v_customer
    FROM public.chat_participants cp
   WHERE cp.room_id = p_room_id
     AND cp.user_id != v_admin
     AND cp.role = 'customer'
   LIMIT 1;

  UPDATE public.chat_rooms
     SET status = 'closed', closed_at = now(), is_active = false
   WHERE id = p_room_id;

  PERFORM public.write_audit(
    'SUPPORT_CLOSED', 'chat_rooms', p_room_id::text,
    jsonb_build_object('priority', v_room.priority, 'assigned_admin_id', v_room.assigned_admin_id)
  );

  IF v_customer IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key,
       sender_id, priority, send_push)
    VALUES
      (v_customer,
       'Chat Closed',
       'Your support chat has been closed. If you need further help, open a new chat.',
       'chat_closed',
       jsonb_build_object('entity_type', 'chat_room', 'entity_id', p_room_id::text, 'action', 'closed'),
       '/support/room/' || p_room_id::text,
       'chat-closed-' || p_room_id::text || '-' || v_customer::text,
       v_admin, 'normal', true)
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;

    INSERT INTO public.member_events (user_id, event_type, payload)
    VALUES (v_customer, 'support_resolved',
            jsonb_build_object('room_id', p_room_id::text, 'closed_by', 'admin'))
    ON CONFLICT DO NOTHING;
  END IF;

  INSERT INTO public.member_events (user_id, event_type, payload)
  VALUES (v_admin, 'support_resolved',
          jsonb_build_object('room_id', p_room_id::text, 'customer_id', v_customer::text))
  ON CONFLICT DO NOTHING;
END;
$function$;


-- ===== get_support_room_contact =====
CREATE OR REPLACE FUNCTION public.get_support_room_contact(p_room_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_room public.chat_rooms%ROWTYPE;
  v_other_id uuid;
  v_user record;
  v_support_phone text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_room FROM public.chat_rooms WHERE id = p_room_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF NOT (v_uid = ANY(v_room.participant_ids)
      OR public._admin_write_scope(public._ops_scope_region(v_room.region_id))) THEN
    RETURN NULL;
  END IF;

  -- Pick counterparty (non-self participant, or assigned admin if user is caller)
  SELECT pid INTO v_other_id
    FROM unnest(v_room.participant_ids) AS pid
   WHERE pid <> v_uid
   LIMIT 1;

  IF v_other_id IS NULL AND v_room.assigned_admin_id IS NOT NULL AND v_room.assigned_admin_id <> v_uid THEN
    v_other_id := v_room.assigned_admin_id;
  END IF;

  IF v_other_id IS NOT NULL THEN
    SELECT id, full_name, phone, role INTO v_user
      FROM public.users
     WHERE id = v_other_id;
  END IF;

  SELECT support_phone INTO v_support_phone
    FROM public.platform_settings
   WHERE id = 'default';

  RETURN jsonb_build_object(
    'reference_number', v_room.reference_number,
    'other_user_id', v_other_id,
    'other_name', v_user.full_name,
    'other_phone', COALESCE(NULLIF(btrim(v_user.phone), ''), v_support_phone),
    'other_role', v_user.role,
    'support_phone', v_support_phone
  );
END;
$function$;


-- ===== admin_broadcast_notification =====
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(p_title text, p_body text, p_type text DEFAULT 'info'::text, p_deep_link text DEFAULT NULL::text, p_target_role text DEFAULT NULL::text, p_target_user_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  matched_ids uuid[];
  device_count INTEGER;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT array_agg(u.id) INTO matched_ids
  FROM public.users u
  WHERE (p_target_user_id IS NULL OR u.id = p_target_user_id)
    AND (p_target_role IS NULL OR u.role = p_target_role);

  IF matched_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, data, is_read)
    SELECT
      unnest(matched_ids),
      p_title,
      p_body,
      p_type,
      CASE
        WHEN p_deep_link IS NULL THEN NULL
        ELSE jsonb_build_object('deep_link', p_deep_link)
      END,
      false;
  END IF;

  SELECT COUNT(*) INTO device_count
  FROM public.notification_tokens t
  WHERE t.user_id = ANY(matched_ids);

  RETURN device_count;
END;
$function$;


-- ===== admin_purge_expired_chats =====
CREATE OR REPLACE FUNCTION public.admin_purge_expired_chats()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_expired integer;
DECLARE r RECORD;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Admins only';
  END IF;

  SELECT count(*) INTO v_expired
    FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now();

  FOR r IN
    SELECT id FROM public.chat_rooms
    WHERE auto_delete_at IS NOT NULL AND auto_delete_at <= now()
  LOOP
    DELETE FROM public.chat_messages WHERE room_id = r.id;
    DELETE FROM storage.objects
      WHERE bucket_id = 'chat_attachments'
        AND name LIKE r.id::text || '/%';
    DELETE FROM public.chat_rooms WHERE id = r.id;
  END LOOP;

  RETURN v_expired;
END;
$function$;


-- ===== admin_upsert_region =====
CREATE OR REPLACE FUNCTION public.admin_upsert_region(p_id uuid DEFAULT NULL::uuid, p_parent_region_id uuid DEFAULT NULL::uuid, p_type text DEFAULT 'village'::text, p_name_ar text DEFAULT ''::text, p_name_en text DEFAULT NULL::text, p_lat double precision DEFAULT NULL::double precision, p_lon double precision DEFAULT NULL::double precision, p_radius_km double precision DEFAULT 3.0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id uuid;
  v_code text;
  v_level integer;
  v_radius_m double precision;
  v_meta jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
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
$function$;


-- ===== get_admin_analytics =====
CREATE OR REPLACE FUNCTION public.get_admin_analytics(date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, date_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_from TIMESTAMPTZ := COALESCE(date_from, NOW() - INTERVAL '30 days');
  v_to   TIMESTAMPTZ := COALESCE(date_to, NOW());
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN jsonb_build_object(
    -- All-time true totals (key names preserved for existing callers)
    'total_orders',    (SELECT COUNT(*) FROM public.orders),
    'total_revenue',   (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered'),
    'total_users',     (SELECT COUNT(*) FROM public.users),
    'total_drivers',   (SELECT COUNT(*) FROM public.drivers),
    'total_merchants', (SELECT COUNT(*) FROM public.merchants),
    -- Windowed values, explicitly labeled
    'window_orders',        (SELECT COUNT(*) FROM public.orders WHERE created_at BETWEEN v_from AND v_to),
    'window_revenue',       (SELECT COALESCE(SUM(total_amount), 0) FROM public.orders WHERE status = 'delivered' AND created_at BETWEEN v_from AND v_to),
    'window_new_users',     (SELECT COUNT(*) FROM public.users WHERE created_at BETWEEN v_from AND v_to),
    'window_new_drivers',   (SELECT COUNT(*) FROM public.drivers WHERE created_at BETWEEN v_from AND v_to),
    'window_new_merchants', (SELECT COUNT(*) FROM public.merchants WHERE created_at BETWEEN v_from AND v_to),
    -- POS walk-in revenue (status 'completed' excludes voided sales)
    'pos_revenue_total',  (SELECT COALESCE(SUM(total_amount), 0) FROM public.pos_sales WHERE status = 'completed'),
    'pos_sales_count',    (SELECT COUNT(*) FROM public.pos_sales WHERE status = 'completed'),
    'pos_revenue_window', (SELECT COALESCE(SUM(total_amount), 0) FROM public.pos_sales WHERE status = 'completed' AND created_at BETWEEN v_from AND v_to),
    'window_from', v_from,
    'window_to',   v_to
  );
END;
$function$;


-- ===== get_all_admins =====
CREATE OR REPLACE FUNCTION public.get_all_admins()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'email', u.email,
           'role', u.role,
           'region_name', r.name_en,
           'is_active', COALESCE(m.is_active, true),
           'supervisor_email', su.email,
           'created_at', u.created_at)
         ORDER BY u.created_at), '[]'::jsonb)
    INTO v_rows
    FROM public.users u
    LEFT JOIN public.admin_management m ON m.admin_id = u.id
    LEFT JOIN public.users su ON su.id = m.supervisor_id
    LEFT JOIN LATERAL (
      SELECT rr.name_en
        FROM public.admin_region_assignments aa
        LEFT JOIN public.regions rr ON rr.id = aa.region_id
       WHERE aa.admin_id = u.id
       ORDER BY aa.created_at DESC
       LIMIT 1
    ) r ON true
   WHERE u.role IN ('owner','admin')
      OR m.admin_id IS NOT NULL;

  RETURN v_rows;
END;
$function$;


-- ===== get_pending_deletions =====
CREATE OR REPLACE FUNCTION public.get_pending_deletions()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', a.id::text,
           'member_email', COALESCE(u.email, ''),
           'member_name', COALESCE(u.full_name, ''),
           'requested_by', COALESCE(ru.email, ''),
           'reason', COALESCE(a.reason, ''),
           'created_at', a.created_at)
         ORDER BY a.created_at DESC), '[]'::jsonb)
    INTO v_rows
    FROM public.approval_requests a
    LEFT JOIN public.users u ON u.id = a.entity_id
    LEFT JOIN public.users ru ON ru.id = a.requested_by
   WHERE a.request_type = 'member_delete'
     AND a.state = 'pending';

  RETURN v_rows;
END;
$function$;


-- ===== list_approval_requests =====
CREATE OR REPLACE FUNCTION public.list_approval_requests(p_state text DEFAULT 'pending'::text, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;
  IF p_state NOT IN ('pending', 'approved', 'rejected', 'all') THEN
    RAISE EXCEPTION 'Invalid state';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', a.id::text,
           'request_type', a.request_type,
           'entity_type', a.entity_type,
           'entity_id', a.entity_id::text,
           'payload', a.payload,
           'requested_by', a.requested_by::text,
           'required_approver', a.required_approver::text,
           'state', a.state,
           'reason', a.reason,
           'decided_by', a.decided_by::text,
           'created_at', a.created_at)
         ), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT * FROM public.approval_requests a
       WHERE p_state = 'all' OR a.state = p_state
       ORDER BY a.created_at DESC
       LIMIT GREATEST(1, p_limit)
    ) a;

  RETURN jsonb_build_object('requests', v_rows);
END;
$function$;


-- ===== list_platform_receiving_accounts =====
CREATE OR REPLACE FUNCTION public.list_platform_receiving_accounts()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'accounts',
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'method_type', method_type,
          'display_name', display_name,
          'account_name', account_name,
          'account_number', account_number,
          'wallet_number', wallet_number,
          'instructions', instructions,
          'is_active', is_active
        )
        ORDER BY created_at
      )
      FROM public.platform_receiving_accounts
    ), '[]'::jsonb)
  );
END;
$function$;


-- ===== decide_provider_profile_request =====
CREATE OR REPLACE FUNCTION public.decide_provider_profile_request(p_profile_id uuid, p_decision text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_req public.provider_business_profiles%ROWTYPE;
  v_dec text := lower(btrim(COALESCE(p_decision, '')));
  v_target jsonb;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
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
$function$;


-- ===== list_provider_profile_requests =====
CREATE OR REPLACE FUNCTION public.list_provider_profile_requests(p_status text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
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
$function$;


-- ===== assign_admin_region =====
CREATE OR REPLACE FUNCTION public.assign_admin_region(p_email text, p_region text, p_scope text DEFAULT 'descendants'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_region_id uuid;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_region IS NULL OR btrim(p_region) = '' THEN
    RAISE EXCEPTION 'Region is required';
  END IF;
  SELECT id INTO v_uid FROM public.users WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  SELECT id INTO v_region_id
    FROM public.regions
   WHERE name_ar ILIKE btrim(p_region)
      OR name_en ILIKE btrim(p_region)
   ORDER BY is_active DESC, type = 'governorate' DESC
   LIMIT 1;
  IF v_region_id IS NULL THEN
    RAISE EXCEPTION 'Region not found';
  END IF;

  PERFORM public._admin_exec_region(auth.uid(), v_uid, v_region_id, p_scope);
END;
$function$;


-- ===== assign_admin_role =====
CREATE OR REPLACE FUNCTION public.assign_admin_role(p_email text, p_role text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_db_role text;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_role NOT IN ('admin','country_admin','governorate_admin','center_admin','village_admin') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  SELECT id INTO v_uid FROM public.users WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_db_role := CASE WHEN p_role IN ('country_admin','governorate_admin','center_admin','village_admin')
                    THEN 'admin' ELSE p_role END;

  IF EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = v_uid) THEN
    PERFORM public._admin_exec_role(auth.uid(), v_uid, v_db_role, COALESCE(p_reason, 'Role updated'));
  ELSE
    PERFORM public._admin_exec_create(auth.uid(), v_uid, NULL, NULL, 'descendants');
  END IF;
END;
$function$;


-- ===== campaign_archive =====
CREATE OR REPLACE FUNCTION public.campaign_archive(p_campaign_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status NOT IN ('published','paused','expired','cancelled','rejected') THEN
    RAISE EXCEPTION 'Campaign cannot be archived from current state';
  END IF;
  UPDATE public.campaigns SET status = 'archived', archived_at = now()
  WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'archive', v_campaign.status, 'archived', p_reason);
END;
$function$;


-- ===== campaign_cancel =====
CREATE OR REPLACE FUNCTION public.campaign_cancel(p_campaign_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
  v_is_creator boolean;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  SELECT (v_campaign.proposed_by = auth.uid()) INTO v_is_creator;
  IF NOT v_is_creator AND NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign';
  END IF;
  IF v_campaign.status NOT IN ('draft','pending_review','approved','scheduled') THEN
    RAISE EXCEPTION 'Campaign cannot be cancelled from current state';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Cancellation requires a reason';
  END IF;
  UPDATE public.campaigns SET status = 'cancelled' WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'cancel', v_campaign.status, 'cancelled', p_reason);
  UPDATE public.approval_requests
    SET state = 'cancelled', reason = COALESCE(reason, p_reason), decided_at = now()
  WHERE request_type = 'campaign_approve' AND entity_id = p_campaign_id AND state = 'pending';
END;
$function$;


-- ===== campaign_pause =====
CREATE OR REPLACE FUNCTION public.campaign_pause(p_campaign_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status <> 'published' THEN
    RAISE EXCEPTION 'Only published campaigns can be paused';
  END IF;
  UPDATE public.campaigns SET status = 'paused' WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'pause', 'published', 'paused', p_reason);
END;
$function$;


-- ===== campaign_resume =====
CREATE OR REPLACE FUNCTION public.campaign_resume(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_campaign_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF NOT public.campaign_targets_authorized(p_campaign_id) THEN
    RAISE EXCEPTION 'Not authorized for this campaign region scope';
  END IF;
  IF v_campaign.status <> 'paused' THEN
    RAISE EXCEPTION 'Only paused campaigns can be resumed';
  END IF;
  IF v_campaign.ends_at IS NOT NULL AND v_campaign.ends_at <= now() THEN
    RAISE EXCEPTION 'Campaign window has expired';
  END IF;
  UPDATE public.campaigns SET status = 'published', published_at = now()
  WHERE id = p_campaign_id;
  INSERT INTO public.campaign_reviews
    (campaign_id, reviewer_id, action, previous_state, new_state, reason)
  VALUES (p_campaign_id, auth.uid(), 'resume', 'paused', 'published', NULL);
END;
$function$;


-- ===== campaign_purge_media =====
CREATE OR REPLACE FUNCTION public.campaign_purge_media(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.campaigns c
    WHERE c.id = p_campaign_id
      AND c.status IN ('archived','cancelled','rejected')
  ) THEN
    RAISE EXCEPTION 'Campaign must be in a terminal state to purge media';
  END IF;
  -- storage.protect_delete() blocks direct SQL DELETE unless the GUC is set.
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  DELETE FROM storage.objects
  WHERE bucket_id = 'campaign-media'
    AND public.campaign_id_from_storage_path(name) = p_campaign_id;
  PERFORM set_config('storage.allow_delete_query', 'false', true);
  UPDATE public.campaign_media SET is_active = false WHERE campaign_id = p_campaign_id;
  UPDATE public.campaign_banners SET is_active = false WHERE campaign_id = p_campaign_id;
END;
$function$;


-- ===== admin_client_priced_ratio =====
CREATE OR REPLACE FUNCTION public.admin_client_priced_ratio(p_since timestamp with time zone DEFAULT (now() - '30 days'::interval))
 RETURNS TABLE(merchant_id uuid, merchant_name text, sales integer, total_lines integer, client_priced_lines integer, client_priced_ratio numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'ADMIN_ONLY';
  END IF;
  RETURN QUERY
  SELECT s.merchant_id,
         m.name,
         COUNT(*)::integer,
         COALESCE(SUM(jsonb_array_length(s.items)), 0)::integer,
         COALESCE(SUM(s.client_priced_lines), 0)::integer,
         ROUND(COALESCE(SUM(s.client_priced_lines), 0)::numeric
               / NULLIF(COALESCE(SUM(jsonb_array_length(s.items)), 0), 0), 3)
    FROM public.pos_sales s
    JOIN public.merchants m ON m.id = s.merchant_id
   WHERE s.created_at >= p_since
     AND s.status = 'completed'
   GROUP BY s.merchant_id, m.name
  HAVING COALESCE(SUM(s.client_priced_lines), 0) > 0
   ORDER BY 6 DESC, 5 DESC;
END;
$function$;


-- ===== admin_insurance_mismatches =====
CREATE OR REPLACE FUNCTION public.admin_insurance_mismatches(p_since timestamp with time zone DEFAULT (now() - '30 days'::interval))
 RETURNS TABLE(merchant_id uuid, merchant_name text, insurance_sale_id bigint, company_id uuid, claimed_total numeric, server_total numeric, company_share numeric, patient_share numeric, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'ADMIN_ONLY';
  END IF;
  RETURN QUERY
  SELECT s.merchant_id, m.name, s.id, s.company_id, s.total, s.server_total,
         s.company_share, s.patient_share, s.created_at
    FROM public.pos_insurance_sales s
    JOIN public.merchants m ON m.id = s.merchant_id
   WHERE s.total_mismatch
     AND s.created_at >= p_since
   ORDER BY s.created_at DESC;
END;
$function$;


-- ===== admin_review_payout =====
CREATE OR REPLACE FUNCTION public.admin_review_payout(p_request_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_req public.merchant_payout_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_req FROM public.merchant_payout_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  UPDATE public.merchant_payout_requests
     SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         reviewed_by = auth.uid(), reviewed_at = now(), rejection_reason = p_reason
   WHERE id = p_request_id;
  IF p_approve THEN
    INSERT INTO public.merchant_ledger
      (merchant_id, entry_type, amount, currency, description, created_by)
    VALUES
      (v_req.merchant_id, 'debit', v_req.amount, v_req.currency,
       'Payout request ' || p_request_id::text, auth.uid());
  END IF;
  PERFORM public.log_admin_action(
    CASE WHEN p_approve THEN 'PAYOUT_APPROVED' ELSE 'PAYOUT_REJECTED' END,
    'merchant_payout_request', p_request_id::text, NULL,
    jsonb_build_object('amount', v_req.amount, 'reason', p_reason), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;


-- ===== admin_waive_obligation =====
CREATE OR REPLACE FUNCTION public.admin_waive_obligation(p_obligation_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  UPDATE public.driver_obligations
     SET status = 'waived', updated_at = now()
   WHERE id = p_obligation_id AND status IN ('open','disputed');
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  PERFORM public.log_admin_action('OBLIGATION_WAIVED', 'driver_obligation',
    p_obligation_id::text, NULL, jsonb_build_object('reason', p_reason), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;


-- ===== admin_create_and_publish_banner =====
CREATE OR REPLACE FUNCTION public.admin_create_and_publish_banner(p_name_ar text, p_name_en text DEFAULT NULL::text, p_subtitle_ar text DEFAULT NULL::text, p_subtitle_en text DEFAULT NULL::text, p_region_id uuid DEFAULT NULL::uuid, p_image_path text DEFAULT NULL::text, p_starts_at timestamp with time zone DEFAULT now(), p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_campaign_id uuid;
  v_request_id uuid;
  v_code text;
  v_publish_status text;
  v_clean_image text := NULLIF(btrim(p_image_path), '');
BEGIN
  IF v_uid IS NULL OR NOT public._is_country_admin_uid(v_uid) THEN
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
$function$;


-- ===== admin_update_banner =====
CREATE OR REPLACE FUNCTION public.admin_update_banner(p_campaign_id uuid, p_name_ar text, p_name_en text DEFAULT NULL::text, p_subtitle_ar text DEFAULT NULL::text, p_subtitle_en text DEFAULT NULL::text, p_region_id uuid DEFAULT NULL::uuid, p_image_path text DEFAULT NULL::text, p_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_current_status text;
  v_existing_starts_at timestamptz;
  v_effective_starts_at timestamptz;
  v_new_status text;
  v_clean_image text := NULLIF(btrim(p_image_path), '');
BEGIN
  IF v_uid IS NULL OR NOT public._is_country_admin_uid(v_uid) THEN
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
$function$;


-- ===== admin_delete_banner =====
CREATE OR REPLACE FUNCTION public.admin_delete_banner(p_campaign_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public._is_country_admin_uid(v_uid) THEN
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
$function$;


-- ===== moh_price_import =====
CREATE OR REPLACE FUNCTION public.moh_price_import(p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_row jsonb;
  v_updated integer := 0;
  v_unmatched integer := 0;
  v_id uuid;
BEGIN
  -- The MoH list is platform-wide reference data; only admins import it.
  IF v_uid IS NULL OR NOT public._is_country_admin_uid(v_uid) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF jsonb_typeof(p_rows) <> 'array' THEN RAISE EXCEPTION 'rows must be an array'; END IF;
  FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_id := NULL;
    UPDATE public.drug_catalog
       SET official_price_egp = (v_row->>'official_price')::numeric
     WHERE barcode IS NOT NULL AND barcode = v_row->>'barcode'
       AND official_price_egp IS DISTINCT FROM (v_row->>'official_price')::numeric
    RETURNING id INTO v_id;
    IF v_id IS NULL AND NULLIF(v_row->>'barcode','') IS NULL THEN
      -- No barcode on the row: fall back to exact English name match.
      UPDATE public.drug_catalog
         SET official_price_egp = (v_row->>'official_price')::numeric
       WHERE lower(name_en) = lower(v_row->>'name_en')
         AND official_price_egp IS DISTINCT FROM (v_row->>'official_price')::numeric
      RETURNING id INTO v_id;
    END IF;
    IF v_id IS NULL THEN
      -- Row already at this price, or no catalog entry: check which.
      PERFORM 1 FROM public.drug_catalog
       WHERE (barcode IS NOT NULL AND barcode = v_row->>'barcode')
          OR (NULLIF(v_row->>'barcode','') IS NULL AND lower(name_en) = lower(v_row->>'name_en'));
      IF NOT FOUND THEN v_unmatched := v_unmatched + 1; END IF;
    ELSE
      v_updated := v_updated + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'updated', v_updated, 'unmatched', v_unmatched);
END;
$function$;


-- ===== list_driver_settlements =====
CREATE OR REPLACE FUNCTION public.list_driver_settlements()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT jsonb_agg(to_jsonb(t)) INTO v_result FROM (
    SELECT ps.id, ps.admin_id, ps.member_id, ps.region_id, ps.payout_type,
           ps.amount, ps.currency, ps.payment_method, ps.reference,
           ps.proof_path, ps.message, ps.status, ps.created_at,
           ps.reviewed_at, ps.reviewed_by, ps.rejection_reason,
           u.full_name AS driver_name, u.email AS driver_email,
           d.id AS driver_surrogate_id
      FROM public.platform_settlements ps
      JOIN public.drivers d  ON d.user_id = ps.member_id
      JOIN public.users    u ON u.id = ps.member_id
     WHERE ps.member_id IS NOT NULL
       AND ps.status IN ('pending', 'approved', 'rejected', 'paid')
     ORDER BY ps.created_at DESC
     LIMIT 200
  ) t;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;


-- ===== dispatch_push =====
CREATE OR REPLACE FUNCTION public.dispatch_push(p_notification_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row public.notifications%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  PERFORM set_config('app.notify_dispatch', 'true', true);

  SELECT * INTO v_row FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;
  -- Idempotent: never re-send an already-sent notification.
  IF v_row.push_status = 'sent' THEN
    RETURN;
  END IF;

  UPDATE public.notifications
     SET push_status = 'pending', push_error = NULL
   WHERE id = p_notification_id;
  PERFORM public._enqueue_push(p_notification_id);
END;
$function$;


-- ===== admin_set_user_role =====
CREATE OR REPLACE FUNCTION public.admin_set_user_role(p_user_id uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;
  IF p_role NOT IN ('customer','merchant','driver','admin','owner','provider','delivery') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  IF p_role = 'owner' AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Only the owner can grant the owner role';
  END IF;
  IF p_role = 'admin'
     AND NOT EXISTS (
       SELECT 1 FROM public.admin_management
       WHERE admin_id = p_user_id AND is_active
     ) THEN
    RAISE EXCEPTION 'Use create_admin_account to create admins';
  END IF;
  -- managing an admin (or demoting one) requires supervision unless owner
  IF NOT public._is_owner_uid(auth.uid())
     AND (EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_user_id)
          OR p_role IN ('admin','owner'))
     AND NOT public.is_supervisor_of(auth.uid(), p_user_id) THEN
    RAISE EXCEPTION 'Not authorized for this user';
  END IF;

  PERFORM public._admin_exec_role(auth.uid(), p_user_id, p_role, NULL);
END;
$function$;


-- ===== admin_promote_and_configure_member =====
CREATE OR REPLACE FUNCTION public.admin_promote_and_configure_member(p_member_id uuid, p_role text, p_region_id uuid DEFAULT NULL::uuid, p_permissions text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_perm text;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
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
$function$;


-- ===== admin_assign_region_by_id =====
CREATE OR REPLACE FUNCTION public.admin_assign_region_by_id(p_email text, p_region_id uuid, p_scope text DEFAULT 'descendants'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_admin_id uuid;
  v_region_name text;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
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
$function$;


-- ===== apply_retention_policies (first is_admin occurrence only; policy body untouched) =====
CREATE OR REPLACE FUNCTION public.apply_retention_policies()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_policy record;
  v_cutoff timestamptz;
  v_count int;
  v_archived int;
  v_result jsonb := '{}'::jsonb;
  v_entry jsonb;
BEGIN
  FOR v_policy IN
    SELECT domain, retention_days FROM public.retention_policies
    WHERE enabled AND retention_days > 0
    ORDER BY domain
  LOOP
    v_cutoff := now() - make_interval(days => v_policy.retention_days);
    v_count := 0;
    v_archived := 0;

    CASE v_policy.domain
      WHEN 'location_updates' THEN
        IF to_regclass('public.location_updates') IS NOT NULL THEN
          DELETE FROM public.location_updates WHERE recorded_at < v_cutoff;
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'driver_locations' THEN
        IF to_regclass('public.driver_locations') IS NOT NULL THEN
          DELETE FROM public.driver_locations WHERE updated_at < v_cutoff;
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'member_events' THEN
        DELETE FROM public.member_events WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'chat_messages' THEN
        DELETE FROM public.chat_messages WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'notifications' THEN
        DELETE FROM public.notifications WHERE created_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'sanctions' THEN
        -- legal/evidence ledger: never purge ACTIVE rows, only closed ones.
        DELETE FROM public.sanctions
        WHERE created_at < v_cutoff AND action_status <> 'active';
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'emergency_audio_sessions' THEN
        -- metadata only; table optional (not live — 036 absorbed).
        IF to_regclass('public.emergency_audio_sessions') IS NOT NULL THEN
          DELETE FROM public.emergency_audio_sessions
          WHERE created_at < v_cutoff AND status IN ('ended','cancelled');
          GET DIAGNOSTICS v_count = ROW_COUNT;
        END IF;
      WHEN 'campaigns' THEN
        -- archived rows only; live campaigns are never purged.
        DELETE FROM public.campaigns
        WHERE archived_at IS NOT NULL AND archived_at < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      WHEN 'activity_logs' THEN
        -- archive-then-purge (audit rows survive, never silently destroyed).
        IF to_regclass('public.activity_logs_archive') IS NULL THEN
          CREATE TABLE public.activity_logs_archive (LIKE public.activity_logs);
          ALTER TABLE public.activity_logs_archive
            ADD COLUMN IF NOT EXISTS archived_at timestamptz DEFAULT now();
          ALTER TABLE public.activity_logs_archive ENABLE ROW LEVEL SECURITY;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM PUBLIC;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM anon;
          REVOKE ALL ON TABLE public.activity_logs_archive FROM authenticated;
          GRANT ALL ON TABLE public.activity_logs_archive TO service_role;
          DROP POLICY IF EXISTS activity_logs_archive_admin_select
            ON public.activity_logs_archive;
          CREATE POLICY activity_logs_archive_admin_select
            ON public.activity_logs_archive
            FOR SELECT TO authenticated
            USING (public._is_country_admin_uid(auth.uid()));
        END IF;
        INSERT INTO public.activity_logs_archive
          (id, user_id, action, resource, resource_id, details, ip_address,
           user_agent, timestamp, archived_at)
        SELECT id, user_id, action, resource, resource_id, details, ip_address,
               user_agent, timestamp, now()
        FROM public.activity_logs
        WHERE timestamp < v_cutoff;
        GET DIAGNOSTICS v_archived = ROW_COUNT;
        DELETE FROM public.activity_logs WHERE timestamp < v_cutoff;
        GET DIAGNOSTICS v_count = ROW_COUNT;
      ELSE
        CONTINUE;
    END CASE;

    IF v_count > 0 OR v_archived > 0 THEN
      PERFORM public.write_audit(
        'RETENTION_PURGED', v_policy.domain, NULL,
        jsonb_build_object('domain', v_policy.domain, 'purged', v_count,
                           'archived', v_archived));
      v_entry := jsonb_build_object('purged', v_count, 'archived', v_archived);
      v_result := v_result || jsonb_build_object(v_policy.domain, v_entry);
    END IF;
  END LOOP;
  RETURN v_result;
END;
$function$;


-- ===== submit_settlement_request =====
CREATE OR REPLACE FUNCTION public.submit_settlement_request(p_amount numeric, p_payment_method text DEFAULT 'bank_transfer'::text, p_reference text DEFAULT NULL::text, p_proof_path text DEFAULT NULL::text, p_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_region uuid;
  v_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  END IF;
  SELECT region_id INTO v_region FROM public.admin_region_assignments
   WHERE admin_id = v_uid LIMIT 1;
  IF v_region IS NULL AND NOT public._is_country_admin_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;

  INSERT INTO public.platform_settlements
    (admin_id, region_id, amount, currency, payment_method, reference, proof_path, message)
  VALUES
    (v_uid, v_region, p_amount, 'SAR', p_payment_method, p_reference, p_proof_path, p_message)
  RETURNING id INTO v_id;
  -- (reference column uses p_reference; fix below)
  UPDATE public.platform_settlements
     SET reference = p_reference, message = p_message
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'code', 'OK', 'id', v_id, 'status', 'pending');
END;
$function$;


-- ===== admin_create_settlement_code =====
CREATE OR REPLACE FUNCTION public.admin_create_settlement_code(p_obligation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ob public.driver_obligations%ROWTYPE;
  v_code text;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.is_admin() OR EXISTS (
      SELECT 1 FROM public.admin_region_assignments WHERE admin_id = auth.uid())
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_ob FROM public.driver_obligations WHERE id = p_obligation_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  END IF;
  IF v_ob.status <> 'open' OR v_ob.owed_to <> 'platform' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_STATE');
  END IF;
  IF NOT public._admin_write_scope(public._ops_scope_region((
    SELECT public._member_region_id(d.user_id)
      FROM public.drivers d WHERE d.id = v_ob.driver_id))) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  v_code := lpad(floor(random() * 10000)::int::text, 4, '0');
  UPDATE public.driver_obligations
     SET settlement_code = v_code, updated_at = now()
   WHERE id = p_obligation_id;
  RETURN jsonb_build_object('ok', true, 'code', v_code);
END;
$function$;


-- ===== F-08 policies =====
DROP POLICY IF EXISTS orders_update_merchant_owner ON public.orders;
CREATE POLICY orders_update_merchant_owner ON public.orders
  FOR UPDATE TO authenticated
  USING (public._is_merchant_owner_only(merchant_id) OR user_id = auth.uid())
  WITH CHECK (public._is_merchant_owner_only(merchant_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS orders_select_merchant_owner ON public.orders;
CREATE POLICY orders_select_merchant_owner ON public.orders
  FOR SELECT TO authenticated
  USING (public._is_merchant_owner_only(merchant_id) OR user_id = auth.uid());

ALTER POLICY "Admins can view all orders" ON public.orders
  USING (admin_has_permission('ORDER_VIEW'::text)
         AND _admin_write_scope(_merchant_region_id(merchant_id)));

ALTER POLICY pharmacy_links_read ON public.pharmacy_links
  USING (is_merchant_owner(pharmacy_a) OR is_merchant_owner(pharmacy_b));

ALTER POLICY pharmacy_transfer_read ON public.pharmacy_transfer_requests
  USING (is_merchant_owner(requesting_merchant) OR is_merchant_owner(lending_merchant));

ALTER POLICY cashier_licenses_owner_read ON public.cashier_licenses
  USING (is_merchant_owner(merchant_id));
