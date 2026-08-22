-- 073_smart_delivery_dispatch_engine.sql
-- Additive. Smart Delivery Dispatch Engine for commerce orders.
-- Reuses: drivers, driver_locations, wallets, driver_earnings,
-- platform_commissions, commission_rules, get_commission_rate (065/066/050).
-- Does NOT duplicate the ride/order lifecycle; extends `orders` with a driver
-- link + a dispatch queue. All RPCs are SECURITY DEFINER + FOR UPDATE guarded.

-- 1) Reconcile orders.status CHECK with Flutter enums (was rejecting
--    picked_up / in_transit). Additive second check constraint.
ALTER TABLE public.orders
  ADD CONSTRAINT orders_status_delivery_check
  CHECK (status IN (
    'pending','confirmed','preparing','ready',
    'picked_up','in_transit','delivering','delivered','cancelled'
  ));

-- 2) Driver link on orders (was a bare UUID with no FK / no assignment RPC).
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS driver_id uuid;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS dispatch_status text
  DEFAULT 'PENDING_DISPATCH'
  CHECK (dispatch_status IN (
    'PENDING_DISPATCH','OFFERED','ASSIGNED','ACCEPTED','EXPIRED','DECLINED','RETURNED'
  ));
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_driver_id_fkey'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_driver_id_fkey
      FOREIGN KEY (driver_id) REFERENCES public.drivers(id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_orders_driver_id ON public.orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_dispatch_status ON public.orders(dispatch_status);

-- Distance helper (great-circle km).
CREATE OR REPLACE FUNCTION public.driver_distance_km(
  p_pickup_lat double precision, p_pickup_lng double precision,
  p_driver_lat double precision, p_driver_lng double precision
)
RETURNS double precision
LANGUAGE sql IMMUTABLE
AS $$
  SELECT 6371 * acos(
    least(1.0, greatest(-1.0,
      cos(radians(p_pickup_lat)) * cos(radians(p_driver_lat)) *
      cos(radians(p_driver_lng) - radians(p_pickup_lng)) +
      sin(radians(p_pickup_lat)) * sin(radians(p_driver_lat))
    ))
  );
$$;

-- 3) Dispatch queue (mirrors ride_requests pattern).
CREATE TABLE IF NOT EXISTS public.order_dispatch (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id),
  candidate_driver_id uuid REFERENCES public.drivers(id),
  score double precision,
  snapshot jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','offered','accepted','expired','declined','returned')),
  region_id uuid,
  assigned_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  UNIQUE (order_id)
);
CREATE INDEX IF NOT EXISTS idx_order_dispatch_status ON public.order_dispatch(status);
CREATE INDEX IF NOT EXISTS idx_order_dispatch_driver ON public.order_dispatch(candidate_driver_id);

-- 4) Dispatch configuration center (global row + optional per-region rows).
CREATE TABLE IF NOT EXISTS public.dispatch_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id uuid,
  auto_dispatch boolean NOT NULL DEFAULT false,
  mode text NOT NULL DEFAULT 'smart' CHECK (mode IN ('smart','nearest','hybrid','manual')),
  max_distance_km int NOT NULL DEFAULT 15,
  max_concurrent_orders int NOT NULL DEFAULT 3,
  retry_interval_sec int NOT NULL DEFAULT 30,
  max_retries int NOT NULL DEFAULT 5,
  sla_priority int NOT NULL DEFAULT 1,
  region_enabled boolean NOT NULL DEFAULT false,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (region_id)
);
INSERT INTO public.dispatch_config (region_id, auto_dispatch, mode)
VALUES (NULL, false, 'smart')
ON CONFLICT (region_id) DO NOTHING;

-- 5) AUTO SMART DISPATCH: evaluate + select best available driver atomically.
CREATE OR REPLACE FUNCTION public.dispatch_order(p_order_id uuid, p_region_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_best uuid;
  v_score numeric;
  v_cfg dispatch_config%ROWTYPE;
  v_cat text;
BEGIN
  SELECT * INTO v_cfg FROM public.dispatch_config WHERE region_id IS NOT DISTINCT FROM p_region_id;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_PENDING', 'dispatch_status', v_order.dispatch_status);
  END IF;
  v_cat := COALESCE(v_order.service_type, 'food');

  SELECT driver_id, score INTO v_best, v_score
  FROM (
    SELECT d.user_id AS driver_id,
      (1.0 / (1.0 + public.driver_distance_km(
        v_order.pickup_latitude, v_order.pickup_longitude,
        dl.latitude, dl.longitude))) AS score
    FROM public.drivers d
    JOIN public.driver_locations dl ON dl.driver_id = d.user_id
    WHERE d.is_online
      AND d.is_verified
      AND d.accepts_deliveries
      AND (d.max_delivery_distance_km IS NULL OR
           public.driver_distance_km(v_order.pickup_latitude, v_order.pickup_longitude, dl.latitude, dl.longitude)
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
$$;
REVOKE ALL ON FUNCTION public.dispatch_order(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.dispatch_order(uuid, uuid) TO authenticated, service_role;

-- 6) ATOMIC ASSIGNMENT (PENDING_DISPATCH -> ASSIGNED). Single success guard.
CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid, p_driver_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' OR v_order.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'STALE', 'dispatch_status', v_order.dispatch_status);
  END IF;
  UPDATE public.orders
    SET driver_id = p_driver_id, dispatch_status = 'ASSIGNED', status = 'preparing'
    WHERE id = p_order_id;
  UPDATE public.order_dispatch
    SET status = 'accepted', candidate_driver_id = p_driver_id, updated_at = now()
    WHERE order_id = p_order_id;
  PERFORM public.log_admin_action('DISPATCH_ACCEPT', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', p_driver_id), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$$;
REVOKE ALL ON FUNCTION public.accept_order(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_order(uuid, uuid) TO authenticated, service_role;

-- 7) Decline / return to queue (manual or auto no-driver escalation).
CREATE OR REPLACE FUNCTION public.decline_order(p_order_id uuid, p_driver_id uuid, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.order_dispatch
    SET status = 'declined', updated_at = now()
    WHERE order_id = p_order_id AND candidate_driver_id = p_driver_id;
  UPDATE public.orders SET dispatch_status = 'PENDING_DISPATCH', driver_id = NULL
    WHERE id = p_order_id AND driver_id = p_driver_id;
  PERFORM public.log_admin_action('DISPATCH_DECLINE', 'order', p_order_id::text,
    jsonb_build_object('driver', p_driver_id), NULL, p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$$;
REVOKE ALL ON FUNCTION public.decline_order(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decline_order(uuid, uuid, text) TO authenticated, service_role;

-- 8) MANUAL / HYBRID assignment by authorized ops admin.
CREATE OR REPLACE FUNCTION public.assign_order_manual(
  p_order_id uuid, p_driver_id uuid, p_admin_id uuid DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  IF NOT (public._is_owner_uid(auth.uid())
          OR public.admin_has_permission('DISPATCH_MANUAL', NULL)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' OR v_order.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'STALE');
  END IF;
  UPDATE public.orders
    SET driver_id = p_driver_id, dispatch_status = 'ASSIGNED', status = 'preparing'
    WHERE id = p_order_id;
  UPDATE public.order_dispatch
    SET status = 'accepted', candidate_driver_id = p_driver_id, assigned_by = p_admin_id, updated_at = now()
    WHERE order_id = p_order_id;
  PERFORM public.log_admin_action('DISPATCH_MANUAL', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', p_driver_id), p_reason, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$$;
REVOKE ALL ON FUNCTION public.assign_order_manual(uuid, uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_order_manual(uuid, uuid, uuid, text) TO authenticated, service_role;

-- 9) Completion credits driver earnings + platform commission (no duplicate ledger).
CREATE OR REPLACE FUNCTION public.complete_delivery(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_rate numeric;
  v_commission numeric;
  v_net numeric;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ASSIGNED');
  END IF;
  SELECT rate INTO v_rate FROM public.get_commission_rate(
    v_order.account_id, v_order.merchant_id, v_order.service_type
  );
  v_rate := COALESCE(v_rate, 0);
  v_commission := (COALESCE(v_order.total, 0) * v_rate / 100.0);
  v_net := COALESCE(v_order.total, 0) - v_commission;

  INSERT INTO public.driver_earnings (driver_id, order_id, amount, commission)
  VALUES (v_order.driver_id, p_order_id, v_net, v_commission)
  ON CONFLICT (order_id) DO UPDATE SET amount = EXCLUDED.amount, commission = EXCLUDED.commission;

  INSERT INTO public.platform_commissions (order_id, account_id, merchant_id, amount, rate, created_at)
  VALUES (p_order_id, v_order.account_id, v_order.merchant_id, v_commission, v_rate, now());

  UPDATE public.orders SET status = 'delivered', dispatch_status = 'ACCEPTED'
    WHERE id = p_order_id;

  PERFORM public.log_admin_action('DELIVERY_COMPLETE', 'order', p_order_id::text,
    NULL, jsonb_build_object('commission', v_commission, 'rate', v_rate), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true, 'commission', v_commission, 'rate', v_rate);
END;
$$;
REVOKE ALL ON FUNCTION public.complete_delivery(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_delivery(uuid) TO authenticated, service_role;

-- 10) Tighten delivery location privacy: only self / owner / authorized admins
--     (DELIVERY_LOCATION_VIEW) may read all; customers/providers limited to their
--     own active delivery agent.
DROP POLICY IF EXISTS driver_locations_select ON public.driver_locations;
CREATE POLICY driver_locations_select ON public.driver_locations
  FOR SELECT USING (
    driver_id = auth.uid()
    OR public._is_owner_uid(auth.uid())
    OR public.admin_has_permission('DELIVERY_LOCATION_VIEW', NULL)
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.driver_id = driver_locations.driver_id
        AND o.dispatch_status IN ('ASSIGNED','ACCEPTED')
        AND (o.customer_user_id = auth.uid() OR o.merchant_id IN (
          SELECT id FROM public.merchants WHERE owner_user_id = auth.uid()
        ))
    )
  );
