-- MIGRATION 052: Commission Management + Approval Center fixes (STEP 18)
--
-- Fixes discovered during the STEP 18 feature audit:
--   A. decide_approval_request was REGRESSED by migration 040 to a
--      campaign-only implementation (it hard-rejects every other request
--      type). As a result member_delete, member_ban, admin_* and
--      reward_config_change approvals could be submitted but NEVER decided —
--      breaking the entire member-deletion and admin-lifecycle approval flow.
--      Restore the full dispatcher (decider guards from 034 + the single
--      _approval_apply path that 045 already finalizes for every type).
--
--   B. Migration 050 analytics hardcoded 7%/3% (`commission_rate = 7/3`)
--      instead of reading commission_rules. If a rate changes, historical
--      commission falls out of both buckets. Derive buckets from the ACTIVE
--      commission_rules via a shared helper.
--
--   C. get_admin_analytics (029) had NO authorization gate and was NOT
--      SECURITY DEFINER — any authenticated user could read aggregate
--      platform figures. Harden it (is_admin() + SECURITY DEFINER +
--      pinned search_path). It is still used by the Admin analytics page.
--
--   D. Commission Management Center: add the admin write RPC
--      set_commission_rate (versioned, immutable history, PLATFORM_REVENUE
--      gate, audit trail) + list_commission_rules (admin read). This is the
--      ONLY write path for commission_rules (client code never touches the
--      table directly — RLS remains fully closed).
--
-- All functions follow the 016/051 posture: SECURITY DEFINER,
-- search_path = public, pg_temp, gates inside, authenticated-only grants.

-- ════════════════════════════════════════════════════════════════════════
-- D. Commission Management
-- ════════════════════════════════════════════════════════════════════════

-- get_commission_rate: switch to pure effective-date semantics so a
-- scheduled (future-dated) rule activates automatically on its effective
-- date without a background job. Most specific rule still wins:
-- service_category > account_type.
CREATE OR REPLACE FUNCTION public.get_commission_rate(
  p_account_type text,
  p_service_category text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rate numeric;
BEGIN
  IF p_service_category IS NOT NULL THEN
    SELECT c.rate INTO v_rate
      FROM public.commission_rules c
     WHERE c.entity_type = 'service_category'
       AND c.entity_key = p_service_category
       AND c.effective_from <= CURRENT_DATE
       AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
     ORDER BY c.effective_from DESC, c.created_at DESC
     LIMIT 1;
    IF v_rate IS NOT NULL THEN
      RETURN v_rate;
    END IF;
  END IF;
  SELECT c.rate INTO v_rate
    FROM public.commission_rules c
   WHERE c.entity_type = 'account_type'
     AND c.entity_key = COALESCE(p_account_type, 'customer')
     AND c.effective_from <= CURRENT_DATE
     AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
   ORDER BY c.effective_from DESC, c.created_at DESC
   LIMIT 1;
  RETURN v_rate;
END;
$$;

-- Admin write path for commission_rules (D). Versioned, never mutates
-- history: the current active rule is deactivated (effective_to closed at
-- the new effective date) and a new rule row is inserted. Future-dated rules
-- are inserted inactive and activate automatically via get_commission_rate
-- once their effective date arrives.
CREATE OR REPLACE FUNCTION public.set_commission_rate(
  p_entity_type text,
  p_entity_key text,
  p_rate numeric,
  p_effective_from date DEFAULT CURRENT_DATE,
  p_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
  v_current_id uuid;
  v_current_from date;
  v_old_to date;
BEGIN
  IF NOT public.has_permission('PLATFORM_REVENUE', NULL) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_entity_type NOT IN ('account_type', 'service_type', 'service_category') THEN
    RAISE EXCEPTION 'Invalid entity type';
  END IF;
  IF p_entity_key IS NULL OR btrim(p_entity_key) = '' THEN
    RAISE EXCEPTION 'Entity key is required';
  END IF;
  IF p_rate IS NULL OR p_rate < 0 OR p_rate > 100 THEN
    RAISE EXCEPTION 'Rate must be between 0 and 100';
  END IF;
  p_effective_from := COALESCE(p_effective_from, CURRENT_DATE);

  SELECT c.id, c.effective_from INTO v_current_id, v_current_from
    FROM public.commission_rules c
   WHERE c.entity_type = p_entity_type
     AND c.entity_key = p_entity_key
     AND c.is_active
   ORDER BY c.effective_from DESC, c.created_at DESC
   LIMIT 1;

  IF v_current_id IS NOT NULL THEN
    v_old_to := GREATEST(v_current_from, p_effective_from);
    UPDATE public.commission_rules
       SET is_active = false,
           effective_to = v_old_to,
           updated_at = now()
     WHERE id = v_current_id;
  END IF;

  INSERT INTO public.commission_rules
    (entity_type, entity_key, rate, currency, effective_from,
     is_active, description, created_by, approved_by)
  VALUES (
    p_entity_type, p_entity_key, p_rate, 'SAR', p_effective_from,
    p_effective_from <= CURRENT_DATE,
    p_description, auth.uid(), auth.uid()
  )
  RETURNING id INTO v_new_id;

  PERFORM public.write_audit(
    'COMMISSION_RATE_CHANGED', 'commission_rules', v_new_id::text,
    jsonb_build_object('entity_type', p_entity_type,
                       'entity_key', p_entity_key,
                       'rate', p_rate,
                       'effective_from', p_effective_from,
                       'description', p_description));

  RETURN v_new_id;
END;
$$;

-- Admin read path for commission rules (active + history). NULL when the
-- caller lacks PLATFORM_REVENUE (mirrors the 050 platform_* pattern).
CREATE OR REPLACE FUNCTION public.list_commission_rules(
  p_entity_type text DEFAULT NULL,
  p_only_active boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rules jsonb;
BEGIN
  IF NOT public.has_permission('PLATFORM_REVENUE', NULL) THEN
    RETURN NULL;
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', c.id::text,
           'entity_type', c.entity_type,
           'entity_key', c.entity_key,
           'rate', c.rate,
           'currency', c.currency,
           'effective_from', c.effective_from,
           'effective_to', c.effective_to,
           'is_active', c.is_active,
           'description', c.description,
           'created_at', c.created_at,
           'updated_at', c.updated_at)
         ORDER BY c.effective_from DESC, c.created_at DESC),
         '[]'::jsonb)
    INTO v_rules
    FROM public.commission_rules c
   WHERE (p_entity_type IS NULL OR c.entity_type = p_entity_type)
     AND (NOT p_only_active OR c.is_active);
  RETURN jsonb_build_object('rules', v_rules);
END;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- B. 050 analytics: derive 7%/3% buckets from commission_rules
-- ════════════════════════════════════════════════════════════════════════

-- Shared bucket helper: returns the commission amount earned at the ACTIVE
-- provider (or merchant) rate within [p_from, p_to]. Falls back to the
-- canonical 7%/3% when no rule is configured.
CREATE OR REPLACE FUNCTION public._commission_bucket_amount(
  p_from timestamptz,
  p_to timestamptz,
  p_bucket text
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rate numeric;
  v_key text;
BEGIN
  IF p_bucket = 'merchant' THEN
    v_key := 'merchant';
  ELSE
    v_key := 'provider';
  END IF;
  SELECT c.rate INTO v_rate
    FROM public.commission_rules c
   WHERE c.entity_type = 'account_type'
     AND c.entity_key = v_key
     AND c.effective_from <= CURRENT_DATE
     AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
   ORDER BY c.effective_from DESC, c.created_at DESC
   LIMIT 1;
  v_rate := COALESCE(v_rate, CASE WHEN p_bucket = 'merchant' THEN 3 ELSE 7 END);
  RETURN (SELECT COALESCE(SUM(pc.commission_amount), 0)
            FROM public.platform_commissions pc
           WHERE pc.commission_rate = v_rate
             AND pc.created_at >= p_from
             AND pc.created_at <= p_to);
END;
$$;

-- 050.1 PLATFORM KPI SUMMARY (recreated with rule-derived buckets)
CREATE OR REPLACE FUNCTION public.platform_kpi_summary(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
      SELECT COALESCE(jsonb_agg(jsonb_build_object('type', t, 'count', c)), '[]'::jsonb)
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
      public._commission_bucket_amount(v_from, v_to, 'provider')
    ELSE 0 END,
    'commission_3pct',     CASE WHEN v_has_revenue THEN
      public._commission_bucket_amount(v_from, v_to, 'merchant')
    ELSE 0 END,

    -- Risk
    'open_complaints',     (SELECT count(*) FROM complaints WHERE status NOT IN ('resolved','closed')),
    'escalated_complaints', (SELECT count(*) FROM complaints WHERE escalated_at IS NOT NULL AND status NOT IN ('resolved','closed')),
    'active_sanctions',    (SELECT count(*) FROM sanctions WHERE is_active = true),
    'sos_active',          (SELECT count(*) FROM sos_alerts WHERE status = 'active'),
    'pending_withdrawals', (SELECT count(*) FROM withdrawal_requests WHERE status = 'pending'),
    'payment_failures',    (SELECT count(*) FROM payment_transactions WHERE status = 'failed' AND created_at >= v_from AND created_at <= v_to),

    -- Period
    'date_from', v_from,
    'date_to',   v_to
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 050.3 PLATFORM REVENUE BREAKDOWN (rule-derived buckets)
CREATE OR REPLACE FUNCTION public.platform_revenue_breakdown(
  p_from timestamptz DEFAULT NULL,
  p_to   timestamptz DEFAULT NULL,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
    'commission_7pct',      public._commission_bucket_amount(v_from, v_to, 'provider'),
    'commission_3pct',      public._commission_bucket_amount(v_from, v_to, 'merchant'),
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

-- 050.14 PLATFORM REVENUE OVERVIEW (rule-derived buckets)
CREATE OR REPLACE FUNCTION public.platform_revenue_overview(
  p_period text DEFAULT 'all',
  p_service_category text DEFAULT NULL,
  p_from date DEFAULT NULL,
  p_to   date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
    'commission_7pct', public._commission_bucket_amount(v_from, v_to, 'provider'),
    'commission_3pct', public._commission_bucket_amount(v_from, v_to, 'merchant'),
    'refund_count',    (SELECT count(*) FROM orders WHERE status = 'cancelled' AND created_at >= v_from AND created_at <= v_to),
    'period',          p_period,
    'date_from',       v_from,
    'date_to',         v_to
  );
END;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- C. get_admin_analytics authz hardening
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_admin_analytics(
  date_from TIMESTAMPTZ DEFAULT NULL,
  date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_from TIMESTAMPTZ := COALESCE(date_from, NOW() - INTERVAL '30 days');
  v_to TIMESTAMPTZ := COALESCE(date_to, NOW());
  v_orders BIGINT;
  v_revenue NUMERIC;
  v_users BIGINT;
  v_drivers BIGINT;
  v_merchants BIGINT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT COUNT(*) INTO v_orders FROM public.rides WHERE created_at BETWEEN v_from AND v_to;
  SELECT COALESCE(SUM(fare), 0) INTO v_revenue FROM public.rides
    WHERE status = 'completed' AND created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_users FROM public.users WHERE created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_drivers FROM public.drivers WHERE created_at BETWEEN v_from AND v_to;
  SELECT COUNT(*) INTO v_merchants FROM public.merchants WHERE created_at BETWEEN v_from AND v_to;

  RETURN jsonb_build_object(
    'total_orders', v_orders,
    'total_revenue', v_revenue,
    'total_users', v_users,
    'total_drivers', v_drivers,
    'total_merchants', v_merchants
  );
END;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- A. decide_approval_request — restore the full dispatcher
-- ════════════════════════════════════════════════════════════════════════
-- Migration 040 replaced the 034 dispatcher with a campaign-only body that
-- hard-rejects every other request type. Recreate the full dispatcher here:
-- decider-authority guards (034) + single _approval_apply path (034/045
-- covers campaign_approve, admin_*, member_ban, member_delete and
-- reward_config_change).
CREATE OR REPLACE FUNCTION public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.approval_requests%ROWTYPE;
  v_is_owner boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_decision NOT IN ('approve','reject') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  SELECT * INTO v_request FROM public.approval_requests a WHERE a.id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approval request not found';
  END IF;
  IF v_request.state <> 'pending' THEN
    RAISE EXCEPTION 'Approval request already decided';
  END IF;
  IF v_request.request_type <> 'campaign_approve'
     AND NOT public._valid_approval_type(v_request.request_type) THEN
    RAISE EXCEPTION 'Unsupported request type';
  END IF;

  SELECT public._is_owner_uid(auth.uid()) INTO v_is_owner;

  IF v_request.requested_by = auth.uid() AND NOT v_is_owner THEN
    RAISE EXCEPTION 'Cannot decide your own request';
  END IF;

  IF NOT v_is_owner THEN
    IF v_request.required_approver IS NULL THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
    IF v_request.required_approver <> auth.uid()
       AND NOT public.is_supervisor_of(auth.uid(), v_request.requested_by) THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
  END IF;

  IF p_decision = 'reject'
     AND (p_reason IS NULL OR btrim(p_reason) = '') THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  IF p_decision = 'approve' THEN
    PERFORM public._approval_apply(v_request, p_reason);
    UPDATE public.approval_requests
      SET state = 'approved', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  ELSE
    UPDATE public.approval_requests
      SET state = 'rejected', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    v_request.requested_by,
    CASE WHEN p_decision = 'approve' THEN 'Approval granted' ELSE 'Approval rejected' END,
    v_request.request_type || ' — ' || COALESCE(p_reason, ''),
    'approval',
    jsonb_build_object('request_id', p_request_id::text,
                       'decision', p_decision,
                       'request_type', v_request.request_type),
    '/admin/approvals',
    'approval-decide-' || p_request_id::text
  );

  PERFORM public.write_audit(
    'APPROVAL_DECIDED', 'approval_requests', p_request_id::text,
    jsonb_build_object('decision', p_decision,
                       'request_type', v_request.request_type,
                       'reason', p_reason));
END;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- ACL CLOSES
-- ════════════════════════════════════════════════════════════════════════

-- Internal helper: service_role ONLY (never callable by the app).
REVOKE ALL ON FUNCTION public._commission_bucket_amount(timestamptz, timestamptz, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._commission_bucket_amount(timestamptz, timestamptz, text) FROM anon;
REVOKE ALL ON FUNCTION public._commission_bucket_amount(timestamptz, timestamptz, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._commission_bucket_amount(timestamptz, timestamptz, text) TO service_role;

-- Commission Management admin RPCs: authenticated (gates inside).
REVOKE ALL ON FUNCTION public.set_commission_rate(text, text, numeric, date, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_commission_rate(text, text, numeric, date, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_commission_rate(text, text, numeric, date, text) TO authenticated;

REVOKE ALL ON FUNCTION public.list_commission_rules(text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_commission_rules(text, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.list_commission_rules(text, boolean) TO authenticated;

-- get_admin_analytics: authenticated only (now properly gated inside).
REVOKE ALL ON FUNCTION public.get_admin_analytics(timestamptz, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_analytics(timestamptz, timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_admin_analytics(timestamptz, timestamptz) TO authenticated;

-- decide_approval_request: authenticated only (gates inside).
REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text) TO authenticated;
