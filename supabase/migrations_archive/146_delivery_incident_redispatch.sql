-- 146: delivery custody incidents and automatic redispatch.
--
-- Before this migration, cancel_ride_lifecycle cancelled a ride at ANY stage
-- and the sync trigger marked the linked order 'cancelled' with it. Two
-- failures resulted:
--   * Goods already picked up (status 'inTrip', physically in the driver's
--     custody) could vanish into a plain cancellation - no incident record,
--     the customer told the order was simply cancelled while a driver held it.
--   * A driver cancelling before pickup killed the customer's order outright,
--     even though other drivers might be available. The customer lost their
--     delivery because one driver changed their mind.
--
-- Now:
--   * Cancelling while goods are in custody is refused ('in_custody'); the
--     driver or rider files an incident through report_delivery_incident and
--     support resolves it (return to merchant / redeliver / cancel) through
--     resolve_delivery_incident.
--   * A driver cancelling before pickup returns the ride to 'searching' and
--     the server immediately re-offers it to the next-nearest eligible
--     drivers. The cancelling driver's prior ride_request row excludes them
--     from re-offer, and the handoff-code trigger issues fresh codes for the
--     replacement driver. Only when nobody is available does the order fall
--     back to PENDING_DISPATCH for the merchant to retry.
--   * A rider cancelling before pickup still cancels outright (goods not yet
--     handed over), matching the previous behavior.
--
-- The dispatch fan-out is extracted into _dispatch_delivery_internal so the
-- server can re-offer without the caller's merchant/rider authorization
-- context; the public dispatch_delivery keeps its authorization checks.
BEGIN;

-- Internal, unauthenticated-context dispatch fan-out. Never callable by
-- clients: only SECURITY DEFINER server flows reach it.
CREATE OR REPLACE FUNCTION public._dispatch_delivery_internal(p_ride_id uuid, p_radius_km numeric DEFAULT 10, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
  v_driver RECORD;
  v_offered_count INTEGER := 0;
  v_found_any BOOLEAN := false;
BEGIN
  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
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
      -- Only active engagements exclude: an offer that EXPIRED unanswered may
      -- be re-offered (automatic retry); a rejected, accepted or cancelled
      -- one may not.
      AND NOT EXISTS (SELECT 1 FROM public.ride_requests previous WHERE previous.ride_id=p_ride_id AND previous.driver_id=d.id AND previous.status IN ('offered','accepted','rejected','cancelled'))
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
    -- The (ride_id, driver_id) uniqueness means a re-offer revives the
    -- expired row with a fresh window instead of inserting a twin.
    INSERT INTO ride_requests (ride_id, driver_id, status, distance_km, offered_at, expires_at)
    VALUES (
      p_ride_id, v_driver.id, 'offered', v_driver.dist_km,
      NOW(), NOW() + interval '20 seconds'
    )
    ON CONFLICT (ride_id, driver_id) DO UPDATE
      SET status = 'offered', distance_km = EXCLUDED.distance_km,
          offered_at = NOW(), expires_at = NOW() + interval '20 seconds',
          responded_at = NULL;
    v_offered_count := v_offered_count + 1;
    v_found_any := true;
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
REVOKE ALL ON FUNCTION public._dispatch_delivery_internal(uuid, numeric, integer) FROM PUBLIC, anon, authenticated;

-- The public entry point keeps its authorization checks and delegates.
CREATE OR REPLACE FUNCTION public.dispatch_delivery(p_ride_id uuid, p_radius_km numeric DEFAULT 10, p_limit integer DEFAULT 5)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  SELECT * INTO v_ride FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ride_not_found');
  END IF;
  IF NOT (public.is_admin() OR COALESCE(v_ride.rider_id = auth.uid(),false)
      OR (v_ride.merchant_id IS NOT NULL AND public.is_merchant_owner(v_ride.merchant_id))) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  RETURN public._dispatch_delivery_internal(p_ride_id, p_radius_km, p_limit);
END;
$function$;

-- A driver's own accepted offer becomes 'cancelled' when they back out, so
-- the audit trail distinguishes it from a rejection or an expiry.
ALTER TABLE public.ride_requests DROP CONSTRAINT IF EXISTS ride_requests_status_check;
ALTER TABLE public.ride_requests ADD CONSTRAINT ride_requests_status_check
  CHECK (status IN ('offered','accepted','rejected','expired','cancelled'));

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
  v_driver_id uuid;
  v_dispatch jsonb;
  v_offered boolean;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  v_is_rider := (r.rider_id = auth.uid());
  SELECT id INTO v_driver_id FROM drivers WHERE user_id = auth.uid() AND id = r.driver_id;
  v_is_driver := (v_driver_id IS NOT NULL);
  IF auth.uid() IS NULL OR NOT (COALESCE(v_is_rider,false) OR COALESCE(v_is_driver,false)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF r.status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  -- Goods are physically with the driver: a plain cancellation would erase
  -- custody. This is an incident, not a cancel.
  IF r.status = 'inTrip' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'in_custody');
  END IF;

  -- Driver backs out before pickup: keep the customer's delivery alive and
  -- re-offer it to other drivers automatically.
  IF v_is_driver AND r.status IN ('matched','arrived') THEN
    UPDATE ride_requests SET status = 'cancelled', responded_at = NOW()
      WHERE ride_id = p_ride_id AND driver_id = v_driver_id AND status = 'accepted';
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND status = 'offered';
    UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;
    UPDATE rides SET status = 'searching', driver_id = NULL,
      cancellation_reason = p_reason, cancelled_by = 'driver'
      WHERE id = p_ride_id;
    INSERT INTO trip_events (ride_id, event_type, actor)
      VALUES (p_ride_id, 'driver_cancelled_redispatch', 'driver');

    v_dispatch := public._dispatch_delivery_internal(p_ride_id, 25.0, 15);
    v_offered := COALESCE((v_dispatch->>'success')::boolean, false);

    UPDATE public.orders
       SET driver_id = NULL,
           dispatch_status = CASE WHEN v_offered THEN 'OFFERED' ELSE 'PENDING_DISPATCH' END,
           updated_at = now()
     WHERE id = r.order_id
       AND status NOT IN ('cancelled','delivered');

    RETURN jsonb_build_object('success', true, 'status', 'redispatching',
      'offered', v_offered,
      'dispatch_reason', v_dispatch->>'reason');
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

-- Custody incidents: server-owned rows, reached only through RPCs.
CREATE TABLE IF NOT EXISTS public.delivery_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id),
  order_id uuid REFERENCES public.orders(id),
  reporter_user_id uuid NOT NULL,
  reporter_role text NOT NULL CHECK (reporter_role IN ('driver','rider')),
  kind text NOT NULL,
  note text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved')),
  resolution text,
  resolved_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
ALTER TABLE public.delivery_incidents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.delivery_incidents FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.report_delivery_incident(p_ride_id uuid, p_kind text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_role text;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'unauthenticated');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF r.rider_id = auth.uid() THEN
    v_role := 'rider';
  ELSIF EXISTS (SELECT 1 FROM drivers WHERE id = r.driver_id AND user_id = auth.uid()) THEN
    v_role := 'driver';
  ELSE
    RETURN jsonb_build_object('ok', false, 'reason', 'forbidden');
  END IF;
  IF r.status NOT IN ('matched','arrived','inTrip') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_transition');
  END IF;
  IF p_kind IS NULL OR btrim(p_kind) = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_kind');
  END IF;

  INSERT INTO public.delivery_incidents (ride_id, order_id, reporter_user_id, reporter_role, kind, note)
    VALUES (p_ride_id, r.order_id, auth.uid(), v_role, btrim(p_kind), NULLIF(btrim(p_note), ''))
    RETURNING id INTO v_id;
  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (p_ride_id, 'incident_reported', v_role);
  RETURN jsonb_build_object('ok', true, 'incident_id', v_id, 'role', v_role);
END;
$function$;
REVOKE ALL ON FUNCTION public.report_delivery_incident(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.report_delivery_incident(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_delivery_incidents(p_status text DEFAULT 'open', p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS SETOF public.delivery_incidents
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT i.* FROM public.delivery_incidents i
    WHERE p_status IS NULL OR i.status = p_status
    ORDER BY i.created_at DESC
    LIMIT LEAST(COALESCE(p_limit, 100), 500) OFFSET COALESCE(p_offset, 0);
END;
$function$;
REVOKE ALL ON FUNCTION public.list_delivery_incidents(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_delivery_incidents(text, integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_delivery_incident(p_incident_id uuid, p_resolution text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  i public.delivery_incidents%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'forbidden');
  END IF;
  IF p_resolution NOT IN ('redelivered','returned_to_merchant','cancelled','dismissed') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_resolution');
  END IF;
  SELECT * INTO i FROM public.delivery_incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;
  IF i.status = 'resolved' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_resolved');
  END IF;

  -- Returned goods end the ride and the order; a plain cancel of the order
  -- closes it out. Redelivery keeps the ride alive for the driver to finish.
  IF p_resolution IN ('returned_to_merchant','cancelled') THEN
    UPDATE public.rides SET status = 'cancelled', cancelled_at = now(),
      cancelled_by = 'system', cancellation_reason = 'incident: ' || p_resolution
      WHERE id = i.ride_id AND status NOT IN ('completed','cancelled');
    UPDATE public.orders SET status = 'cancelled', updated_at = now()
      WHERE id = i.order_id AND status NOT IN ('delivered','cancelled');
  END IF;

  UPDATE public.delivery_incidents
     SET status = 'resolved', resolution = p_resolution,
         note = COALESCE(NULLIF(btrim(p_note), ''), note),
         resolved_by = auth.uid(), resolved_at = now()
   WHERE id = p_incident_id;
  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (i.ride_id, 'incident_resolved_' || p_resolution, 'support');
  RETURN jsonb_build_object('ok', true, 'resolution', p_resolution);
END;
$function$;
REVOKE ALL ON FUNCTION public.resolve_delivery_incident(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_delivery_incident(uuid, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
