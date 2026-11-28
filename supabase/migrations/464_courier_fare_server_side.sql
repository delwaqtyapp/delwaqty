-- 464: courier delivery fare is computed and stored server-side at request time.
-- Before: request_courier_delivery inserted fare = NULL, the app only displayed an
-- estimate (estimate_delivery_fee) and nothing guaranteed the driver collected that
-- amount (driver_cash_collection_state collects rides.fare). Now the RPC prices the
-- ride with the same formula (courier pricing row, straight-line haversine km,
-- 1 kg, requested priority) so estimate = stored fare. No active courier pricing
-- row => PRICING_UNAVAILABLE and no ride. Signature, grants and the caller-cannot-
-- price guarantee are unchanged. Re-runnable (CREATE OR REPLACE).
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
