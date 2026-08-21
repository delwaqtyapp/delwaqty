-- MIGRATION 050: Platform Operations + Financial Intelligence Center RPCs
-- STEP 16: Drop broken RPCs from earlier steps and recreate correctly
-- All RPCs are SECURITY DEFINER, admin-only via has_permission()

-- ============================================================
-- DROP ALL EXISTING BROKEN PLATFORM RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.platform_kpi_summary(timestamptz, timestamptz, uuid);
DROP FUNCTION IF EXISTS public.platform_orders_timeseries(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_revenue_breakdown(timestamptz, timestamptz, uuid);
DROP FUNCTION IF EXISTS public.platform_service_performance(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_delivery_intelligence(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_merchant_intelligence(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_wallet_intelligence(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_provider_intelligence(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_operational_alerts();
DROP FUNCTION IF EXISTS public.platform_transaction_ledger(timestamptz, timestamptz, text, uuid, text, integer, integer);
DROP FUNCTION IF EXISTS public.platform_commission_summary(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_complaint_summary(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_rides_timeseries(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.platform_revenue_overview(text, text, date, date);

-- ============================================================
-- 050.1: PLATFORM KPI SUMMARY
-- Returns all top-level dashboard KPIs in a single call
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_kpi_summary(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_result jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);

  SELECT jsonb_build_object(
    -- Members
    'total_users',         (SELECT count(*) FROM users),
    'customers',           (SELECT count(*) FROM users WHERE user_type = 'customer'),
    'providers',           (SELECT count(*) FROM users WHERE user_type = 'provider'),
    'delivery_users',      (SELECT count(*) FROM users WHERE user_type = 'delivery'),
    'merchant_users',      (SELECT count(*) FROM users WHERE user_type = 'merchant'),
    'driver_users',        (SELECT count(*) FROM users WHERE user_type = 'driver'),
    'new_users_period',    (SELECT count(*) FROM users WHERE created_at >= v_from AND created_at <= v_to),
    'pending_verification',(SELECT count(*) FROM users WHERE verification_status = 'pending'),
    'verified_members',    (SELECT count(*) FROM users WHERE verification_status = 'approved'),
    'rejected_members',    (SELECT count(*) FROM users WHERE verification_status = 'rejected'),
    'new_today',           (SELECT count(*) FROM users WHERE created_at >= date_trunc('day', v_now)),
    'new_this_week',       (SELECT count(*) FROM users WHERE created_at >= date_trunc('week', v_now)),
    'new_this_month',      (SELECT count(*) FROM users WHERE created_at >= date_trunc('month', v_now)),

    -- Drivers
    'total_drivers',       (SELECT count(*) FROM drivers),
    'online_drivers',      (SELECT count(*) FROM drivers WHERE is_online = true),
    'verified_drivers',    (SELECT count(*) FROM drivers WHERE is_verified = true),

    -- Merchants
    'total_merchants',     (SELECT count(*) FROM merchants),
    'active_merchants',    (SELECT count(*) FROM merchants WHERE status = 'active'),
    'merchants_by_type',   (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', c)), '[]'::jsonb)
      FROM (SELECT type, count(*) as c FROM merchants GROUP BY type) sub
    ),

    -- Orders
    'total_orders',        (SELECT count(*) FROM orders),
    'orders_today',        (SELECT count(*) FROM orders WHERE created_at >= date_trunc('day', v_now)),
    'orders_this_week',    (SELECT count(*) FROM orders WHERE created_at >= date_trunc('week', v_now)),
    'orders_this_month',   (SELECT count(*) FROM orders WHERE created_at >= date_trunc('month', v_now)),
    'completed_orders',    (SELECT count(*) FROM orders WHERE status = 'completed'),
    'pending_orders',      (SELECT count(*) FROM orders WHERE status = 'pending'),
    'cancelled_orders',    (SELECT count(*) FROM orders WHERE status = 'cancelled'),

    -- Rides & Deliveries
    'total_rides',         (SELECT count(*) FROM rides WHERE service_type = 'ride'),
    'completed_rides',     (SELECT count(*) FROM rides WHERE service_type = 'ride' AND status = 'completed'),
    'active_rides',        (SELECT count(*) FROM rides WHERE service_type = 'ride' AND status IN ('searching','matched','arrived','inTrip')),
    'total_deliveries',    (SELECT count(*) FROM rides WHERE service_type != 'ride'),
    'completed_deliveries',(SELECT count(*) FROM rides WHERE service_type != 'ride' AND status = 'completed'),
    'active_deliveries',   (SELECT count(*) FROM rides WHERE service_type != 'ride' AND status IN ('searching','matched','arrived','inTrip')),

    -- Service Bookings
    'total_service_bookings',  (SELECT count(*) FROM service_bookings),
    'completed_service_bookings',(SELECT count(*) FROM service_bookings WHERE status = 'completed'),

    -- Financial (conditional on permission)
    'total_gmv',           CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'ride_gmv',            CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type = 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type != 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'service_gmv',         CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'platform_commission', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(amount), 0) FROM driver_earnings WHERE created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'total_wallet_liability',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(balance), 0) FROM wallets)
    ELSE 0 END,
    'commission_7pct',     CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 7 AND created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'commission_3pct',     CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 3 AND created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,

    -- Risk
    'open_complaints',     (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')),
    'escalated_complaints', (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')),
    'active_sanctions',    (SELECT count(*) FROM sanctions WHERE is_active = true),
    'sos_active',          (SELECT count(*) FROM sos_alerts WHERE status = 'active'),
    'pending_withdrawals', (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending'),
    'payment_failures',    (SELECT count(*) FROM payment_transactions WHERE status = 'failed' AND created_at >= v_from AND created_at <= v_to),

    -- Period
    'date_from', v_from
  ) || jsonb_build_object('date_to', v_to) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 050.2: PLATFORM ORDERS TIMESERIES
-- Orders/rides/bookings by day for chart
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_orders_timeseries(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, v_now - interval '30 days');
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'orders_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT status, count(*) as cnt FROM orders WHERE created_at >= v_from AND created_at <= v_to GROUP BY status) sub
    ),
    'rides_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT status, count(*) as cnt FROM rides WHERE service_type = 'ride' AND created_at >= v_from AND created_at <= v_to GROUP BY status) sub
    ),
    'deliveries_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'service_type', service_type, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT status, service_type, count(*) as cnt FROM rides WHERE service_type != 'ride' AND created_at >= v_from AND created_at <= v_to GROUP BY status, service_type) sub
    ),
    'service_bookings_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'category_type', category_type, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT status, category_type, count(*) as cnt FROM service_bookings WHERE created_at >= v_from AND created_at <= v_to GROUP BY status, category_type) sub
    ),
    'orders_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT date_trunc('day', created_at)::date as day, count(*) as cnt FROM orders WHERE created_at >= v_from AND created_at <= v_to GROUP BY day ORDER BY day) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.3: PLATFORM REVENUE BREAKDOWN
-- GMV, commission, refunds, net revenue by period
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_revenue_breakdown(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  RETURN jsonb_build_object(
    'orders_gmv',     (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to),
    'ride_gmv',       (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type = 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'delivery_gmv',   (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type != 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'service_gmv',    (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'total_gmv',      (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to)
      + (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
      + (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'total_commission',     (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to),
    'fulfilled_commission', (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE status = 'fulfilled' AND created_at >= v_from AND created_at <= v_to),
    'pending_commission',   (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE status = 'pending' AND created_at >= v_from AND created_at <= v_to),
    'commission_7pct',      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 7 AND created_at >= v_from AND created_at <= v_to),
    'commission_3pct',      (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 3 AND created_at >= v_from AND created_at <= v_to),
    'provider_earnings',    (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'driver_earnings',      (SELECT COALESCE(SUM(amount), 0) FROM driver_earnings WHERE created_at >= v_from AND created_at <= v_to),
    'refund_count',         (SELECT count(*) FROM orders WHERE status = 'cancelled' AND created_at >= v_from AND created_at <= v_to),
    'financial_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'gmv', gmv, 'commission', 0)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', created_at)::date as day, COALESCE(SUM(total_amount), 0) as gmv
        FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to
        GROUP BY day ORDER BY day
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.4: PLATFORM SERVICE PERFORMANCE
-- Per-service-category metrics
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_service_performance(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'delivery_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'service_type', service_type, 'total', total, 'completed', completed,
        'cancelled', cancelled, 'gmv', gmv
      )), '[]'::jsonb)
      FROM (
        SELECT service_type, count(*) as total,
          count(*) FILTER (WHERE status = 'completed') as completed,
          count(*) FILTER (WHERE status = 'cancelled') as cancelled,
          COALESCE(SUM(fare) FILTER (WHERE status = 'completed'), 0) as gmv
        FROM rides WHERE service_type != 'ride' AND created_at >= v_from AND created_at <= v_to
        GROUP BY service_type
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
        GROUP BY sb.category_type
      ) sub
    ),
    'ride_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'ride_type', ride_type, 'total', total, 'completed', completed,
        'cancelled', cancelled, 'gmv', gmv
      )), '[]'::jsonb)
      FROM (
        SELECT ride_type, count(*) as total,
          count(*) FILTER (WHERE status = 'completed') as completed,
          count(*) FILTER (WHERE status = 'cancelled') as cancelled,
          COALESCE(SUM(fare) FILTER (WHERE status = 'completed'), 0) as gmv
        FROM rides WHERE service_type = 'ride' AND created_at >= v_from AND created_at <= v_to
        GROUP BY ride_type
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.5: PLATFORM DELIVERY INTELLIGENCE
-- Driver stats, delivery GMV, earnings
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_delivery_intelligence(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);

  RETURN jsonb_build_object(
    'total_drivers',       (SELECT count(*) FROM drivers),
    'online_drivers',      (SELECT count(*) FROM drivers WHERE is_online = true),
    'verified_drivers',    (SELECT count(*) FROM drivers WHERE is_verified = true),
    'pending_drivers',     (SELECT count(*) FROM drivers WHERE verification_status = 'pending'),
    'completed_deliveries',(SELECT count(*) FROM rides WHERE service_type != 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'pending_deliveries',  (SELECT count(*) FROM rides WHERE service_type != 'ride' AND status IN ('searching','matched','arrived')),
    'cancelled_deliveries',(SELECT count(*) FROM rides WHERE service_type != 'ride' AND status = 'cancelled' AND cancelled_at >= v_from AND cancelled_at <= v_to),
    'delivery_gmv',        CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE service_type != 'ride' AND status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
    ELSE 0 END,
    'driver_earnings_total',CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(amount), 0) FROM driver_earnings WHERE created_at >= v_from AND created_at <= v_to)
    ELSE 0 END,
    'pending_withdrawals',    (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending'),
    'pending_withdrawal_amount', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(amount), 0) FROM withdrawal_requests WHERE status = 'pending')
    ELSE 0 END,
    'paid_withdrawals',       (SELECT count(*) FROM withdrawal_requests WHERE status = 'paid'),
    'paid_withdrawal_amount', CASE WHEN v_has_revenue THEN
      (SELECT COALESCE(SUM(amount), 0) FROM withdrawal_requests WHERE status = 'paid')
    ELSE 0 END,
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.6: PLATFORM MERCHANT INTELLIGENCE
-- Per-merchant metrics
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_merchant_intelligence(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);

  RETURN jsonb_build_object(
    'total_merchants',  (SELECT count(*) FROM merchants),
    'active_merchants', (SELECT count(*) FROM merchants WHERE status = 'active'),
    'merchants_by_type', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT type, count(*) as cnt FROM merchants GROUP BY type) sub
    ),
    'merchants', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', m.id, 'name', m.name, 'type', m.type, 'status', m.status,
        'rating', m.rating, 'total_orders', m.total_orders,
        'order_count_period', pc.order_count, 'gmv_period', pc.gmv
      )), '[]'::jsonb)
      FROM merchants m
      LEFT JOIN LATERAL (
        SELECT count(*) as order_count, COALESCE(SUM(o.total_amount), 0) as gmv
        FROM orders o WHERE o.merchant_id = m.id AND o.status = 'completed'
          AND o.created_at >= v_from AND o.created_at <= v_to
      ) pc ON true
      ORDER BY pc.gmv DESC NULLS LAST
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.7: PLATFORM WALLET INTELLIGENCE
-- Wallet liability, transactions
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_wallet_intelligence(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  RETURN jsonb_build_object(
    'wallet_count',      (SELECT count(*) FROM wallets),
    'total_liability',   (SELECT COALESCE(SUM(balance), 0) FROM wallets),
    'avg_balance',       (SELECT COALESCE(AVG(balance), 0) FROM wallets),
    'transactions_by_type', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', type, 'count', cnt, 'total', total)), '[]'::jsonb)
      FROM (
        SELECT type, count(*) as cnt, COALESCE(SUM(amount), 0) as total
        FROM wallet_transactions WHERE created_at >= v_from AND created_at <= v_to
        GROUP BY type
      ) sub
    ),
    'total_transactions', (SELECT count(*) FROM wallet_transactions WHERE created_at >= v_from AND created_at <= v_to),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.8: PLATFORM PROVIDER INTELLIGENCE
-- Service provider metrics
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_provider_intelligence(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'total_providers',    (SELECT count(*) FROM service_providers),
    'verified_providers', (SELECT count(*) FROM service_providers WHERE is_verified = true),
    'available_providers',(SELECT count(*) FROM service_providers WHERE is_available = true),
    'providers_by_category', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category_type, 'count', cnt, 'avg_rating', avg_r)), '[]'::jsonb)
      FROM (
        SELECT category_type, count(*) as cnt, COALESCE(AVG(rating), 0) as avg_r
        FROM service_providers GROUP BY category_type
      ) sub
    ),
    'bookings_by_category', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category_type, 'total', t, 'completed', c, 'gmv', g)), '[]'::jsonb)
      FROM (
        SELECT category_type, count(*) as t,
          count(*) FILTER (WHERE status = 'completed') as c,
          COALESCE(SUM(final_price) FILTER (WHERE status = 'completed'), 0) as g
        FROM service_bookings WHERE created_at >= v_from AND created_at <= v_to
        GROUP BY category_type
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.9: PLATFORM COMMISSION SUMMARY
-- Commission breakdown by rate
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_commission_summary(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  RETURN jsonb_build_object(
    'total_commission',     (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to),
    'fulfilled_commission', (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE status = 'fulfilled' AND created_at >= v_from AND created_at <= v_to),
    'pending_commission',   (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE status = 'pending' AND created_at >= v_from AND created_at <= v_to),
    'commission_by_rate', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('rate', commission_rate, 'amount', commission_amount)), '[]'::jsonb)
      FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to
    ),
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
$$;

-- ============================================================
-- 050.10: PLATFORM COMPLAINT SUMMARY
-- Complaint metrics
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_complaint_summary(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'total_complaints',    (SELECT count(*) FROM complaints WHERE created_at >= v_from AND created_at <= v_to),
    'open_complaints',     (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')),
    'escalated_complaints', (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')),
    'resolved_complaints', (SELECT count(*) FROM complaints WHERE status IN ('resolved','closed') AND resolved_at >= v_from AND resolved_at <= v_to),
    'complaints_by_status', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
      FROM (SELECT status, count(*) as cnt FROM complaints WHERE created_at >= v_from AND created_at <= v_to GROUP BY status) sub
    ),
    'escalation_events',   (SELECT count(*) FROM escalation_events WHERE created_at >= v_from AND created_at <= v_to),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.11: PLATFORM RIDES TIMESERIES
-- Rides/deliveries by day for chart
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_rides_timeseries(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, v_now - interval '30 days');
  v_to   timestamptz := COALESCE(p_to, v_now);
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'rides_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt, 'gmv', gmv)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', created_at)::date as day, count(*) as cnt,
          COALESCE(SUM(fare) FILTER (WHERE status = 'completed'), 0) as gmv
        FROM rides WHERE service_type = 'ride' AND created_at >= v_from AND created_at <= v_to
        GROUP BY day ORDER BY day
      ) sub
    ),
    'deliveries_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', day, 'count', cnt, 'gmv', gmv)), '[]'::jsonb)
      FROM (
        SELECT date_trunc('day', created_at)::date as day, count(*) as cnt,
          COALESCE(SUM(fare) FILTER (WHERE status = 'completed'), 0) as gmv
        FROM rides WHERE service_type != 'ride' AND created_at >= v_from AND created_at <= v_to
        GROUP BY day ORDER BY day
      ) sub
    ),
    'date_from', v_from,
    'date_to',   v_to
  );
END;
$$;

-- ============================================================
-- 050.12: PLATFORM TRANSACTION LEDGER
-- Paginated commission ledger
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_transaction_ledger(
  p_from      timestamptz DEFAULT NULL,
  p_to        timestamptz DEFAULT NULL,
  p_type      text DEFAULT NULL,
  p_member_id uuid DEFAULT NULL,
  p_search    text DEFAULT NULL,
  p_limit     integer DEFAULT 50,
  p_offset    integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz := COALESCE(p_from, '1970-01-01'::timestamptz);
  v_to   timestamptz := COALESCE(p_to, v_now);
  v_total integer;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  SELECT count(*) INTO v_total
  FROM platform_commissions pc
  WHERE pc.created_at >= v_from AND pc.created_at <= v_to
    AND (p_type IS NULL OR pc.reference_type = p_type)
    AND (p_member_id IS NULL OR pc.member_id = p_member_id);

  RETURN jsonb_build_object(
    'total', v_total,
    'page', (p_offset / p_limit) + 1,
    'page_size', p_limit,
    'total_pages', CEIL(v_total::float / p_limit),
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', pc.id, 'member_id', pc.member_id, 'reference_type', pc.reference_type,
        'reference_id', pc.reference_id, 'gross_amount', pc.gross_amount,
        'commission_rate', pc.commission_rate, 'commission_amount', pc.commission_amount,
        'net_amount', pc.net_amount, 'currency', pc.currency, 'status', pc.status,
        'created_at', pc.created_at
      )), '[]'::jsonb)
      FROM platform_commissions pc
      WHERE pc.created_at >= v_from AND pc.created_at <= v_to
        AND (p_type IS NULL OR pc.reference_type = p_type)
        AND (p_member_id IS NULL OR pc.member_id = p_member_id)
      ORDER BY pc.created_at DESC
      LIMIT p_limit OFFSET p_offset
    )
  );
END;
$$;

-- ============================================================
-- 050.13: PLATFORM OPERATIONAL ALERTS
-- Deterministic alerts based on actual data
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_operational_alerts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_alerts jsonb := '[]'::jsonb;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;

  IF (SELECT count(*) FROM users WHERE verification_status = 'pending') > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'verification_backlog', 'severity', 'warning',
      'message', 'Pending verification backlog',
      'count', (SELECT count(*) FROM users WHERE verification_status = 'pending'),
      'action_route', '/admin/verifications'
    );
  END IF;

  IF (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'open_complaints', 'severity', 'warning',
      'message', 'Open complaints require attention',
      'count', (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')),
      'action_route', '/admin/complaints'
    );
  END IF;

  IF (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'escalated_complaints', 'severity', 'critical',
      'message', 'Escalated complaints need immediate attention',
      'count', (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')),
      'action_route', '/admin/escalations'
    );
  END IF;

  IF (SELECT count(*) FROM sos_alerts WHERE status = 'active') > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'active_sos', 'severity', 'critical',
      'message', 'Active emergency SOS alerts',
      'count', (SELECT count(*) FROM sos_alerts WHERE status = 'active'),
      'action_route', '/admin/live-tracking'
    );
  END IF;

  IF (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending') > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'pending_withdrawals', 'severity', 'info',
      'message', 'Pending withdrawal requests',
      'count', (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending'),
      'action_route', '/admin/drivers'
    );
  END IF;

  IF (SELECT count(*) FROM payment_transactions WHERE status = 'failed' AND created_at >= now() - interval '24 hours') > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'payment_failures', 'severity', 'warning',
      'message', 'Payment failures in last 24 hours',
      'count', (SELECT count(*) FROM payment_transactions WHERE status = 'failed' AND created_at >= now() - interval '24 hours'),
      'action_route', '/admin/orders'
    );
  END IF;

  IF (SELECT count(*) FROM sanctions WHERE is_active = true) > 0 THEN
    v_alerts := v_alerts || jsonb_build_object(
      'type', 'active_sanctions', 'severity', 'info',
      'message', 'Active sanctions on platform',
      'count', (SELECT count(*) FROM sanctions WHERE is_active = true),
      'action_route', '/admin/sanctions'
    );
  END IF;

  RETURN jsonb_build_object('alerts', v_alerts, 'count', jsonb_array_length(v_alerts));
END;
$$;

-- ============================================================
-- 050.14: PLATFORM REVENUE OVERVIEW
-- Revenue by period with service breakdown
-- ============================================================

CREATE OR REPLACE FUNCTION public.platform_revenue_overview(
  p_period text DEFAULT 'all',
  p_service_category text DEFAULT NULL,
  p_from date DEFAULT NULL,
  p_to   date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_member_id uuid;
  v_has_revenue boolean;
  v_now timestamptz := now();
  v_from timestamptz;
  v_to   timestamptz;
BEGIN
  v_member_id := auth.uid();
  IF v_member_id IS NULL OR NOT has_permission('MEMBER_VIEW', v_member_id) THEN
    RETURN NULL;
  END IF;
  v_has_revenue := has_permission('PLATFORM_REVENUE', v_member_id);
  IF NOT v_has_revenue THEN
    RETURN jsonb_build_object('error', 'insufficient_permissions');
  END IF;

  -- Determine time range from period
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
    'total_gmv',      (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE status = 'completed' AND created_at >= v_from AND created_at <= v_to)
      + (SELECT COALESCE(SUM(fare), 0) FROM rides WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to)
      + (SELECT COALESCE(SUM(final_price), 0) FROM service_bookings WHERE status = 'completed' AND completed_at >= v_from AND completed_at <= v_to),
    'total_commission',(SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE created_at >= v_from AND created_at <= v_to),
    'commission_7pct', (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 7 AND created_at >= v_from AND created_at <= v_to),
    'commission_3pct', (SELECT COALESCE(SUM(commission_amount), 0) FROM platform_commissions WHERE commission_rate = 3 AND created_at >= v_from AND created_at <= v_to),
    'refund_count',    (SELECT count(*) FROM orders WHERE status = 'cancelled' AND created_at >= v_from AND created_at <= v_to),
    'period',          p_period,
    'date_from',       v_from,
    'date_to',         v_to
  );
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================

DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.proname as name,
           pg_get_function_identity_arguments(p.oid) as args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'platform_%'
      AND p.prokind = 'f'
  LOOP
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated', fn.name, fn.args);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO anon', fn.name, fn.args);
  END LOOP;
END $$;
