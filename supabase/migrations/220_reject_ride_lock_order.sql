-- 220: BUG 6 (sim lab) - deadlock 40P01 between accept_ride_request and
-- reject_ride_request under concurrent accept/reject on the same ride.
-- accept locks drivers -> rides -> ride_requests; reject took a ride_request
-- row lock first and then needed a rides key-share lock for the trip_events
-- FK, inverting the order. Reject now takes the same locks in the same order.
CREATE OR REPLACE FUNCTION public.reject_ride_request(p_ride_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM public.drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  -- Same lock order as accept_ride_request (drivers, then ride, then the
  -- request rows) so concurrent accept/reject cannot deadlock. The drivers
  -- row is already read above; lock the ride before touching ride_requests.
  PERFORM 1 FROM public.drivers WHERE id = p_driver_id FOR UPDATE;
  PERFORM 1 FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  UPDATE public.ride_requests SET status = 'rejected', responded_at = NOW()
    WHERE ride_id = p_ride_id AND driver_id = p_driver_id AND status = 'offered';
  INSERT INTO public.trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'rejected', 'driver');
  RETURN jsonb_build_object('success', true);
END;
$function$;
