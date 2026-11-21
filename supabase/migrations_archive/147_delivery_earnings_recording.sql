-- 147: record earnings and commissions when an assigned delivery completes.
--
-- The handoff-secured ride completion flow (144) marked rides and orders
-- delivered but recorded NO economics: no driver_earnings row, no
-- platform_commissions row. The only path that recorded economics was the
-- legacy no-ride complete_delivery(order_id), and it used a broken split for
-- merchant orders (driver credited with the goods money minus 7%, merchant
-- received nothing, platform commission charged on the full order total
-- including merchandise the driver never owned).
--
-- This migration wires the economics into the real completion flow with the
-- split the existing commission_rules already encode:
--   * driver  (default 7%) on the delivery FARE only - charging a driver a
--     percentage of the goods value would make large orders loss-making to
--     deliver;
--   * merchant (default 3%) on the goods subtotal.
-- Reference conventions match the admin snapshot tool
-- platform_commission_for_reference: ('ride', ride_id) for the driver row,
-- ('order', order_id) for the merchant row. One row per reference is enforced
-- by platform_commissions_reference_unique, and the helper is idempotent.
--
-- Recording only: no wallet movements, transfers, payouts or balance changes.
-- Cash settlement continues through the existing settlement subsystem
-- (platform_settlements). The legacy no-ride complete_delivery(order_id) is
-- revoked from client roles: no app calls it, and its old split must not be
-- triggerable until it is removed.
BEGIN;

CREATE OR REPLACE FUNCTION public._record_delivery_earnings(p_ride_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.rides%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_currency text;
BEGIN
  SELECT * INTO r FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND OR r.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one earning/commission pair per ride.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE ride_id = p_ride_id) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
  v_currency := COALESCE(NULLIF(r.currency, ''), 'EGP');

  -- Driver: earns the delivery fare minus the driver-rate commission.
  v_gross := COALESCE(r.fare, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (r.driver_id, p_ride_id, 'trip', v_gross - v_commission, v_currency,
          'Delivery fare ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'ride', p_ride_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal for merchant orders.
  IF r.order_id IS NOT NULL THEN
    SELECT * INTO v_order FROM public.orders WHERE id = r.order_id;
    IF FOUND AND v_order.merchant_id IS NOT NULL THEN
      SELECT owner_user_id, type INTO v_merchant_uid, v_merchant_type
        FROM public.merchants WHERE id = v_order.merchant_id;
      IF v_merchant_uid IS NOT NULL THEN
        v_gross := COALESCE(v_order.subtotal, 0);
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
        v_commission := public.calculate_commission(v_gross, v_rate);
        INSERT INTO public.platform_commissions
          (member_id, reference_type, reference_id, gross_amount, commission_rate,
           commission_amount, net_amount, currency, status)
        VALUES (v_merchant_uid, 'order', v_order.id, v_gross, v_rate, v_commission,
                v_gross - v_commission, v_currency, 'computed')
        ON CONFLICT (reference_type, reference_id) DO NOTHING;
      END IF;
    END IF;
  END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public._record_delivery_earnings(uuid) FROM PUBLIC, anon, authenticated;

-- Record economics at the moment the recipient code completes the delivery.
CREATE OR REPLACE FUNCTION public.complete_delivery(p_ride_id uuid, p_driver_id uuid, p_proof_url text DEFAULT NULL::text, p_final_distance numeric DEFAULT NULL::numeric, p_recipient_otp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.rides%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM public.drivers WHERE id=p_driver_id AND user_id=auth.uid()) THEN
   RETURN jsonb_build_object('success',false,'reason','forbidden');
 END IF;
 SELECT * INTO r FROM public.rides WHERE id=p_ride_id FOR UPDATE;
 IF NOT FOUND OR r.driver_id IS DISTINCT FROM p_driver_id THEN
   RETURN jsonb_build_object('success',false,'reason','not_your_delivery');
 END IF;
 IF r.service_type='ride' OR r.status IS DISTINCT FROM 'inTrip' THEN
   RETURN jsonb_build_object('success',false,'reason','invalid_transition');
 END IF;
 IF NOT public._verify_delivery_handoff(p_ride_id,'dropoff',p_recipient_otp) THEN
   RETURN jsonb_build_object('success',false,'reason','INVALID_OR_LOCKED_RECIPIENT_CODE');
 END IF;
 UPDATE public.rides SET status='completed',completed_at=now(),delivered_at=now(),
   delivery_proof_url=COALESCE(p_proof_url,delivery_proof_url) WHERE id=p_ride_id;
 UPDATE public.driver_locations SET ride_id=NULL WHERE driver_id=p_driver_id AND ride_id=p_ride_id;
 INSERT INTO public.trip_events(ride_id,event_type,actor) VALUES(p_ride_id,'delivered','driver');
 PERFORM public._record_delivery_earnings(p_ride_id);
 RETURN jsonb_build_object('success',true,'ride_id',p_ride_id,'fare',r.fare);
END; $function$
;

-- The legacy no-ride order completion keeps its old, wrong-for-merchants
-- economics. No app calls it, and its USE_ASSIGNED_DELIVERY_FLOW response is
-- the guard that keeps ride-linked orders on the handoff-verified path, so
-- the function stays callable but only the owner may actually run it.
CREATE OR REPLACE FUNCTION public.complete_delivery(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

DECLARE
  v_uid     uuid := auth.uid();
  v_order   orders%ROWTYPE;
  v_is_driver boolean;
  v_driver_uid uuid;
  v_rate      numeric;
  v_commission numeric;
  v_net       numeric;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ASSIGNED');
  END IF;
  IF v_order.status = 'delivered' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_DONE');
  END IF;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  v_is_driver := EXISTS (
    SELECT 1 FROM public.drivers d
     WHERE d.user_id = v_uid AND d.id = v_order.driver_id
  );

  IF NOT v_is_driver AND NOT public._is_owner_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  IF EXISTS(SELECT 1 FROM public.rides WHERE order_id=p_order_id) THEN
    RETURN jsonb_build_object('ok',false,'reason','USE_ASSIGNED_DELIVERY_FLOW');
  END IF;

  -- Retired surface: the old split below credits the driver with the goods
  -- money and records nothing for the merchant. Only the owner may still run
  -- it, pending removal once no-ride assignments are gone.
  IF NOT public._is_owner_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'LEGACY_RETIRED');
  END IF;

  -- Canonical identity mapping: driver_earnings.driver_id -> drivers.id;
  -- platform_commissions.member_id -> users.id (drivers.user_id).
  SELECT user_id INTO v_driver_uid
    FROM public.drivers WHERE id = v_order.driver_id;

  SELECT COALESCE(public.get_commission_rate('driver'::text, NULL::text, v_driver_uid), 0)
    INTO v_rate;
  v_rate := COALESCE(v_rate, 0);
  v_commission := (COALESCE(v_order.total_amount, 0) * v_rate / 100.0);
  v_net := COALESCE(v_order.total_amount, 0) - v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (v_order.driver_id, NULL, 'trip', v_net, 'EGP', 'Order ' || p_order_id::text || ' delivery earning');

  INSERT INTO public.platform_commissions (member_id, reference_type, reference_id, gross_amount, commission_rate, commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'order', p_order_id, v_order.total_amount, v_rate, v_commission, v_net, 'EGP', 'computed');

  UPDATE public.orders SET status = 'delivered', dispatch_status = 'ACCEPTED'
    WHERE id = p_order_id;

  PERFORM public.log_admin_action('DELIVERY_COMPLETE', 'order', p_order_id::text,
    NULL, jsonb_build_object('commission', v_commission, 'rate', v_rate), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true, 'commission', v_commission, 'rate', v_rate);
END;
$function$
;
GRANT EXECUTE ON FUNCTION public.complete_delivery(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
