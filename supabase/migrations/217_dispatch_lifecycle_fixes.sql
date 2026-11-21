-- 217: order-lifecycle dispatch fixes (sim lab smoke test findings)
--
-- BUG 1: create_order_idempotent accepted no delivery coordinates, so
--   API-created orders had NULL delivery_latitude/longitude and dispatch
--   failed MISSING_DELIVERY_LOCATION while orders_guard_sensitive blocked
--   client patching. Adds p_delivery_latitude/p_delivery_longitude.
-- BUG 2: accept_order propagated the assignment to rides with
--   ride_type='delivery', a value rides_ride_type_check can never hold, so
--   the UPDATE matched 0 rows. Match on order_id + searching instead.
-- BUG 3: accept_ride_request wrote veh.make||' '||veh.model into
--   rides.vehicle_type, violating rides_delivery_vehicle_type_check (23514)
--   for any vehicle with make/model set. Write veh.category instead, which
--   shares the same CHECK enum.
-- Reconciliation: sync_linked_delivery_order now expires parallel
--   dispatch_order offers once the canonical ride path matches a driver.

-- BUG 1 ---------------------------------------------------------------------
DROP FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text);

CREATE FUNCTION public.create_order_idempotent(p_idempotency_key text, p_merchant_id uuid, p_merchant_name text, p_items jsonb, p_subtotal numeric, p_delivery_fee numeric, p_discount numeric, p_total numeric, p_delivery_address text, p_payment_method text, p_payment_status text, p_payment_provider text, p_payment_provider_order_id text, p_delivery_latitude numeric DEFAULT NULL::numeric, p_delivery_longitude numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_order_id uuid;
  v_existing_order uuid;
  v_coupon_id uuid;
  v_items jsonb;
  v_quantity int;
  v_unit_price numeric;
  v_total_price numeric;
  v_subtotal numeric;
  v_delivery_fee numeric;
  v_discount numeric;
  v_total numeric;
  v_is_service boolean;
  v_status text;
  v_item record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_idempotency_key IS NULL OR p_idempotency_key = '' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'MISSING_IDEMPOTENCY_KEY');
  END IF;
  v_is_service := (current_user = 'service_role' OR current_setting('request.jwt.claims', true) LIKE '%"role":"service_role"%');
  v_subtotal := COALESCE(p_subtotal, 0);
  v_delivery_fee := COALESCE(p_delivery_fee, 0);
  v_discount := COALESCE(p_discount, 0);
  IF v_subtotal < 0 OR v_delivery_fee < 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNTS');
  END IF;
  v_discount := LEAST(v_discount, v_subtotal + v_delivery_fee);
  IF v_discount < 0 THEN
    v_discount := 0;
  END IF;
  v_total := ROUND(v_subtotal + v_delivery_fee - v_discount, 2);
  IF v_total < 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_TOTAL');
  END IF;
  IF v_is_service THEN
    v_status := p_payment_status;
  ELSIF p_payment_status IN ('paid','refunded','failed') THEN
    RETURN jsonb_build_object('ok', false, 'code', 'PAYMENT_STATUS_FORBIDDEN');
  ELSE
    v_status := COALESCE(NULLIF(p_payment_status, ''), 'pending');
  END IF;

  -- Tolerant items: accept either a JSON array (direct callers) or a
  -- string-encoded array (the app's jsonEncode() call), then normalize keys.
  IF jsonb_typeof(p_items) = 'string' THEN
    BEGIN
      v_items := (p_items #>> '{}')::jsonb;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_ITEMS');
    END;
  ELSE
    v_items := p_items;
  END IF;
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_ITEMS');
  END IF;

  SELECT id INTO v_existing_order
    FROM public.orders
   WHERE idempotency_key = p_idempotency_key;
  IF v_existing_order IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_EXISTS', 'order_id', v_existing_order);
  END IF;

  v_coupon_id := NULLIF(COALESCE(v_items -> 0 ->> 'coupon_id', v_items -> 0 ->> 'couponId'), '')::uuid;

  -- Validate every line resolves a product + both prices (snake_case OR camelCase).
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_items) AS e(item) LOOP
    v_quantity := COALESCE((v_item.item ->> 'quantity')::int, 1);
    v_unit_price := COALESCE((v_item.item ->> 'unit_price')::numeric, (v_item.item ->> 'unitPrice')::numeric);
    v_total_price := COALESCE((v_item.item ->> 'total_price')::numeric, (v_item.item ->> 'totalPrice')::numeric);
    IF COALESCE(v_item.item ->> 'product_id', v_item.item ->> 'productId') IS NULL
       OR v_quantity <= 0 OR v_unit_price IS NULL OR v_total_price IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'INVALID_ITEMS');
    END IF;
  END LOOP;

  BEGIN
    INSERT INTO public.orders (
      user_id, merchant_id, merchant_name, items, subtotal, delivery_fee,
      discount, total_amount, delivery_address, delivery_latitude, delivery_longitude,
      payment_method, payment_status, payment_provider, payment_provider_order_id,
      idempotency_key, coupon_id
    ) VALUES (
      v_uid, p_merchant_id, p_merchant_name, v_items, v_subtotal, v_delivery_fee,
      v_discount, v_total, p_delivery_address, p_delivery_latitude, p_delivery_longitude,
      p_payment_method, v_status, p_payment_provider, p_payment_provider_order_id,
      p_idempotency_key, v_coupon_id
    ) RETURNING id INTO v_order_id;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT id INTO v_existing_order
        FROM public.orders WHERE idempotency_key = p_idempotency_key;
      IF v_existing_order IS NOT NULL THEN
        RETURN jsonb_build_object('ok', true, 'code', 'ALREADY_EXISTS', 'order_id', v_existing_order);
      END IF;
      RETURN jsonb_build_object('ok', false, 'code', 'CONFLICT');
  END;

  INSERT INTO public.order_items (order_id, product_id, quantity, unit_price, total_price, modifiers)
  SELECT
    v_order_id,
    COALESCE((item ->> 'product_id')::uuid, (item ->> 'productId')::uuid),
    COALESCE((item ->> 'quantity')::int, 1),
    COALESCE((item ->> 'unit_price')::numeric, (item ->> 'unitPrice')::numeric),
    COALESCE((item ->> 'total_price')::numeric, (item ->> 'totalPrice')::numeric),
    COALESCE(item -> 'modifiers', '[]'::jsonb)
  FROM jsonb_array_elements(v_items) AS item;

  RETURN jsonb_build_object('ok', true, 'code', 'CREATED', 'order_id', v_order_id, 'total_amount', v_total);
END;
$function$;



GRANT EXECUTE ON FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_order_idempotent(text,uuid,text,jsonb,numeric,numeric,numeric,numeric,text,text,text,text,text,numeric,numeric) TO service_role;

-- BUG 2 ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' OR v_order.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'STALE', 'dispatch_status', v_order.dispatch_status);
  END IF;
  -- Non-owner callers may only accept an offer actually pending for their driver.
  IF NOT public._is_owner_uid(auth.uid()) AND NOT EXISTS (
    SELECT 1 FROM public.order_dispatch
     WHERE order_id = p_order_id
       AND candidate_driver_id = p_driver_id
       AND status IN ('pending', 'offered')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NO_PENDING_OFFER');
  END IF;
  UPDATE public.orders
    SET driver_id = p_driver_id, dispatch_status = 'ASSIGNED', status = 'preparing'
    WHERE id = p_order_id;
  UPDATE public.order_dispatch
    SET status = 'accepted', candidate_driver_id = p_driver_id, updated_at = now()
    WHERE order_id = p_order_id;
  -- The driver app works off the delivery ride: hand it the same assignment.
  -- rides.ride_type is a vehicle class (motorcycle/tuk_tuk/tricycle/car per
  -- rides_ride_type_check), never 'delivery': match the order's live ride on
  -- order_id + searching only. The old ride_type predicate matched 0 rows and
  -- left the ride driverless while the order showed ASSIGNED.
  UPDATE public.rides
     SET driver_id = p_driver_id, status = 'matched', accepted_at = now()
   WHERE order_id = p_order_id
     AND status = 'searching';
  PERFORM public.log_admin_action('DISPATCH_ACCEPT', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', p_driver_id), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;



-- BUG 3 ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_ride_request(p_ride_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner UUID;
  v_status TEXT;
  v_req_status TEXT;
  v_expires timestamptz;
  v_otp TEXT;
  drv drivers%ROWTYPE;
  veh vehicles%ROWTYPE;
BEGIN
  SELECT * INTO drv FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
  IF auth.uid() IS NULL OR drv.user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF drv.location_updated_at IS NULL OR drv.location_updated_at <= now()-interval '2 minutes' THEN
    RETURN jsonb_build_object('success',false,'reason','stale_location');
  END IF;
  IF drv.is_verified IS DISTINCT FROM true OR drv.is_active IS DISTINCT FROM true
     OR drv.status IS DISTINCT FROM 'online' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_ineligible');
  END IF;
  -- Serialize by ride before offer rows, so competing acceptances do not
  -- deadlock while expiring one another's offers.
  SELECT status INTO v_status FROM public.rides WHERE id=p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_unavailable');
  END IF;
  IF EXISTS (SELECT 1 FROM rides WHERE driver_id = p_driver_id
             AND status IN ('matched','arrived','inTrip')) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'driver_busy');
  END IF;

  SELECT status, expires_at INTO v_req_status, v_expires FROM ride_requests
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id FOR UPDATE;
  IF v_req_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_offer');
  END IF;
  IF v_req_status = 'offered' AND (v_expires IS NULL OR v_expires <= now()) THEN
    UPDATE public.ride_requests SET status='expired', responded_at=now()
      WHERE ride_id=p_ride_id AND driver_id=p_driver_id;
    RETURN jsonb_build_object('success', false, 'reason', 'offer_expired');
  END IF;
  IF v_req_status <> 'offered' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'offer_' || v_req_status);
  END IF;

  IF v_status IS DISTINCT FROM 'searching' THEN
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND driver_id = p_driver_id;
    RETURN jsonb_build_object('success', false, 'reason', 'ride_unavailable');
  END IF;

  SELECT * INTO drv FROM drivers WHERE id = p_driver_id;
  SELECT * INTO veh FROM vehicles
    WHERE id=drv.active_vehicle_id AND driver_id=p_driver_id AND is_active=true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_active_vehicle');
  END IF;
  v_otp := lpad((floor(random() * 10000))::INT::TEXT, 4, '0');

  UPDATE rides SET
    driver_id = p_driver_id,
    driver_name = drv.full_name,
    driver_phone = drv.phone,
    vehicle_type = COALESCE(veh.category, drv.vehicle_type),
    vehicle_plate = COALESCE(veh.plate_number, drv.vehicle_plate),
    vehicle_color = COALESCE(veh.color, drv.vehicle_color),
    driver_latitude = drv.current_latitude,
    driver_longitude = drv.current_longitude,
    status = 'matched',
    matched_at = NOW(),
    accepted_at = NOW(),
    pickup_otp = v_otp
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'accepted', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id;
  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id <> p_driver_id AND status = 'offered';

  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'accepted', 'driver');
  -- NOTE: OTP intentionally NOT included in the driver-facing return payload.
  RETURN jsonb_build_object('success', true);
END;
$function$;



-- dispatch reconciliation ----------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_linked_delivery_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.order_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.status = 'matched' THEN
    UPDATE public.orders SET driver_id=NEW.driver_id, dispatch_status='ASSIGNED', updated_at=now()
      WHERE id=NEW.order_id AND status NOT IN ('cancelled','delivered');
    -- Canonical food dispatch runs through rides + ride_requests; once the
    -- ride is matched, any parallel dispatch_order offer for the same order
    -- is dead and must not linger as 'pending'.
    UPDATE public.order_dispatch SET status='expired', updated_at=now()
      WHERE order_id=NEW.order_id AND status IN ('pending','offered');
  ELSIF NEW.status = 'inTrip' THEN
    UPDATE public.orders SET status='delivering', dispatch_status='ACCEPTED', updated_at=now()
      WHERE id=NEW.order_id AND status NOT IN ('cancelled','delivered');
  ELSIF NEW.status = 'completed' THEN
    UPDATE public.orders SET status='delivered', dispatch_status='ACCEPTED', updated_at=now()
      WHERE id=NEW.order_id AND status <> 'cancelled';
  ELSIF NEW.status = 'cancelled' THEN
    UPDATE public.orders SET status='cancelled', updated_at=now()
      WHERE id=NEW.order_id AND status <> 'delivered';
  END IF;
  RETURN NEW;
END; $function$;

NOTIFY pgrst, 'reload schema';
