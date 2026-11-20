-- Foreground presence lease: a 45-second fresh-position heartbeat renews
-- eligibility for two minutes. A dead/backgrounded app cannot stay dispatchable.
BEGIN;
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
CREATE OR REPLACE FUNCTION public.dispatch_delivery(p_ride_id uuid, p_radius_km numeric DEFAULT 10, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
  v_request RECORD;
  v_driver RECORD;
  v_offered_count INTEGER := 0;
  v_found_any BOOLEAN := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;
  IF NOT (public.is_admin() OR COALESCE(v_ride.rider_id = auth.uid(),false)
      OR (v_ride.merchant_id IS NOT NULL AND public.is_merchant_owner(v_ride.merchant_id))) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  IF v_ride.status != 'searching' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_searching');
  END IF;

  UPDATE public.ride_requests SET status='expired',responded_at=now()
    WHERE ride_id=p_ride_id AND status='offered' AND expires_at <= now();

  FOR v_driver IN
    SELECT d.id, d.user_id,
      haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                   d.current_latitude, d.current_longitude) AS dist_km
    FROM drivers d
    WHERE d.status = 'online'
      AND d.location_updated_at > now() - interval '2 minutes'
      AND d.is_verified = true
      AND d.is_active = true
      AND NOT EXISTS (SELECT 1 FROM public.ride_requests previous WHERE previous.ride_id=p_ride_id AND previous.driver_id=d.id)
      AND NOT EXISTS (SELECT 1 FROM public.rides busy WHERE busy.driver_id=d.id AND busy.status IN ('matched','arrived','inTrip'))
      AND d.active_vehicle_id IS NOT NULL
      AND d.active_vehicle_id IN (
        SELECT v.id FROM vehicles v
        WHERE v.driver_id = d.id
          AND v.is_active = true
          AND (v.category = v_ride.ride_type OR v_ride.service_type != 'ride')
      )
      AND (d.accepts_deliveries = true OR v_ride.service_type = 'ride')
      AND d.current_latitude IS NOT NULL
      AND d.current_longitude IS NOT NULL
      AND haversine_km(v_ride.pickup_latitude, v_ride.pickup_longitude,
                       d.current_latitude, d.current_longitude) <= p_radius_km
    ORDER BY dist_km ASC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 5), 30))
  LOOP
    BEGIN
      INSERT INTO ride_requests (ride_id, driver_id, status, distance_km, offered_at, expires_at)
      VALUES (
        p_ride_id, v_driver.id, 'offered', v_driver.dist_km,
        NOW(), NOW() + interval '20 seconds'
      );
      v_offered_count := v_offered_count + 1;
      v_found_any := true;
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
  END LOOP;

  IF NOT v_found_any AND EXISTS (
    SELECT 1 FROM public.ride_requests WHERE ride_id=p_ride_id
      AND status='offered' AND expires_at > now()
  ) THEN
    RETURN jsonb_build_object('success', true, 'offered_to', 0, 'reason', 'offers_pending');
  END IF;
  IF NOT v_found_any THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_drivers_available');
  END IF;

  RETURN jsonb_build_object('success', true, 'offered_to', v_offered_count);
END;
$function$
;
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
    vehicle_type = COALESCE(veh.make || ' ' || veh.model, drv.vehicle_type),
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
$function$
;
CREATE OR REPLACE FUNCTION public.driver_presence(p_driver_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE d drivers%ROWTYPE;
BEGIN
 SELECT * INTO d FROM drivers WHERE id=p_driver_id AND user_id=auth.uid();
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'reason','FORBIDDEN'); END IF;
 RETURN jsonb_build_object('ok',true,'online',COALESCE(d.is_online,false),
   'fresh',COALESCE(d.location_updated_at > now()-interval '2 minutes',false));
END; $$;
REVOKE ALL ON FUNCTION public.driver_presence(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.driver_presence(uuid) TO authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
