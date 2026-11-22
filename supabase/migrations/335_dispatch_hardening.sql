-- 335 (reviewer batch 16): dispatch hardening.
-- #1 merchant_dispatch_order_driver double-fire: a re-tap while offers are
--    live returned a second dispatch wave; now it reports the pending
--    offers instead (idempotent), and a unique partial index makes a
--    second active ride per order impossible even under races that slip
--    past the order row lock.
-- #4 a driver coming online after a failed dispatch waited for the
--    2-minute cron sweep; driver_set_online_state now re-offers nearby
--    stuck rides immediately (the internal dispatcher still applies every
--    eligibility filter).

CREATE UNIQUE INDEX IF NOT EXISTS rides_one_active_delivery_per_order
  ON public.rides (order_id)
  WHERE order_id IS NOT NULL
    AND status IN ('searching', 'matched', 'arrived', 'inTrip');

CREATE OR REPLACE FUNCTION public.merchant_dispatch_order_driver(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_order record;
  v_merchant record;
  v_customer record;
  v_ride_id uuid;
  v_pickup_lat double precision;
  v_pickup_lng double precision;
  v_dropoff_lat double precision;
  v_dropoff_lng double precision;
  v_items_summary text;
  v_dispatch jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_order
    FROM public.orders
   WHERE id = p_order_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT public.is_merchant_owner(v_order.merchant_id) THEN
    RAISE EXCEPTION 'Not authorized to dispatch this order';
  END IF;

  SELECT * INTO v_merchant
    FROM public.merchants
   WHERE id = v_order.merchant_id;

  SELECT full_name, phone INTO v_customer
    FROM public.users
   WHERE id = v_order.user_id;

  SELECT string_agg(
           COALESCE(oi.quantity::text, '1') || 'x ' || COALESCE(NULLIF(oi.product_name, ''), 'Item'),
           ', '
         )
    INTO v_items_summary
    FROM public.order_items oi
   WHERE oi.order_id = p_order_id;

  IF v_order.status IN ('delivered','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ORDER_STATE');
  END IF;
  IF v_merchant.latitude IS NULL OR v_merchant.longitude IS NULL
     OR v_order.delivery_latitude IS NULL OR v_order.delivery_longitude IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'MISSING_DELIVERY_LOCATION');
  END IF;
  v_pickup_lat := v_merchant.latitude;
  v_pickup_lng := v_merchant.longitude;
  v_dropoff_lat := v_order.delivery_latitude;
  v_dropoff_lng := v_order.delivery_longitude;

  -- A delivery ride is unique per order.
  SELECT id INTO v_ride_id
    FROM public.rides
   WHERE order_id = p_order_id
     AND status IN ('searching', 'matched', 'arrived', 'inTrip')
   ORDER BY created_at DESC
   LIMIT 1;

  IF v_ride_id IS NULL THEN
    INSERT INTO public.rides (
      rider_id,
      merchant_id,
      order_id,
      service_type,
      ride_type,
      status,
      delivery_status,
      pickup_address,
      pickup_latitude,
      pickup_longitude,
      dropoff_address,
      dropoff_latitude,
      dropoff_longitude,
      fare,
      distance,
      estimated_minutes,
      payment_method,
      payment_status,
      currency,
      recipient_name,
      recipient_phone,
      items_summary,
      pickup_notes,
      dropoff_notes,
      otp_required
    )
    VALUES (
      v_order.user_id,
      v_order.merchant_id,
      p_order_id,
      'food_delivery',
      'motorcycle',
      'searching',
      'searching',
      COALESCE(NULLIF(v_merchant.address, ''), COALESCE(v_merchant.name, 'Store Pickup')),
      v_pickup_lat,
      v_pickup_lng,
      COALESCE(NULLIF(v_order.delivery_address, ''), 'Customer Address'),
      v_dropoff_lat,
      v_dropoff_lng,
      GREATEST(COALESCE(v_order.delivery_fee, v_merchant.delivery_fee, 20), 15),
      3.5,
      COALESCE(v_merchant.delivery_time_min, 30),
      COALESCE(v_order.payment_method, 'cash'),
      COALESCE(v_order.payment_status, 'pending'),
      'EGP',
      v_customer.full_name,
      v_customer.phone,
      COALESCE(v_items_summary, v_order.notes),
      v_merchant.name,
      COALESCE(v_order.notes, v_order.special_instructions),
      false
    )
    RETURNING id INTO v_ride_id;
  END IF;

  IF EXISTS (SELECT 1 FROM public.rides WHERE id=v_ride_id AND status <> 'searching') THEN
    RETURN jsonb_build_object('ok', true, 'order_id', p_order_id,
      'ride_id', v_ride_id, 'reason', 'ALREADY_ASSIGNED');
  END IF;
  -- Reviewer batch 16 #1: a re-tap while offers are still live must not
  -- fire a second dispatch wave; report the pending offers instead.
  IF EXISTS (SELECT 1 FROM public.ride_requests rr
              WHERE rr.ride_id = v_ride_id
                AND rr.status = 'offered'
                AND rr.expires_at > now()) THEN
    RETURN jsonb_build_object(
      'ok', true, 'order_id', p_order_id, 'ride_id', v_ride_id,
      'dispatch', jsonb_build_object('success', true, 'offered_to', 0,
                                     'reason', 'offers_pending'),
      'dispatch_status', 'OFFERED', 'reason', 'ALREADY_DISPATCHED');
  END IF;
  v_dispatch := public.dispatch_delivery(v_ride_id, 25.0, 15);
  IF COALESCE((v_dispatch->>'success')::boolean, false) = false
     AND v_dispatch->>'reason' <> 'no_drivers_available' THEN
    RAISE EXCEPTION 'Dispatch failed: %', v_dispatch->>'reason';
  END IF;

  UPDATE public.orders
     SET dispatch_status = CASE WHEN (v_dispatch->>'success')::boolean THEN 'OFFERED' ELSE 'PENDING_DISPATCH' END,
         status = CASE
           WHEN status IN ('pending', 'confirmed', 'accepted', 'preparing') THEN 'ready'
           ELSE status
         END,
         updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'dispatch', v_dispatch,
    'ok', true,
    'order_id', p_order_id,
    'ride_id', v_ride_id,
    'dispatch_status', CASE WHEN (v_dispatch->>'success')::boolean THEN 'OFFERED' ELSE 'PENDING_DISPATCH' END
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.driver_set_online_state(p_online boolean, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_driver_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_vehicle uuid;
  v_stuck record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id INTO v_driver
    FROM public.drivers
   WHERE user_id = v_uid
   ORDER BY created_at
   LIMIT 1
   FOR UPDATE;

  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'Driver profile not found';
  END IF;

  IF p_driver_id IS NOT NULL AND p_driver_id <> v_driver THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF p_online THEN
    IF p_lat IS NULL OR p_lng IS NULL OR p_lat NOT BETWEEN -90 AND 90 OR p_lng NOT BETWEEN -180 AND 180 THEN
      RETURN jsonb_build_object('ok',false,'reason','FRESH_LOCATION_REQUIRED');
    END IF;
    IF NOT EXISTS(SELECT 1 FROM drivers WHERE id=v_driver AND is_verified AND is_active) THEN
      RETURN jsonb_build_object('ok',false,'reason','DRIVER_NOT_VERIFIED');
    END IF;
    IF NOT EXISTS(SELECT 1 FROM vehicles WHERE driver_id=v_driver AND is_active) THEN
      RETURN jsonb_build_object('ok',false,'reason','ACTIVE_VEHICLE_REQUIRED');
    END IF;
  END IF;
  -- Adopt the driver's active vehicle so dispatch_delivery's
  -- `active_vehicle_id IS NOT NULL` precondition can be satisfied.
  SELECT id INTO v_vehicle
    FROM public.vehicles
   WHERE driver_id = v_driver
     AND is_active = true
   ORDER BY created_at
   LIMIT 1;

  UPDATE public.drivers
     SET is_online = p_online,
         -- status and is_online are two views of the same fact; the
         -- dispatch filter reads `status`, so both must move together.
         status = CASE WHEN p_online THEN 'online' ELSE 'offline' END,
         active_vehicle_id = COALESCE(active_vehicle_id, v_vehicle),
         current_latitude = COALESCE(p_lat, current_latitude),
         current_longitude = COALESCE(p_lng, current_longitude),
         location_updated_at = CASE
           WHEN p_lat IS NOT NULL THEN now() ELSE location_updated_at END,
         updated_at = now()
   WHERE id = v_driver;

  IF p_online AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    INSERT INTO public.driver_locations (driver_id, latitude, longitude, updated_at)
         VALUES (v_driver, p_lat, p_lng, now())
    ON CONFLICT (driver_id) DO UPDATE
      SET latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          updated_at = EXCLUDED.updated_at;
  END IF;

  -- Reviewer batch 16 #4: a driver coming online after a failed dispatch
  -- used to wait for the 2-minute cron sweep; re-offer nearby stuck rides
  -- immediately. _dispatch_delivery_internal still applies every driver
  -- eligibility filter, so this can only create valid offers.
  IF p_online AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    FOR v_stuck IN
      SELECT r.id
        FROM public.rides r
       WHERE r.status = 'searching'
         AND r.created_at >= now() - interval '45 minutes'
         AND r.pickup_latitude IS NOT NULL
         AND r.pickup_longitude IS NOT NULL
         AND haversine_km(r.pickup_latitude, r.pickup_longitude,
                          p_lat, p_lng) <= 25
         AND NOT EXISTS (
           SELECT 1 FROM public.ride_requests rr
            WHERE rr.ride_id = r.id
              AND rr.status = 'offered'
              AND rr.expires_at > now())
       ORDER BY r.created_at
       LIMIT 10
    LOOP
      BEGIN
        PERFORM public._dispatch_delivery_internal(v_stuck.id, 25.0, 15);
      EXCEPTION WHEN OTHERS THEN
        NULL; -- one bad ride must not block the driver going online
      END;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'driver_id', v_driver,
    'status', CASE WHEN p_online THEN 'online' ELSE 'offline' END,
    'active_vehicle_id', COALESCE(
      (SELECT active_vehicle_id FROM public.drivers WHERE id = v_driver),
      NULL
    )
  );
END;
$function$
;