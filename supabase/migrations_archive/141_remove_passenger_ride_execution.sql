-- Remove passenger-only execution entry points. Shared delivery tables,
-- lifecycle RPCs, tracking, maps, driver GPS and financial records stay.
BEGIN;
CREATE OR REPLACE FUNCTION public.rate_recipient(p_delivery_id uuid, p_driver_id uuid, p_stars integer, p_comment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public,pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_delivery_id;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.service_type = 'ride' THEN
    RETURN jsonb_build_object('success',false,'reason','not_a_delivery');
  END IF;
  IF r.status IS DISTINCT FROM 'completed' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_completed');
  END IF;
  IF p_stars < 1 OR p_stars > 5 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_stars');
  END IF;
  UPDATE rides SET driver_rating = p_stars, driver_feedback = p_comment WHERE id = p_delivery_id;
  INSERT INTO ride_ratings (ride_id, rater_id, ratee_role, stars, comment)
    VALUES (p_delivery_id, auth.uid(), 'rider', p_stars, p_comment)
  ON CONFLICT (ride_id, rater_id) DO UPDATE
    SET stars = EXCLUDED.stars, comment = EXCLUDED.comment;
  RETURN jsonb_build_object('success', true);
END;
$function$
;
DROP FUNCTION IF EXISTS public.request_ride(uuid, numeric, numeric, text, numeric, numeric, text, text, double precision, double precision, double precision, text, text, numeric, text);
DROP FUNCTION IF EXISTS public.dispatch_ride(uuid, double precision, integer);
DROP FUNCTION IF EXISTS public.accept_ride(uuid, uuid);
DROP FUNCTION IF EXISTS public.advance_ride(uuid, text, text);
DROP FUNCTION IF EXISTS public.complete_trip(uuid, uuid, double precision);
DROP FUNCTION IF EXISTS public.estimate_fare(text, double precision, double precision, double precision);
DROP FUNCTION IF EXISTS public.rate_passenger(uuid, uuid, integer, text);
DROP FUNCTION IF EXISTS public.register_delivery_driver(text,text,text,text,text,text,text,integer);
DROP FUNCTION IF EXISTS public.register_ride_driver(text, text, text, text, text, text, text, integer);
DROP FUNCTION IF EXISTS public.find_nearest_drivers(double precision,double precision,text,double precision,integer);
-- Hard server boundary: legacy clients cannot create passenger trips.
ALTER TABLE public.rides ADD CONSTRAINT rides_delivery_services_only
 CHECK(service_type IS NOT NULL AND service_type <> 'ride');
ALTER TABLE public.rides ALTER COLUMN service_type SET DEFAULT 'courier';
-- Keep historical pricing data out of client access. It is not a delivery
-- pricing source; public.delivery_pricing is retained unchanged.
REVOKE ALL ON TABLE public.ride_pricing FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
