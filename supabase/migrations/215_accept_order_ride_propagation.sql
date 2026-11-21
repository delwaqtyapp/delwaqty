-- 215: E2E defect - accept_order assigned orders.driver_id but never the
-- linked delivery ride, so the driver app (rides-backed deliveries view)
-- never saw the job. Propagate the assignment to the searching ride.

CREATE OR REPLACE FUNCTION public.accept_order(p_order_id uuid, p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order orders%ROWTYPE;
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF v_order.dispatch_status <> 'PENDING_DISPATCH' OR v_order.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'STALE', 'dispatch_status', v_order.dispatch_status);
  END IF;
  -- Non-owner callers may only accept an offer actually pending for their driver.
  IF NOT public._is_owner_uid(auth.uid()) AND NOT EXISTS (
    SELECT 1 FROM public.order_dispatch
     WHERE order_id = p_order_id
       AND candidate_driver_id = p_driver_id
       AND status IN ('pending', 'offered')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NO_PENDING_OFFER');
  END IF;
  UPDATE public.orders
    SET driver_id = p_driver_id, dispatch_status = 'ASSIGNED', status = 'preparing'
    WHERE id = p_order_id;
  UPDATE public.order_dispatch
    SET status = 'accepted', candidate_driver_id = p_driver_id, updated_at = now()
    WHERE order_id = p_order_id;
  -- The driver app works off the delivery ride: hand it the same assignment.
  UPDATE public.rides
     SET driver_id = p_driver_id, status = 'matched', accepted_at = now()
   WHERE order_id = p_order_id
     AND ride_type = 'delivery'
     AND status = 'searching';
  PERFORM public.log_admin_action('DISPATCH_ACCEPT', 'order', p_order_id::text,
    NULL, jsonb_build_object('driver', p_driver_id), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.accept_order(uuid, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.accept_order(uuid, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
