-- 222: redispatch sweep for rides stuck 'searching' (approved by main).
-- The first dispatch offer can expire unanswered (driver offline, ignored);
-- without a sweep the order would wait forever. Every 2 minutes, rides that
-- have been searching for over 2 minutes with no live offer get re-offered
-- via _dispatch_delivery_internal, which already excludes drivers who
-- rejected/accepted and re-locks the ride (BUG 6 order).
CREATE OR REPLACE FUNCTION public.redispatch_stuck_searching_rides()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride record;
  v_n integer := 0;
BEGIN
  FOR v_ride IN
    SELECT r.id
      FROM public.rides r
     WHERE r.status = 'searching'
       AND r.created_at < now() - interval '2 minutes'
       AND NOT EXISTS (
         SELECT 1 FROM public.ride_requests rr
          WHERE rr.ride_id = r.id
            AND rr.status = 'offered'
            AND rr.expires_at > now()
       )
     ORDER BY r.created_at
     LIMIT 50
  LOOP
    PERFORM public._dispatch_delivery_internal(v_ride.id, 25.0, 15);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;

-- Cron-only entry point: never client-callable.
REVOKE EXECUTE ON FUNCTION public.redispatch_stuck_searching_rides() FROM public, anon, authenticated;

SELECT cron.schedule('redispatch-stuck-rides', '*/2 * * * *', $cmd$SELECT public.redispatch_stuck_searching_rides()$cmd$);
