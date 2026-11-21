-- ============================================================
-- 151_orders_rides_update_lockdown.sql
-- Closes three holes:
--  1. orders: any customer could UPDATE every column of their
--     own order (payment_status, total_amount, status, ...).
--     The app never updates orders as a customer, so a guard
--     trigger now freezes all sensitive columns for non-admin
--     client roles. Merchant owners keep a narrow carve-out:
--     status/updated_at only, forward-only into kitchen states,
--     never 'delivered' or 'cancelled'.
--  2. Merchant "mark delivered" bypassed earnings recording.
--     New RPC merchant_complete_order records the merchant
--     commission (subtotal - 3%) idempotently, then marks the
--     order delivered. Ride-linked orders are refused (they
--     complete through the driver handoff path).
--  3. rides: a rider could UPDATE every column of their ride
--     (fare, payment_status, driver_id) and INSERT a ride that
--     is already 'paid'. All rides writes from non-admin client
--     roles are now frozen; inserts are forced back to
--     payment_status 'pending' and system defaults.
-- SECURITY DEFINER RPCs run as the table owner and are
-- unaffected, matching the users/drivers guard pattern.
-- ============================================================

-- ─── 1. orders guard trigger ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.orders_guard_sensitive()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_merchant_owner boolean;
BEGIN
  -- DEFINER RPCs and backend run as the table owner.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public._is_active_admin_uid(auth.uid()) THEN
    RETURN NEW;
  END IF;

  v_merchant_owner := public.is_merchant_owner(OLD.merchant_id);

  -- Columns no client may ever change directly.
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
     OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
     OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
     OR NEW.payment_id IS DISTINCT FROM OLD.payment_id
     OR NEW.payment_provider IS DISTINCT FROM OLD.payment_provider
     OR NEW.payment_provider_order_id IS DISTINCT FROM OLD.payment_provider_order_id
     OR NEW.payment_provider_transaction_id IS DISTINCT FROM OLD.payment_provider_transaction_id
     OR NEW.transaction_id IS DISTINCT FROM OLD.transaction_id
     OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
     OR NEW.subtotal IS DISTINCT FROM OLD.subtotal
     OR NEW.tax IS DISTINCT FROM OLD.tax
     OR NEW.discount IS DISTINCT FROM OLD.discount
     OR NEW.delivery_fee IS DISTINCT FROM OLD.delivery_fee
     OR NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.items IS DISTINCT FROM OLD.items
     OR NEW.coupon_id IS DISTINCT FROM OLD.coupon_id
     OR NEW.cash_collected_at IS DISTINCT FROM OLD.cash_collected_at
     OR NEW.cash_collected_by IS DISTINCT FROM OLD.cash_collected_by
     OR NEW.confirmed_at IS DISTINCT FROM OLD.confirmed_at
     OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
     OR NEW.cancelled_reason IS DISTINCT FROM OLD.cancelled_reason
     OR NEW.dispatch_status IS DISTINCT FROM OLD.dispatch_status
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'order financial and assignment fields are managed by the order RPCs';
  END IF;

  -- status: only the merchant owner may move it, forward-only
  -- through kitchen states. Delivery completion and cancellation
  -- go through RPCs that record earnings / incidents.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT v_merchant_owner THEN
      RAISE EXCEPTION 'order status is managed by the order RPCs';
    END IF;
    IF NEW.status NOT IN ('confirmed','preparing','ready','delivering') THEN
      RAISE EXCEPTION 'delivery completion must go through merchant_complete_order; cancellation through the incident flow';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_guard_sensitive ON public.orders;
CREATE TRIGGER trg_orders_guard_sensitive
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.orders_guard_sensitive();

-- ─── 2. merchant completion RPC with earnings recording ──────

CREATE OR REPLACE FUNCTION public.merchant_complete_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_order public.orders%ROWTYPE;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_rate numeric;
  v_commission numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF NOT public.is_merchant_owner(v_order.merchant_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;
  IF v_order.status = 'delivered' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_DONE');
  END IF;
  IF v_order.status NOT IN ('ready','delivering') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'BAD_STATE');
  END IF;
  -- Ride-linked orders complete through the driver handoff flow,
  -- which verifies the recipient OTP and records both legs.
  IF EXISTS (SELECT 1 FROM public.rides r WHERE r.order_id = p_order_id) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'USE_ASSIGNED_DELIVERY_FLOW');
  END IF;

  UPDATE public.orders
     SET status = 'delivered', updated_at = now()
   WHERE id = p_order_id;

  -- Merchant leg: subtotal minus the merchant commission rate.
  SELECT owner_user_id, type INTO v_merchant_uid, v_merchant_type
    FROM public.merchants WHERE id = v_order.merchant_id;
  v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 3);
  v_commission := public.calculate_commission(COALESCE(v_order.subtotal,0), v_rate);
  INSERT INTO public.platform_commissions(
      member_id, reference_type, reference_id, gross_amount, commission_rate,
      commission_amount, net_amount, currency, status)
  VALUES (
      v_merchant_uid, 'order', p_order_id, COALESCE(v_order.subtotal,0), v_rate,
      v_commission, COALESCE(v_order.subtotal,0) - v_commission,
      'EGP', 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.merchant_complete_order(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merchant_complete_order(uuid) TO authenticated;

-- ─── 3. rides guard: freeze client writes, sanitize inserts ──

CREATE OR REPLACE FUNCTION public.rides_guard_client_writes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public._is_active_admin_uid(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- No app flow updates rides directly as a client; every
    -- legitimate transition goes through a SECURITY DEFINER RPC.
    RAISE EXCEPTION 'ride fields are managed by the delivery RPCs';
  END IF;

  -- INSERT: a rider may request a ride, but never a pre-paid or
  -- pre-assigned one. Force money and assignment fields back to
  -- system defaults.
  NEW.payment_status := 'pending';
  NEW.status := 'searching';
  NEW.driver_id := NULL;
  NEW.driver_name := NULL;
  NEW.driver_phone := NULL;
  NEW.driver_photo := NULL;
  NEW.driver_latitude := NULL;
  NEW.driver_longitude := NULL;
  NEW.driver_heading := NULL;
  NEW.accepted_at := NULL;
  NEW.arrived_at := NULL;
  NEW.matched_at := NULL;
  NEW.started_at := NULL;
  NEW.picked_up_at := NULL;
  NEW.completed_at := NULL;
  NEW.delivered_at := NULL;
  NEW.cancelled_at := NULL;
  NEW.cancelled_by := NULL;
  NEW.cash_collected_at := NULL;
  NEW.cash_collected_by := NULL;
  NEW.rating := NULL;
  NEW.driver_rating := NULL;
  NEW.reassign_count := 0;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rides_guard_client_writes ON public.rides;
CREATE TRIGGER trg_rides_guard_client_writes
  BEFORE INSERT OR UPDATE ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.rides_guard_client_writes();
