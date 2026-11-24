-- 430: rides INSERT guard (code review #150, #151).
--
-- Problem: the "riders insert own rides" / "riders update own rides"
-- policies let any authenticated client INSERT rides rows with arbitrary
-- fare/payment fields and link them to someone else's order via a
-- caller-supplied order_id (then mutate that order through
-- sync_linked_delivery_order).
--
-- Fix (security-reviewer preferred design): the client can no longer
-- write rides directly at all. Creation happens only through SECURITY
-- DEFINER RPCs that set rider_id, service_type and every money field
-- server-side. The ask-anything courier flow gets a dedicated
-- request_courier_delivery RPC that preserves the product's fare-NULL
-- semantics (drivers quote later) while making fare/payment/order_id/
-- merchant_id impossible for the caller to supply.
--
-- UPDATE stays granted to authenticated solely for the admin app, which
-- the "Admins can update any ride" policy gates; with the rider policies
-- dropped, no other authenticated UPDATE path remains.

BEGIN;

DROP POLICY IF EXISTS "riders insert own rides" ON public.rides;
DROP POLICY IF EXISTS "riders update own rides" ON public.rides;

REVOKE INSERT ON public.rides FROM anon, authenticated;
REVOKE UPDATE ON public.rides FROM anon;

CREATE OR REPLACE FUNCTION public.request_courier_delivery(
  p_pickup_latitude numeric,
  p_pickup_longitude numeric,
  p_pickup_address text,
  p_dropoff_latitude numeric,
  p_dropoff_longitude numeric,
  p_dropoff_address text,
  p_items_summary text DEFAULT NULL,
  p_dropoff_notes text DEFAULT NULL,
  p_priority text DEFAULT 'standard'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_delivery_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  IF p_pickup_latitude IS NULL OR p_pickup_longitude IS NULL
     OR p_dropoff_latitude IS NULL OR p_dropoff_longitude IS NULL
     OR p_dropoff_address IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  IF p_priority NOT IN ('standard', 'priority', 'express') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  -- Every field is server-controlled: rider from the JWT, service_type
  -- fixed, fare/payment/currency at column defaults, order_id and
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
    NULL, NULL, NULL
  ) RETURNING id INTO v_delivery_id;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_id', v_delivery_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.request_courier_delivery(numeric, numeric, text, numeric, numeric, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_courier_delivery(numeric, numeric, text, numeric, numeric, text, text, text, text) TO authenticated;

COMMIT;
