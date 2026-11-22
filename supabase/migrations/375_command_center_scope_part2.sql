-- 375: scope-correct the remaining Command Center RPCs (part 2 of 374).
-- These seven took no p_region_id and returned platform-wide numbers to any
-- admin with MEMBER_VIEW. Each now limits region-scoped admins to their 373
-- footprint via _kpi_effective_regions(NULL) (NULL = owner/country,
-- unrestricted). Region attribution follows 372/374: users/drivers via
-- user_region_preferences, merchants/orders via _merchant_region_id, rides
-- via merchant else pickup geocode, bookings/providers via geocode, wallets
-- and commissions via user prefs, complaints via order/ride/complainant.
-- commission_rules and platform config rows stay platform-wide (config, not
-- counters); escalation_events scope via their complaint when entity_type =
-- 'complaint' and are hidden from scoped admins otherwise.

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
        LEFT JOIN service_providers sp ON sp.user_id = sb.provider_id
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

CREATE OR REPLACE FUNCTION public.platform_delivery_intelligence(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'total_drivers',       (SELECT count(*) FROM drivers d WHERE v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions)),
    'online_drivers',      (SELECT count(*) FROM drivers d WHERE d.is_online = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),
    'verified_drivers',    (SELECT count(*) FROM drivers d WHERE d.is_verified = true AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),
    'pending_drivers',     (SELECT count(*) FROM drivers d WHERE d.verification_status = 'pending' AND (v_regions IS NULL OR public._user_in_regions(d.user_id, v_regions))),
    'completed_deliveries',(SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'pending_deliveries',  (SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status IN ('searching','matched','arrived') AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'cancelled_deliveries',(SELECT count(*) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'cancelled' AND r.cancelled_at >= v_from AND r.cancelled_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))),
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(r.fare), 0) FROM rides r WHERE r.service_type != 'ride' AND r.status = 'completed' AND r.completed_at >= v_from AND r.completed_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)))
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(de.amount), 0) FROM driver_earnings de WHERE de.created_at >= v_from AND de.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = de.driver_id), v_regions)))
    ELSE 0 END,
    'pending_withdrawals',    (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
    'pending_withdrawal_amount', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(wr.amount), 0) FROM withdrawal_requests wr WHERE wr.status = 'pending' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions)))
    ELSE 0 END,
    'paid_withdrawals',       (SELECT count(*) FROM withdrawal_requests wr WHERE wr.status = 'paid' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions))),
    'paid_withdrawal_amount', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(wr.amount), 0) FROM withdrawal_requests wr WHERE wr.status = 'paid' AND (v_regions IS NULL OR public._user_in_regions((SELECT d.user_id FROM drivers d WHERE d.id = wr.driver_id), v_regions)))
    ELSE 0 END,
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_merchant_intelligence(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_has_rev boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;
  v_has_rev := has_permission('PLATFORM_REVENUE');
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'total_merchants', (SELECT count(*) FROM merchants m WHERE v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions)),
    'active_merchants', (SELECT count(*) FROM merchants m WHERE m.status='active' AND (v_regions IS NULL OR public._merchant_region_id(m.id) = ANY(v_regions))),
    'merchants_by_type', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', sub.typ, 'count', sub.cnt)), '[]'::jsonb)
      FROM (SELECT m2.type as typ, count(*) as cnt FROM merchants m2
            WHERE v_regions IS NULL OR public._merchant_region_id(m2.id) = ANY(v_regions)
            GROUP BY m2.type) sub
    ),
    'merchants', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', m2.id, 'name', m2.name, 'type', m2.type, 'status', m2.status,
        'rating', m2.rating, 'total_orders', m2.total_orders
      ) ORDER BY m2.total_orders DESC NULLS LAST), '[]'::jsonb)
      FROM merchants m2
      WHERE v_regions IS NULL OR public._merchant_region_id(m2.id) = ANY(v_regions)
    ),
    'date_from', v_from,
    'date_to', v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_wallet_intelligence(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'wallet_count',      (SELECT count(*) FROM wallets w WHERE v_regions IS NULL OR public._user_in_regions(w.user_id, v_regions)),
    'total_liability',   (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w WHERE v_regions IS NULL OR public._user_in_regions(w.user_id, v_regions)),
    'avg_balance',       (SELECT COALESCE(AVG(w.balance), 0) FROM wallets w WHERE v_regions IS NULL OR public._user_in_regions(w.user_id, v_regions)),
    'transactions_by_type', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', cnt, 'total', total)), '[]'::jsonb)
      FROM (
        SELECT wt.type, count(*) as cnt, COALESCE(SUM(wt.amount), 0) as total
        FROM wallet_transactions wt WHERE wt.created_at >= v_from AND wt.created_at <= v_to
          AND (v_regions IS NULL OR public._user_in_regions(wt.user_id, v_regions))
        GROUP BY wt.type
      ) sub
    ),
    'total_transactions', (SELECT count(*) FROM wallet_transactions wt WHERE wt.created_at >= v_from AND wt.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(wt.user_id, v_regions))),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_provider_intelligence(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
    'total_providers',    (SELECT count(*) FROM service_providers sp WHERE v_regions IS NULL OR COALESCE(public._point_region_id(sp.latitude, sp.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = sp.user_id LIMIT 1)) = ANY(v_regions)),
    'verified_providers', (SELECT count(*) FROM service_providers sp WHERE sp.is_verified = true AND (v_regions IS NULL OR COALESCE(public._point_region_id(sp.latitude, sp.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = sp.user_id LIMIT 1)) = ANY(v_regions))),
    'available_providers',(SELECT count(*) FROM service_providers sp WHERE sp.is_available = true AND (v_regions IS NULL OR COALESCE(public._point_region_id(sp.latitude, sp.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = sp.user_id LIMIT 1)) = ANY(v_regions))),
    'providers_by_category', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category_type, 'count', cnt, 'avg_rating', avg_r)), '[]'::jsonb)
      FROM (
        SELECT sp.category_type, count(*) as cnt, COALESCE(AVG(sp.rating), 0) as avg_r
        FROM service_providers sp
        WHERE v_regions IS NULL OR COALESCE(public._point_region_id(sp.latitude, sp.longitude), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = sp.user_id LIMIT 1)) = ANY(v_regions)
        GROUP BY sp.category_type
      ) sub
    ),
    'bookings_by_category', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category_type, 'total', t, 'completed', c, 'gmv', g)), '[]'::jsonb)
      FROM (
        SELECT sb.category_type, count(*) as t,
          count(*) FILTER (WHERE sb.status = 'completed') as c,
          COALESCE(SUM(sb.final_price) FILTER (WHERE sb.status = 'completed'), 0) as g
        FROM service_bookings sb WHERE sb.created_at >= v_from AND sb.created_at <= v_to
          AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions))
        GROUP BY sb.category_type
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_commission_summary(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'total_commission',     (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    'fulfilled_commission', (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.status = 'fulfilled' AND pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    'pending_commission',   (SELECT COALESCE(SUM(pc.commission_amount), 0) FROM platform_commissions pc WHERE pc.status = 'pending' AND pc.created_at >= v_from AND pc.created_at <= v_to AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))),
    'commission_by_rate', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('rate', pc.commission_rate, 'amount', pc.commission_amount)), '[]'::jsonb)
      FROM platform_commissions pc WHERE pc.created_at >= v_from AND pc.created_at <= v_to
        AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions))
    ),
    -- Platform commission rules are global config, not counters.
    'active_rules', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'entity_type', entity_type, 'entity_key', entity_key, 'rate', rate, 'currency', currency
      )), '[]'::jsonb)
      FROM commission_rules WHERE is_active = true
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_complaint_summary(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
    'total_complaints',    (SELECT count(*) FROM complaints c WHERE c.created_at >= v_from AND c.created_at <= v_to AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'open_complaints',     (SELECT count(*) FROM complaints c WHERE c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'escalated_complaints', (SELECT count(*) FROM complaints c WHERE c.escalated_at IS NOT NULL AND c.status NOT IN ('resolved','closed') AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'resolved_complaints', (SELECT count(*) FROM complaints c WHERE c.status IN ('resolved','closed') AND c.resolved_at >= v_from AND c.resolved_at <= v_to AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))),
    'complaints_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT c.status, count(*) as cnt FROM complaints c
            WHERE c.created_at >= v_from AND c.created_at <= v_to
              AND (v_regions IS NULL OR COALESCE(public._order_region(c.order_id), public._ride_region(c.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c.complainant_id LIMIT 1)) = ANY(v_regions))
            GROUP BY c.status) sub
    ),
    -- Escalation events scope via their complaint; non-complaint events are
    -- hidden from scoped admins.
    'escalation_events',   (SELECT count(*) FROM escalation_events ee WHERE ee.created_at >= v_from AND ee.created_at <= v_to AND (v_regions IS NULL OR (ee.entity_type = 'complaint' AND (SELECT COALESCE(public._order_region(c2.order_id), public._ride_region(c2.ride_id), (SELECT urp.region_id FROM public.user_region_preferences urp WHERE urp.user_id = c2.complainant_id LIMIT 1)) FROM public.complaints c2 WHERE c2.id = ee.entity_id::uuid) = ANY(v_regions)))),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

-- 374b: re-define the 374 trio with the corrected has_permission calls
-- (374 passed v_member_id as the p_region_id argument; owner bypassed it,
-- every other admin was denied). Files for fresh databases are fixed in
-- 374 itself; this re-definition repairs databases where 374 already ran.

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

-- 374c: four more platform_* RPCs carried the same pre-existing defect,
-- passing the caller's member/auth id as has_permission's p_region_id
-- (owner bypassed, every other admin denied). Fixed calls, plus the same
-- region scoping as the rest of this migration.

CREATE OR REPLACE FUNCTION public.platform_orders_timeseries(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, v_now - interval '30 days');
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'orders_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT o.status, count(*) as cnt FROM orders o WHERE o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)) GROUP BY o.status) sub
    ),
    'rides_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT r.status, count(*) as cnt FROM rides r WHERE r.service_type = 'ride' AND r.created_at >= v_from AND r.created_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)) GROUP BY r.status) sub
    ),
    'deliveries_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'service_type', service_type, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT r.status, r.service_type, count(*) as cnt FROM rides r WHERE r.service_type != 'ride' AND r.created_at >= v_from AND r.created_at <= v_to AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions)) GROUP BY r.status, r.service_type) sub
    ),
    'service_bookings_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'category_type', category_type, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT sb.status, sb.category_type, count(*) as cnt FROM service_bookings sb WHERE sb.created_at >= v_from AND sb.created_at <= v_to AND (v_regions IS NULL OR public._point_region_id(sb.address_latitude, sb.address_longitude) = ANY(v_regions)) GROUP BY sb.status, sb.category_type) sub
    ),
    'orders_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT date_trunc('day', o.created_at)::date as day, count(*) as cnt FROM orders o WHERE o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)) GROUP BY day ORDER BY day) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.platform_rides_timeseries(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, v_now - interval '30 days');
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_regions uuid[];
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;
  v_regions := public._kpi_effective_regions(NULL);

  RETURN jsonb_build_object(
    'rides_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt, 'gmv', gmv)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', r.created_at)::date as day, count(*) as cnt,
          COALESCE(SUM(r.fare) FILTER (WHERE r.status = 'completed'), 0) as gmv
        FROM rides r WHERE r.service_type = 'ride' AND r.created_at >= v_from AND r.created_at <= v_to
          AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))
        GROUP BY day ORDER BY day
      ) sub
    ),
    'deliveries_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt, 'gmv', gmv)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', r.created_at)::date as day, count(*) as cnt,
          COALESCE(SUM(r.fare) FILTER (WHERE r.status = 'completed'), 0) as gmv
        FROM rides r WHERE r.service_type != 'ride' AND r.created_at >= v_from AND r.created_at <= v_to
          AND (v_regions IS NULL OR COALESCE(public._merchant_region_id(r.merchant_id), public._point_region_id(r.pickup_latitude, r.pickup_longitude)) = ANY(v_regions))
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
    'total_gmv',      (SELECT COALESCE(SUM(o.total_amount), 0) FROM orders o WHERE o.status = 'completed' AND o.created_at >= v_from AND o.created_at <= v_to AND (v_regions IS NULL OR public._merchant_region_id(o.merchant_id) = ANY(v_regions)))
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

CREATE OR REPLACE FUNCTION public.platform_transaction_ledger(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_type text DEFAULT NULL::text, p_member_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_id uuid;
  v_has_rev boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_total integer;
  v_regions uuid[];
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL OR NOT has_permission('MEMBER_VIEW') THEN
    RETURN NULL;
  END IF;
  v_has_rev := has_permission('PLATFORM_REVENUE');
  IF NOT v_has_rev THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;
  v_regions := public._kpi_effective_regions(NULL);

  SELECT count(*) INTO v_total
  FROM platform_commissions pc
  WHERE pc.created_at >= v_from AND pc.created_at <= v_to
    AND (p_type IS NULL OR pc.reference_type = p_type)
    AND (p_member_id IS NULL OR pc.member_id = p_member_id)
    AND (v_regions IS NULL OR public._user_in_regions(pc.member_id, v_regions));

  RETURN jsonb_build_object(
    'total', v_total,
    'page', (p_offset / p_limit) + 1,
    'page_size', p_limit,
    'total_pages', CEIL(v_total::float / p_limit),
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', x.id, 'member_id', x.member_id, 'reference_type', x.reference_type,
        'reference_id', x.reference_id, 'gross_amount', x.gross_amount,
        'commission_rate', x.commission_rate, 'commission_amount', x.commission_amount,
        'net_amount', x.net_amount, 'currency', x.currency, 'status', x.status,
        'created_at', x.created_at
      )), '[]'::jsonb)
      FROM (
        SELECT pc2.id, pc2.member_id, pc2.reference_type, pc2.reference_id,
               pc2.gross_amount, pc2.commission_rate, pc2.commission_amount,
               pc2.net_amount, pc2.currency, pc2.status, pc2.created_at
        FROM platform_commissions pc2
        WHERE pc2.created_at >= v_from AND pc2.created_at <= v_to
          AND (p_type IS NULL OR pc2.reference_type = p_type)
          AND (p_member_id IS NULL OR pc2.member_id = p_member_id)
          AND (v_regions IS NULL OR public._user_in_regions(pc2.member_id, v_regions))
        ORDER BY pc2.created_at DESC
        LIMIT p_limit OFFSET p_offset
      ) x
    )
  );
END;
$function$;
