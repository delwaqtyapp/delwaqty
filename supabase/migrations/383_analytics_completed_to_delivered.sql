-- 383: analytics fixes (reviewer #43 + service-performance join)
-- 1) orders.status terminal success is 'delivered', not 'completed'
--    (orders_status_check: pending/confirmed/preparing/ready/delivering/delivered/cancelled).
--    platform_kpi_summary, platform_revenue_breakdown, platform_revenue_overview
--    filtered orders by 'completed', which matches no rows -> GMV/orders counts were zero.
-- 2) platform_service_performance joined service_providers ON sp.user_id = sb.provider_id;
--    service_bookings.provider_id references service_providers.id (see confirm_cash_collection),
--    so avg_rating was always NULL / join never matched.
-- Definitions are the CURRENT prod definitions (pg_get_functiondef) with only these literals changed.

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
    'completed_orders',    (SELECT count(*) FROM orders o WHERE o.status = 'delivered' AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
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
      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
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
    'orders_gmv',     (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'ride_gmv',       (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type = 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'delivery_gmv',   (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'service_gmv',    (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),
    'total_gmv',      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
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
        FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to
          AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))
        GROUP BY day ORDER BY day
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_revenue_overview(p_period text DEFAULT 'all'::text, p_service_category text DEFAULT NULL::text, p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz;
  v_to   timestamptz;
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
  v_regions := public._kpi_effective_regions(NULL);

  v_to := v_now;
  v_from := CASE p_period
    WHEN 'today' THEN date_trunc('day', v_now)
    WHEN 'yesterday' THEN date_trunc('day', v_now) - interval '1 day'
    WHEN '7d' THEN v_now - interval '7 days'
    WHEN '30d' THEN v_now - interval '30 days'
    WHEN 'month' THEN date_trunc('month', v_now)
    WHEN 'last_month' THEN date_trunc('month', v_now) - interval '1 month'
    WHEN 'year' THEN date_trunc('year', v_now)
    WHEN 'custom' THEN COALESCE(p_from::timestamptz, '1970-01-01'::timestamptz)
    ELSE '1970-01-01'::timestamptz
  END;

  IF p_period = 'custom' AND p_to IS NOT NULL THEN
    v_to := p_to::timestamptz + interval '1 day';
  END IF;

  RETURN jsonb_build_object(
    'total_gmv',      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'delivered' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
      + (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
      + (SELECT COALESCE(SUM(sb.final_price), 0) FROM service_bookings sb WHERE sb.status = 'completed' AND sb.completed_at >= v_from AND sb.completed_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))),
    'total_commission',(SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    -- Buckets are not region-splittable; scoped admins get 0, not globals.
    'commission_7pct', CASE WHEN v_regions IS NULL THEN public._commission_bucket_amount(v_from, v_to, 'provider') ELSE 0 END,
    'commission_3pct', CASE WHEN v_regions IS NULL THEN public._commission_bucket_amount(v_from, v_to, 'merchant') ELSE 0 END,
    'refund_count',    (SELECT count(*) FROM orders o WHERE o.status = 'cancelled' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions))),
    'period',          p_period,
    'date_from',       v_from,
    'date_to',         v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_service_performance(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;

  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'delivery_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'service_type', service_type, 'total', total, 'completed', completed,
        'cancelled', cancelled, 'gmv', gmv
      )), '[]'::jsonb)
      FROM (
        SELECT r.service_type, count(*) as total,
          count(*) FILTER (WHERE r.status = 'completed') as completed,
          count(*) FILTER (WHERE r.status = 'cancelled') as cancelled,
          COALESCE(SUM(r.fare) FILTER (WHERE r.status = 'completed'), 0) as gmv
        FROM rides r
        WHERE r.service_type != 'ride' AND r.created_at >= v_from AND r.created_at <= v_to
          AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))
        GROUP BY r.service_type
      ) sub
    ),
    'home_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'category_type', category_type, 'total', total, 'completed', completed,
        'cancelled', cancelled, 'gmv', gmv, 'avg_rating', avg_rating
      )), '[]'::jsonb)
      FROM (
        SELECT sb.category_type, count(*) as total,
          count(*) FILTER (WHERE sb.status = 'completed') as completed,
          count(*) FILTER (WHERE sb.status = 'cancelled') as cancelled,
          COALESCE(SUM(sb.final_price) FILTER (WHERE sb.status = 'completed'), 0) as gmv,
          COALESCE(AVG(sp.rating), 0) as avg_rating
        FROM service_bookings sb
        LEFT JOIN service_providers sp ON sp.id = sb.provider_id
        WHERE sb.created_at >= v_from AND sb.created_at <= v_to
          AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))
        GROUP BY sb.category_type
      ) sub
    ),
    'ride_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'ride_type', ride_type, 'total', total, 'completed', completed,
        'cancelled', cancelled, 'gmv', gmv
      )), '[]'::jsonb)
      FROM (
        SELECT r.ride_type, count(*) as total,
          count(*) FILTER (WHERE r.status = 'completed') as completed,
          count(*) FILTER (WHERE r.status = 'cancelled') as cancelled,
          COALESCE(SUM(r.fare) FILTER (WHERE r.status = 'completed'), 0) as gmv
        FROM rides r
        WHERE r.service_type = 'ride' AND r.created_at >= v_from AND r.created_at <= v_to
          AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))
        GROUP BY r.ride_type
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;
