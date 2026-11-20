-- Current fleet: motorcycle, tuk_tuk, tricycle, car. Live preflight found
-- no vehicles or rides and one driver with a NULL vehicle_type.
BEGIN;
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_category_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_category_check CHECK(category IN ('motorcycle','tuk_tuk','tricycle','car'));
ALTER TABLE public.vehicles ALTER COLUMN category SET DEFAULT 'motorcycle';
ALTER TABLE public.rides DROP CONSTRAINT IF EXISTS rides_ride_type_check;
ALTER TABLE public.rides ADD CONSTRAINT rides_ride_type_check CHECK(ride_type IN ('motorcycle','tuk_tuk','tricycle','car'));
ALTER TABLE public.rides ALTER COLUMN ride_type SET DEFAULT 'motorcycle';
ALTER TABLE public.drivers ADD CONSTRAINT drivers_delivery_vehicle_type_check CHECK(vehicle_type IS NULL OR vehicle_type IN ('motorcycle','tuk_tuk','tricycle','car'));
ALTER TABLE public.rides ADD CONSTRAINT rides_delivery_vehicle_type_check CHECK(vehicle_type IS NULL OR vehicle_type IN ('motorcycle','tuk_tuk','tricycle','car'));
CREATE OR REPLACE FUNCTION public.add_driver_vehicle(p_driver_id uuid, p_category text, p_make text, p_model text, p_year integer, p_color text, p_plate_number text, p_seats integer DEFAULT 4, p_photo_url text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id UUID;
BEGIN
  IF p_category IS NOT NULL AND p_category NOT IN ('motorcycle','tuk_tuk','tricycle','car') THEN
    RAISE EXCEPTION 'Invalid delivery vehicle type';
  END IF;
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  INSERT INTO vehicles (driver_id, category, make, model, year, color, plate_number, seats, photo_url)
  VALUES (p_driver_id, p_category, p_make, p_model, p_year, p_color, p_plate_number, p_seats, p_photo_url)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'vehicle_id', v_id);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.driver_complete_registration(p_full_name text, p_phone text DEFAULT NULL::text, p_vehicle_type text DEFAULT NULL::text, p_vehicle_plate text DEFAULT NULL::text, p_vehicle_color text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_vehicle uuid;
BEGIN
  IF p_vehicle_type IS NOT NULL AND p_vehicle_type NOT IN ('motorcycle','tuk_tuk','tricycle','car') THEN
    RAISE EXCEPTION 'Invalid delivery vehicle type';
  END IF;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_full_name IS NULL OR btrim(p_full_name) = '' THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  SELECT id INTO v_driver FROM public.drivers WHERE user_id = v_uid LIMIT 1;

  IF v_driver IS NULL THEN
    INSERT INTO public.drivers
      (user_id, full_name, phone, vehicle_type, vehicle_plate,
       vehicle_color, status, is_online, is_active, is_verified,
       verification_status, onboarding_step, created_at, updated_at)
    VALUES
      (v_uid, btrim(p_full_name), p_phone, p_vehicle_type, p_vehicle_plate,
       p_vehicle_color, 'offline', false, true, false, 'pending', 1,
       now(), now())
    RETURNING id INTO v_driver;
  ELSE
    UPDATE public.drivers
       SET full_name = btrim(p_full_name),
           phone = COALESCE(p_phone, phone),
           vehicle_type = COALESCE(p_vehicle_type, vehicle_type),
           vehicle_plate = COALESCE(p_vehicle_plate, vehicle_plate),
           vehicle_color = COALESCE(p_vehicle_color, vehicle_color),
           updated_at = now()
     WHERE id = v_driver
      RETURNING id INTO v_driver;
  END IF;

  -- A driver with no vehicle can never satisfy the dispatch filter.
  IF p_vehicle_type IS NOT NULL AND btrim(COALESCE(p_vehicle_plate,'')) <> '' THEN
    SELECT id INTO v_vehicle
      FROM public.vehicles
     WHERE driver_id = v_driver
       AND category = p_vehicle_type
     LIMIT 1;

    IF v_vehicle IS NULL THEN
      -- The live vehicles table uses `category` (not vehicle_type),
      -- `plate_number` (not vehicle_plate) and `color` (not
      -- vehicle_color).
      INSERT INTO public.vehicles
        (driver_id, category, plate_number, color, is_active, is_verified, created_at)
      VALUES
        (v_driver, p_vehicle_type, p_vehicle_plate, p_vehicle_color, true, false, now())
      RETURNING id INTO v_vehicle;
    ELSE
      UPDATE public.vehicles
         SET is_active = true,
             plate_number = COALESCE(p_vehicle_plate, plate_number),
             color = COALESCE(p_vehicle_color, color)
       WHERE id = v_vehicle;
    END IF;

    UPDATE public.drivers SET active_vehicle_id = v_vehicle WHERE id = v_driver;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'driver_id', v_driver, 'vehicle_id', v_vehicle
  );
END;
$function$
;
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
CREATE OR REPLACE FUNCTION public.register_ride_driver(p_full_name text, p_phone text, p_category text, p_make text, p_model text, p_color text, p_plate text, p_seats integer DEFAULT 4)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_driver_id UUID;
  v_vehicle_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;
  IF p_category NOT IN ('motorcycle','tuk_tuk','tricycle','car') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_category');
  END IF;

  SELECT id INTO v_driver_id FROM drivers WHERE user_id = v_uid;
  IF v_driver_id IS NULL THEN
    INSERT INTO drivers (user_id, full_name, phone, vehicle_type, vehicle_model,
                         vehicle_color, vehicle_plate, is_online, is_verified,
                         verification_status, status, earnings_balance, rating,
                         total_trips)
      VALUES (v_uid, p_full_name, p_phone, p_category, p_make || ' ' || p_model,
              p_color, p_plate, false, false, 'pending', 'offline', 0, 5.0, 0)
      RETURNING id INTO v_driver_id;
  ELSE
    UPDATE drivers SET
      full_name = COALESCE(p_full_name, full_name),
      phone = COALESCE(p_phone, phone)
    WHERE id = v_driver_id;
  END IF;

  SELECT id INTO v_vehicle_id FROM vehicles
    WHERE driver_id = v_driver_id AND category = p_category LIMIT 1;
  IF v_vehicle_id IS NULL THEN
    INSERT INTO vehicles (driver_id, category, make, model, color, plate_number,
                          seats, is_active)
      VALUES (v_driver_id, p_category, p_make, p_model, p_color, p_plate,
              p_seats, true)
      RETURNING id INTO v_vehicle_id;
  ELSE
    UPDATE vehicles SET make = p_make, model = p_model, color = p_color,
      plate_number = p_plate, seats = p_seats, is_active = true
    WHERE id = v_vehicle_id;
  END IF;

  UPDATE drivers SET active_vehicle_id = v_vehicle_id WHERE id = v_driver_id;

  RETURN jsonb_build_object('success', true, 'driver_id', v_driver_id,
                            'vehicle_id', v_vehicle_id);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.request_delivery(p_pickup_latitude numeric, p_pickup_longitude numeric, p_pickup_address text, p_dropoff_latitude numeric, p_dropoff_longitude numeric, p_dropoff_address text, p_items_summary text, p_weight_kg numeric DEFAULT 0, p_dropoff_notes text DEFAULT NULL::text, p_priority text DEFAULT 'standard'::text, p_payment_method text DEFAULT 'cash'::text, p_otp_required boolean DEFAULT true, p_vehicle_type text DEFAULT 'motorcycle'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_pricing RECORD;
  v_distance double precision;
  v_fee numeric;
  v_multiplier numeric := 1.0;
  v_delivery_id uuid;
  v_currency text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  IF p_pickup_latitude IS NULL OR p_pickup_longitude IS NULL OR
     p_dropoff_latitude IS NULL OR p_dropoff_longitude IS NULL OR
     p_items_summary IS NULL OR p_dropoff_address IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT * INTO v_pricing
    FROM delivery_pricing
   WHERE service_type = 'marketplace_delivery' AND is_active = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICING_UNAVAILABLE');
  END IF;

  SELECT haversine_km(
           p_pickup_latitude::double precision,
           p_pickup_longitude::double precision,
           p_dropoff_latitude::double precision,
           p_dropoff_longitude::double precision
         ) INTO v_distance;
  v_distance := GREATEST(COALESCE(v_distance, 0), 0.1);

  v_fee := v_pricing.base_fee
           + (v_pricing.per_km * v_distance)
           + (COALESCE(p_weight_kg, 0) * COALESCE(v_pricing.per_kg, 0));

  IF p_priority = 'priority' THEN
    v_multiplier := v_pricing.priority_multiplier;
  ELSIF p_priority = 'express' THEN
    v_multiplier := v_pricing.express_multiplier;
  END IF;

  v_fee := v_fee * v_multiplier;

  IF v_fee < v_pricing.minimum_fee THEN
    v_fee := v_pricing.minimum_fee;
  END IF;
  v_fee := ROUND(v_fee, 2);
  v_currency := v_pricing.currency;

  INSERT INTO public.rides (
    rider_id,
    pickup_latitude, pickup_longitude, pickup_address,
    dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status, fare,
    distance, estimated_minutes,
    items_summary, weight_kg, dropoff_notes,
    priority, payment_method, currency,
    otp_required
  ) VALUES (
    v_uid,
    p_pickup_latitude, p_pickup_longitude, p_pickup_address,
    p_dropoff_latitude, p_dropoff_longitude, p_dropoff_address,
    COALESCE(p_vehicle_type, 'motorcycle'), 'marketplace_delivery', 'searching',
    v_fee, ROUND(v_distance::numeric, 4),
    GREATEST(CEIL(v_distance / 25.0 * 60)::int, 5),
    p_items_summary, COALESCE(p_weight_kg, 0), p_dropoff_notes,
    COALESCE(p_priority, 'standard'), COALESCE(p_payment_method, 'cash'),
    v_currency, COALESCE(p_otp_required, true)
  ) RETURNING id INTO v_delivery_id;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_id', v_delivery_id,
    'fare', v_fee,
    'distance_km', ROUND(v_distance::numeric, 2),
    'currency', v_currency
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.update_driver_vehicle(p_vehicle_id uuid, p_driver_id uuid, p_category text DEFAULT NULL::text, p_make text DEFAULT NULL::text, p_model text DEFAULT NULL::text, p_year integer DEFAULT NULL::integer, p_color text DEFAULT NULL::text, p_plate_number text DEFAULT NULL::text, p_seats integer DEFAULT NULL::integer, p_photo_url text DEFAULT NULL::text, p_is_active boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_category IS NOT NULL AND p_category NOT IN ('motorcycle','tuk_tuk','tricycle','car') THEN
    RAISE EXCEPTION 'Invalid delivery vehicle type';
  END IF;
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  UPDATE vehicles SET
    category = COALESCE(p_category, category),
    make = COALESCE(p_make, make),
    model = COALESCE(p_model, model),
    year = COALESCE(p_year, year),
    color = COALESCE(p_color, color),
    plate_number = COALESCE(p_plate_number, plate_number),
    seats = COALESCE(p_seats, seats),
    photo_url = COALESCE(p_photo_url, photo_url),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_vehicle_id AND driver_id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$function$
;
NOTIFY pgrst,'reload schema';
COMMIT;
