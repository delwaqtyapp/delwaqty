-- 374: make the Command Center RPCs scope-correct.
-- platform_kpi_summary, platform_operational_alerts and
-- platform_revenue_breakdown previously ignored p_region_id and returned
-- platform-wide numbers to every admin with MEMBER_VIEW, leaking global
-- counters to region-scoped admins. Each now computes the caller's effective
-- region filter: owner/country unrestricted (optional p_region_id subtree),
-- region-scoped admins limited to their 373 footprint (optionally narrowed
-- by an in-scope p_region_id; out-of-scope picks return zeros, never an
-- error). Region attribution follows 372: users/drivers via
-- user_region_preferences, merchants/orders via _merchant_region_id, rides
-- via merchant else pickup geocode, bookings via address geocode.

-- Effective region filter for the calling admin.
-- Returns NULL for unrestricted (owner/country with no p_region_id), an
-- array of covered region ids otherwise ('{}' = nothing visible).
CREATE OR REPLACE FUNCTION public._kpi_effective_regions(p_region_id uuid DEFAULT NULL)
RETURNS uuid[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_ids uuid[];
  v_sub uuid[];
BEGIN
  IF v_uid IS NULL THEN
    RETURN '{}';
  END IF;

  IF public._is_owner_uid(v_uid) OR public._is_country_admin_uid(v_uid) THEN
    IF p_region_id IS NULL THEN
      RETURN NULL;
    END IF;
    WITH RECURSIVE t AS (
      SELECT r.id FROM public.regions r WHERE r.id = p_region_id
      UNION ALL
      SELECT r.id FROM public.regions r JOIN t ON r.parent_region_id = t.id
    )
    SELECT coalesce(array_agg(id), '{}') INTO v_sub FROM t;
    RETURN v_sub;
  END IF;

  -- Region-scoped admin: own footprint from assignments.
  WITH RECURSIVE covered AS (
    SELECT r.id, a.scope
      FROM public.regions r
      JOIN public.admin_region_assignments a
        ON a.admin_id = v_uid AND a.region_id = r.id
    UNION ALL
    SELECT r.id, c.scope
      FROM public.regions r
      JOIN covered c
        ON r.parent_region_id = c.id AND c.scope = 'descendants'
  )
  SELECT coalesce(array_agg(DISTINCT id), '{}') INTO v_ids FROM covered;

  IF p_region_id IS NULL THEN
    RETURN v_ids;
  END IF;
  IF NOT (p_region_id = ANY(v_ids)) THEN
    RETURN '{}';
  END IF;
  WITH RECURSIVE t AS (
    SELECT r.id FROM public.regions r WHERE r.id = p_region_id
    UNION ALL
    SELECT r.id FROM public.regions r JOIN t ON r.parent_region_id = t.id
  )
  SELECT coalesce(array_agg(id), '{}') INTO v_sub FROM t;
  SELECT coalesce(array_agg(u), '{}') INTO v_ids
    FROM (SELECT unnest(v_sub) INTERSECT SELECT unnest(v_ids)) AS i(u);
  RETURN v_ids;
END;
$function$;

-- User belongs to one of the filter regions via user_region_preferences.
-- NULL filter = always true.
CREATE OR REPLACE FUNCTION public._user_in_regions(p_user_id uuid, p_regions uuid[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_regions IS NULL OR EXISTS (
    SELECT 1 FROM public.user_region_preferences urp
    WHERE urp.user_id = p_user_id AND urp.region_id = ANY(p_regions)
  );
$function$;

-- Region of an order via its merchant's geocode.
CREATE OR REPLACE FUNCTION public._order_region(p_order_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public._merchant_region_id(o.merchant_id)
    FROM public.orders o WHERE o.id = p_order_id;
$function$;

-- Region of a ride via its merchant, else pickup geocode.
CREATE OR REPLACE FUNCTION public._ride_region(p_ride_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT COALESCE(
    public._merchant_region_id(r.merchant_id),
    public._point_region_id(r.pickup_latitude, r.pickup_longitude)
  ) FROM public.rides r WHERE r.id = p_ride_id;
$function$;

CREATE OR REPLACE FUNCTION public.platform_kpi_summary(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_region_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
  v_result jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;

  v_has_revenue := has_permission('PLATFORM_REVENUE');
  v_regions := public._kpi_effective_regions(p_region_id);

  SELECT jsonb_build_object(
    -- Members
    'total_users',         (SELECT count(*) FROM users u WHERE v_regions IS NULL OR public._user_in_regions(u.id, v_regions)),
    'customers',           (SELECT count(*) FROM users u WHERE u.user_type = 'customer' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'providers',           (SELECT count(*) FROM users u WHERE u.user_type = 'provider' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'delivery_users',      (SELECT count(*) FROM users u WHERE u.user_type = 'delivery' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'merchant_users',      (SELECT count(*) FROM users u WHERE u.user_type = 'merchant' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'driver_users',        (SELECT count(*) FROM users u WHERE u.user_type = 'driver' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_users_period',    (SELECT count(*) FROM users u WHERE u.created_at >= v_from AND u.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'pending_verification',(SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'verified_members',    (SELECT count(*) FROM users u WHERE u.verification_status = 'approved' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'rejected_members',    (SELECT count(*) FROM users u WHERE u.verification_status = 'rejected' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_today',           (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('day', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_this_week',       (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('week', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
    'new_this_month',      (SELECT count(*) FROM users u WHERE u.created_at >= date_trunc('month', v_now) AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),

    -- Drivers
    'total_drivers',       (SELECT count(*) FROM drivers d WHERE v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions)),
    'online_drivers',      (SELECT count(*) FROM drivers d WHERE d.is_online = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),
    'verified_drivers',    (SELECT count(*) FROM drivers d WHERE d.is_verified = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),

    -- Merchants
    'total_merchants',     (SELECT count(*) FROM merchants m WHERE v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions)),
    'active_merchants',    (SELECT count(*) FROM merchants m WHERE m.status = 'active' AND (v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions))),
    'merchants_by_type',   (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', c)), '[]'::jsonb)
      FROM (SELECT m.type, count(*) as c FROM merchants m
            WHERE v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions)
            GROUP BY m.type) sub
    ),

    -- Orders
    'total_orders',        (SELECT count(*) FROM orders o WHERE v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)),
    'orders_today',        (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('day', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'orders_this_week',    (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('week', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'orders_this_month',   (SELECT count(*) FROM orders o WHERE o.created_at >= date_trunc('month', v_now) AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'completed_orders',    (SELECT count(*) FROM orders o WHERE o.status = 'completed' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'pending_orders',      (SELECT count(*) FROM orders o WHERE o.status = 'pending' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'cancelled_orders',    (SELECT count(*) FROM orders o WHERE o.status = 'cancelled' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),

    -- Rides & Deliveries
    'total_rides',         (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'completed_rides',     (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'active_rides',        (SELECT count(*) FROM rides r WHERE r.service_type = 'ride' AND r.status IN ('searching','matched','arrived','inTrip') AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'total_deliveries',    (SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'completed_deliveries',(SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'active_deliveries',   (SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status IN ('searching','matched','arrived','inTrip') AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),

    -- Service Bookings (region via service address geocode)
    'total_service_bookings',  (SELECT count(*) FROM service_bookings sb WHERE v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions)),
    'completed_service_bookings',(SELECT count(*) FROM service_bookings sb WHERE sb.status = 'completed' AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),

    -- Financial (conditional on permission)
    'total_gmv',           CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'completed' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
    ELSE 0 END,
    'ride_gmv',            CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
    ELSE 0 END,
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
    ELSE 0 END,
    'service_gmv',         CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions)))
    ELSE 0 END,
    'platform_commission', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions)))
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(de.amount), 0) FROM driver_earnings de WHERE de.created_at >= v_from AND de.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = de.driver_id), v_regions)))
    ELSE 0 END,
    'total_wallet_liability',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w WHERE v_regions IS NULL OR public._user_in_regions(w.user_id, v_regions))
    ELSE 0 END,
    -- Commission buckets cannot be region-split without redefining the
    -- bucket helper; scoped admins get 0 rather than platform-wide numbers.
    'commission_7pct',     CASE WHEN v_has_revenue AND v_regions IS NULL THEN
      public._commission_bucket_amount(v_from, v_to, 'provider')
    ELSE 0 END,
    'commission_3pct',     CASE WHEN v_has_revenue AND v_regions IS NULL THEN
      public._commission_bucket_amount(v_from, v_to, 'merchant')
    ELSE 0 END,

    -- Risk
    'open_complaints',     (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'escalated_complaints', (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'active_sanctions',    (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))),
    'sos_active',          (SELECT count(*) FROM sos_alerts s WHERE s.status = 'active' AND (v_regions IS NULL OR COALESCE(public._point_region_id(s.latitude, s.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = s.user_id LIMIT 1)) = ANY(v_regions))),
    'pending_withdrawals', (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
    'payment_failures',    (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= v_from AND pt.created_at <= v_to AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))),

    -- Period
    'date_from', v_from
  ) || jsonb_build_object('date_to', v_to) INTO v_result;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_operational_alerts()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_regions uuid[];
  v_alerts jsonb := '[]'::jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;

  v_regions := public._kpi_effective_regions(NULL);

  IF (SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'verification_backlog', 'severity', 'warning',
      'message', 'Pending verification backlog',
      'count', (SELECT count(*) FROM users u WHERE u.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(u.id, v_regions))),
      'action_route', '/admin/verifications'
    );
  END IF;

  IF (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'open_complaints', 'severity', 'warning',
      'message', 'Open complaints require attention',
      'count', (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
      'action_route', '/admin/complaints'
    );
  END IF;

  IF (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'escalated_complaints', 'severity', 'critical',
      'message', 'Escalated complaints need immediate attention',
      'count', (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
      'action_route', '/admin/escalations'
    );
  END IF;

  IF (SELECT count(*) FROM sos_alerts s WHERE s.status = 'active' AND (v_regions IS NULL OR COALESCE(public._point_region_id(s.latitude, s.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = s.user_id LIMIT 1)) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'active_sos', 'severity', 'critical',
      'message', 'Active emergency SOS alerts',
      'count', (SELECT count(*) FROM sos_alerts s WHERE s.status = 'active' AND (v_regions IS NULL OR COALESCE(public._point_region_id(s.latitude, s.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = s.user_id LIMIT 1)) = ANY(v_regions))),
      'action_route', '/admin/live-tracking'
    );
  END IF;

  IF (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'pending_withdrawals', 'severity', 'info',
      'message', 'Pending withdrawal requests',
      'count', (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
      'action_route', '/admin/drivers'
    );
  END IF;

  IF (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= now() - interval '24 hours' AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'payment_failures', 'severity', 'warning',
      'message', 'Payment failures in last 24 hours',
      'count', (SELECT count(*) FROM payment_transactions pt WHERE pt.status = 'failed' AND pt.created_at >= now() - interval '24 hours' AND (v_regions IS NULL OR public._order_region(pt.order_id) = ANY(v_regions))),
      'action_route', '/admin/orders'
    );
  END IF;

  IF (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'active_sanctions', 'severity', 'info',
      'message', 'Active sanctions on platform',
      'count', (SELECT count(*) FROM sanctions s WHERE s.is_active = true AND (v_regions IS NULL OR public._user_in_regions(s.target_user_id, v_regions))),
      'action_route', '/admin/sanctions'
    );
  END IF;

  RETURN jsonb_build_object('alerts', v_alerts, 'count', jsonb_array_length(v_alerts));
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_revenue_breakdown(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_region_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE');
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  v_regions := public._kpi_effective_regions(p_region_id);

  RETURN jsonb_build_object(
    'orders_gmv',     (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'completed' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'ride_gmv',       (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'delivery_gmv',   (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'service_gmv',    (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),
    'total_gmv',      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'completed' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
      + (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
      + (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),
    'total_commission',     (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    'fulfilled_commission', (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.status = 'fulfilled' AND pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    'pending_commission',   (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.status = 'pending' AND pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    -- Buckets are not region-splittable without redefining the helper;
    -- scoped admins get 0 rather than platform-wide numbers.
    'commission_7pct',      CASE WHEN v_regions IS NULL THEN public._commission_bucket_amount(v_from, v_to, 'provider') ELSE 0 END,
    'commission_3pct',      CASE WHEN v_regions IS NULL THEN public._commission_bucket_amount(v_from, v_to, 'merchant') ELSE 0 END,
    'provider_earnings',    (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),
    'driver_earnings',      (SELECT COALESCE(SUM(de.amount), 0) FROM driver_earnings de WHERE de.created_at >= v_from AND de.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = de.driver_id), v_regions))),
    'refund_count',         (SELECT count(*) FROM orders o WHERE o.status = 'cancelled' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'financial_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'gmv', gmv, 'commission', 0)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', o.created_at)::date as day, COALESCE(SUM(o.total_amount), 0) as gmv
        FROM orders o WHERE o.status = 'completed' AND o.created_at >= v_from AND o.created_at <= v_to
          AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))
        GROUP BY day ORDER BY day
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public._kpi_effective_regions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._user_in_regions(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public._order_region(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._ride_region(uuid) TO authenticated;
