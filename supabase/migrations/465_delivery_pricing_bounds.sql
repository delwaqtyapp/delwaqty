-- 465: database-level bounds for delivery_pricing, and fail closed on a non-positive fare.
-- Why: the admin pricing editor (app) validates input, but a direct API write by an
-- admin could store negative fees or huge multipliers (estimate then returned a
-- negative fee as success). This adds:
--   1. CHECK delivery_pricing_bounds: base_fee/minimum_fee 0..500, per_km/per_kg 0..50,
--      priority/express multipliers 1..3 (same caps as the app). All 8 current rows fit.
--   2. updated_at set by a BEFORE UPDATE trigger (not the device clock).
--   3. request_courier_delivery and request_delivery return PRICING_UNAVAILABLE when
--      the computed fare is <= 0 (no ride is created).
-- Re-runnable. Signatures and grants unchanged (CREATE OR REPLACE).
ALTER TABLE public.delivery_pricing DROP CONSTRAINT IF EXISTS delivery_pricing_bounds;
ALTER TABLE public.delivery_pricing ADD CONSTRAINT delivery_pricing_bounds CHECK (
  base_fee BETWEEN 0 AND 500
  AND minimum_fee BETWEEN 0 AND 500
  AND per_km BETWEEN 0 AND 50
  AND COALESCE(per_kg, 0) BETWEEN 0 AND 50
  AND COALESCE(priority_multiplier, 1) BETWEEN 1 AND 3
  AND COALESCE(express_multiplier, 1) BETWEEN 1 AND 3
);

CREATE OR REPLACE FUNCTION public.delivery_pricing_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.delivery_pricing_touch_updated_at() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS delivery_pricing_touch_updated_at ON public.delivery_pricing;
CREATE TRIGGER delivery_pricing_touch_updated_at
  BEFORE UPDATE ON public.delivery_pricing
  FOR EACH ROW EXECUTE FUNCTION public.delivery_pricing_touch_updated_at();

CREATE OR REPLACE FUNCTION public.request_courier_delivery(p_pickup_latitude numeric, p_pickup_longitude numeric, p_pickup_address text, p_dropoff_latitude numeric, p_dropoff_longitude numeric, p_dropoff_address text, p_items_summary text DEFAULT NULL::text, p_dropoff_notes text DEFAULT NULL::text, p_priority text DEFAULT 'standard'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_delivery_id uuid;
  v_open int;
  v_km numeric;
  v_quote jsonb;
  v_fare numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  -- Input bounds: real coordinates, finite values, non-blank addresses,
  -- length caps, a known priority.
  IF p_pickup_latitude IS NULL OR p_pickup_longitude IS NULL
     OR p_dropoff_latitude IS NULL OR p_dropoff_longitude IS NULL
     OR p_pickup_latitude NOT BETWEEN -90 AND 90
     OR p_dropoff_latitude NOT BETWEEN -90 AND 90
     OR p_pickup_longitude NOT BETWEEN -180 AND 180
     OR p_dropoff_longitude NOT BETWEEN -180 AND 180
     OR p_pickup_latitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_dropoff_latitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_pickup_longitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_dropoff_longitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_pickup_address IS NULL OR btrim(p_pickup_address) = ''
     OR p_dropoff_address IS NULL OR btrim(p_dropoff_address) = ''
     OR length(p_pickup_address) > 500 OR length(p_dropoff_address) > 500
     OR length(COALESCE(p_items_summary, '')) > 500
     OR length(COALESCE(p_dropoff_notes, '')) > 500 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  IF p_priority NOT IN ('standard', 'priority', 'express') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  -- Abuse cap: at most 5 open (searching) rides per rider, counted over
  -- all service types. The advisory lock serializes concurrent requests
  -- from the same rider so the check-then-insert cannot race.
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));
  SELECT count(*) INTO v_open
    FROM public.rides
   WHERE rider_id = v_uid AND status = 'searching';
  IF v_open >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TOO_MANY_OPEN_RIDES');
  END IF;

  -- Server-side price: same formula the app shows as the estimate
  -- (estimate_delivery_fee, courier row, straight-line km, 1 kg), stored so
  -- the amount the driver collects equals the quote. Fail closed when no
  -- active courier pricing exists: never create a ride with an unknown price.
  v_km := public.haversine_km(
    p_pickup_latitude::float8, p_pickup_longitude::float8,
    p_dropoff_latitude::float8, p_dropoff_longitude::float8
  )::numeric;
  v_quote := public.estimate_delivery_fee('courier', v_km, 1.0, p_priority);
  IF NOT COALESCE((v_quote->>'success')::boolean, false)
     OR (v_quote->>'fee') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICING_UNAVAILABLE');
  END IF;
  v_fare := (v_quote->>'fee')::numeric;
  IF v_fare <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICING_UNAVAILABLE');
  END IF;

  -- Every field is server-controlled: rider from the JWT, service_type
  -- fixed, payment/currency at column defaults, fare computed here, order_id and
  -- merchant_id always NULL. The caller cannot price or link anything.
  INSERT INTO public.rides (
    rider_id,
    pickup_latitude, pickup_longitude, pickup_address,
    dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status,
    items_summary, dropoff_notes, priority,
    fare, order_id, merchant_id
  ) VALUES (
    v_uid,
    p_pickup_latitude, p_pickup_longitude, p_pickup_address,
    p_dropoff_latitude, p_dropoff_longitude, p_dropoff_address,
    'motorcycle', 'courier', 'searching',
    p_items_summary, p_dropoff_notes, COALESCE(p_priority, 'standard'),
    v_fare, NULL, NULL
  ) RETURNING id INTO v_delivery_id;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_id', v_delivery_id,
    'fare', v_fare,
    'currency', COALESCE(v_quote->>'currency', 'EGP')
  );
END;
$function$;

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
  IF v_fee <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICING_UNAVAILABLE');
  END IF;
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
$function$;
