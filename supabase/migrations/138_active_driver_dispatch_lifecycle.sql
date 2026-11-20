-- Active driver lifecycle repair. UI uses rides + ride_requests RPCs,
-- not the legacy deliveries view. No payout/commission policy changes.
BEGIN;

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
$function$;

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
      'motorbike',
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
$function$;

ALTER TABLE public.rides DROP CONSTRAINT IF EXISTS rides_payment_method_check;
ALTER TABLE public.rides ADD CONSTRAINT rides_payment_method_check
  CHECK (payment_method IN ('cash','card','wallet','instapay','vodafone_cash'));

CREATE OR REPLACE FUNCTION public.accept_ride_request(p_ride_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
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
$function$;

CREATE OR REPLACE FUNCTION public.reject_ride_request(p_ride_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  UPDATE ride_requests SET status = 'rejected', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id AND status = 'offered';
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'rejected', 'driver');
  RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.driver_arrive(p_ride_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'matched' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  UPDATE rides SET status = 'arrived', arrived_at = NOW(),
    driver_arrived_confirmed = true WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'driver_arrived', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'arrived');
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_trip(p_ride_id uuid, p_driver_id uuid, p_otp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'arrived' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  UPDATE rides SET status = 'inTrip', started_at = NOW(), picked_up_at = NOW()
    WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'picked_up', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'inTrip');
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_ride_lifecycle(p_ride_id uuid, p_by text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_is_rider BOOLEAN;
  v_is_driver BOOLEAN;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  v_is_rider := (r.rider_id = auth.uid());
  v_is_driver := EXISTS (SELECT 1 FROM drivers WHERE id = r.driver_id AND user_id = auth.uid());
  IF auth.uid() IS NULL OR NOT (COALESCE(v_is_rider,false) OR COALESCE(v_is_driver,false)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF r.status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  UPDATE rides SET status = 'cancelled', cancelled_at = NOW(),
    cancellation_reason = p_reason,
    cancelled_by = CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND status = 'offered';
  UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;

  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (p_ride_id, 'cancelled', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END);
  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_linked_delivery_order()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NEW.order_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.status = 'matched' THEN
    UPDATE public.orders SET driver_id=NEW.driver_id, dispatch_status='ASSIGNED', updated_at=now()
      WHERE id=NEW.order_id AND status NOT IN ('cancelled','delivered');
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
END; $$;
DROP TRIGGER IF EXISTS sync_linked_delivery_order ON public.rides;
CREATE TRIGGER sync_linked_delivery_order AFTER UPDATE OF status ON public.rides
  FOR EACH ROW WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.sync_linked_delivery_order();

-- Clients may read their offers; creating or editing offers is server-owned.
DROP POLICY IF EXISTS "ride requests driver" ON public.ride_requests;
CREATE POLICY "ride requests driver read" ON public.ride_requests FOR SELECT TO authenticated
 USING (driver_id IN (SELECT id FROM public.drivers WHERE user_id=auth.uid()));

CREATE OR REPLACE FUNCTION public.complete_delivery(
 p_ride_id uuid, p_driver_id uuid, p_proof_url text DEFAULT NULL,
 p_final_distance numeric DEFAULT NULL, p_recipient_otp text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
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
 UPDATE public.rides SET status='completed',completed_at=now(),delivered_at=now(),
   delivery_proof_url=COALESCE(p_proof_url,delivery_proof_url) WHERE id=p_ride_id;
 UPDATE public.driver_locations SET ride_id=NULL WHERE driver_id=p_driver_id AND ride_id=p_ride_id;
 INSERT INTO public.trip_events(ride_id,event_type,actor) VALUES(p_ride_id,'delivered','driver');
 RETURN jsonb_build_object('success',true,'ride_id',p_ride_id,'fare',r.fare);
END; $$;

REVOKE ALL ON FUNCTION public.dispatch_delivery(uuid,numeric,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispatch_delivery(uuid,numeric,integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.merchant_dispatch_order_driver(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_dispatch_order_driver(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.accept_ride_request(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_ride_request(uuid,uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reject_ride_request(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_ride_request(uuid,uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.driver_arrive(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_arrive(uuid,uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.start_trip(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_trip(uuid,uuid,text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cancel_ride_lifecycle(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_ride_lifecycle(uuid,text,text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.complete_delivery(uuid,uuid,text,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_delivery(uuid,uuid,text,numeric,text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.driver_update_location(p_driver_id uuid, p_lat double precision, p_lon double precision, p_heading double precision DEFAULT NULL::double precision, p_speed double precision DEFAULT NULL::double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public,pg_temp
AS $function$
DECLARE
  v_owner UUID;
  v_ride UUID;
BEGIN
  IF auth.uid() IS NULL OR p_lat IS NULL OR p_lon IS NULL OR p_lat NOT BETWEEN -90 AND 90 OR p_lon NOT BETWEEN -180 AND 180 THEN
    RETURN jsonb_build_object('success',false,'reason','invalid_location');
  END IF;
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT id INTO v_ride FROM rides
    WHERE driver_id = p_driver_id
      AND status IN ('matched','arrived','inTrip')
    ORDER BY created_at DESC LIMIT 1;

  INSERT INTO driver_locations (driver_id, latitude, longitude, heading, speed, ride_id, updated_at)
    VALUES (p_driver_id, p_lat, p_lon, p_heading, p_speed, v_ride, NOW())
  ON CONFLICT (driver_id) DO UPDATE
    SET latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        heading = EXCLUDED.heading,
        speed = EXCLUDED.speed,
        ride_id = EXCLUDED.ride_id,
        updated_at = NOW();

  UPDATE drivers SET
    current_latitude = p_lat,
    current_longitude = p_lon,
    location_updated_at = NOW()
  WHERE id = p_driver_id;

  IF v_ride IS NOT NULL THEN
    UPDATE rides SET
      driver_latitude = p_lat,
      driver_longitude = p_lon,
      driver_heading = p_heading
    WHERE id = v_ride;
  END IF;

  RETURN jsonb_build_object('success', true, 'ride_id', v_ride);
END;
$function$;

REVOKE ALL ON FUNCTION public.driver_update_location(uuid,double precision,double precision,double precision,double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_update_location(uuid,double precision,double precision,double precision,double precision) TO authenticated, service_role;
-- The retired compatibility writer skipped all lifecycle checks. Current UI
-- callers use the RPCs above. Keep the compatibility relation read-only.
REVOKE UPDATE ON public.deliveries FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_driver_delivery_offer()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_user uuid;
BEGIN
 IF NEW.status <> 'offered' OR NEW.expires_at <= now() THEN RETURN NEW; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.rides WHERE id=NEW.ride_id AND service_type <> 'ride') THEN RETURN NEW; END IF;
 SELECT user_id INTO v_user FROM public.drivers WHERE id=NEW.driver_id;
 IF v_user IS NOT NULL THEN
   INSERT INTO public.notifications(user_id,title,body,type,data,deep_link,idempotency_key,send_push)
   VALUES(v_user,'عرض توصيل متاح','افتح التطبيق لمراجعة عرض التوصيل قبل انتهاء وقته','delivery',
     jsonb_build_object('entity_type','delivery','entity_id',NEW.ride_id::text,'action','offer','expires_at',NEW.expires_at),
     '/driver/hub','delivery-offer-'||NEW.id::text,true)
   ON CONFLICT(idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS notify_driver_delivery_offer ON public.ride_requests;
CREATE TRIGGER notify_driver_delivery_offer AFTER INSERT ON public.ride_requests
 FOR EACH ROW EXECUTE FUNCTION public.notify_driver_delivery_offer();

CREATE OR REPLACE FUNCTION public.notify_driver_delivery_assigned()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid;
BEGIN
  IF NEW.service_type <> 'ride'
     AND NEW.driver_id IS NOT NULL
     AND (OLD.driver_id IS DISTINCT FROM NEW.driver_id) THEN
    SELECT user_id INTO v_uid FROM public.drivers WHERE id = NEW.driver_id;
    IF v_uid IS NOT NULL THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key, send_push)
      VALUES
        (v_uid, 'طلب توصيل جديد', 'عندك طلب توصيل جديد مستنييك', 'delivery',
         jsonb_build_object('entity_type', 'delivery', 'entity_id', NEW.id::text, 'action', 'assigned'),
         '/driver/hub',
         'delivery-assigned-' || NEW.id::text || '-' || v_uid::text,
         true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END IF;
  END IF;
  RETURN NULL;
END;
$function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
