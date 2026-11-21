-- 216: E2E defect - the deliveries view filtered ride_type='delivery', but the
-- four-type fleet model (140) stores the VEHICLE type in ride_type, so
-- order-linked delivery rides never appeared in the driver app.
DROP TRIGGER IF EXISTS deliveries_view_update ON public.deliveries;
DROP VIEW IF EXISTS public.deliveries;
CREATE VIEW public.deliveries
WITH (security_invoker = true) AS
 SELECT r.id,
    r.order_id,
    r.driver_id,
    COALESCE(m.name, ''::text) AS merchant_name,
    COALESCE(NULLIF(r.pickup_address, ''::text), COALESCE(m.address, ''::text)) AS merchant_address,
    COALESCE(r.recipient_name, u.full_name, ''::text) AS customer_name,
    COALESCE(r.dropoff_address, ''::text) AS delivery_address,
    r.dropoff_latitude AS customer_latitude,
    r.dropoff_longitude AS customer_longitude,
        CASE r.status
            WHEN 'searching'::text THEN 'pending'::text
            WHEN 'matched'::text THEN 'accepted'::text
            WHEN 'arrived'::text THEN 'arrived'::text
            WHEN 'inTrip'::text THEN 'picked_up'::text
            WHEN 'completed'::text THEN 'delivered'::text
            WHEN 'cancelled'::text THEN 'cancelled'::text
            ELSE r.status
        END AS status,
    r.fare AS delivery_fee,
    COALESCE(r.delivery_notes, r.dropoff_notes) AS notes,
    r.created_at,
    r.accepted_at,
    r.picked_up_at,
    r.delivered_at,
    COALESCE(r.recipient_phone, u.phone, ''::text) AS customer_phone
   FROM ((rides r
     LEFT JOIN merchants m ON ((m.id = r.merchant_id)))
     LEFT JOIN users u ON ((u.id = r.rider_id)))
  WHERE (r.ride_type = 'delivery'::text) OR (r.order_id IS NOT NULL);

REVOKE ALL ON public.deliveries FROM public, anon, authenticated;
GRANT SELECT ON public.deliveries TO authenticated;
GRANT UPDATE ON public.deliveries TO authenticated;

CREATE TRIGGER deliveries_view_update INSTEAD OF UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION deliveries_view_update();

NOTIFY pgrst, 'reload schema';

-- Fix trigger: rides.delivery_status is an enum; COALESCE mixed text/enum (42804)
-- and 'inTrip' is not an enum member. Map view statuses explicitly per column.
CREATE OR REPLACE FUNCTION public.deliveries_view_update()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_driver uuid;
  v_ride_status text;
  v_delivery_status public.delivery_status;
BEGIN
  SELECT id INTO v_driver FROM public.drivers WHERE user_id = auth.uid() LIMIT 1;
  IF v_driver IS NULL THEN RAISE EXCEPTION 'Not a driver'; END IF;

  IF NEW.status = 'rejected' THEN
    UPDATE public.rides
       SET driver_id = NULL, status = 'searching', delivery_status = 'searching',
           accepted_at = NULL
     WHERE id = OLD.id AND driver_id = v_driver;
    RETURN NEW;
  END IF;

  v_ride_status := CASE NEW.status
    WHEN 'accepted' THEN 'matched'
    WHEN 'arrived' THEN 'arrived'
    WHEN 'picked_up' THEN 'inTrip'
    WHEN 'delivered' THEN 'completed'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE NULL END;
  v_delivery_status := CASE NEW.status
    WHEN 'accepted' THEN 'matched'::public.delivery_status
    WHEN 'arrived' THEN 'arrived'::public.delivery_status
    WHEN 'picked_up' THEN 'picked_up'::public.delivery_status
    WHEN 'delivered' THEN 'delivered'::public.delivery_status
    WHEN 'cancelled' THEN 'cancelled'::public.delivery_status
    ELSE NULL END;

  UPDATE public.rides
     SET status = COALESCE(v_ride_status, status),
         delivery_status = COALESCE(v_delivery_status, delivery_status),
         driver_id = CASE WHEN NEW.status = 'accepted' THEN v_driver ELSE driver_id END,
         accepted_at = COALESCE(NEW.accepted_at, accepted_at),
         picked_up_at = CASE WHEN v_ride_status = 'inTrip' THEN COALESCE(NEW.picked_up_at, now()) ELSE COALESCE(NEW.picked_up_at, picked_up_at) END,
         delivered_at = CASE WHEN v_ride_status = 'completed' THEN COALESCE(NEW.delivered_at, now()) ELSE COALESCE(NEW.delivered_at, delivered_at) END
   WHERE id = OLD.id
     AND (driver_id IS NULL OR driver_id = v_driver);

  IF NOT FOUND THEN RAISE EXCEPTION 'Delivery unavailable or assigned to another driver'; END IF;

  IF v_ride_status = 'matched' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders SET dispatch_status = 'ASSIGNED', updated_at = now() WHERE id = OLD.order_id;
  ELSIF v_ride_status = 'inTrip' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders SET status = 'delivering', dispatch_status = 'ACCEPTED', updated_at = now() WHERE id = OLD.order_id;
  ELSIF v_ride_status = 'completed' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders SET status = 'delivered', dispatch_status = 'ACCEPTED', updated_at = now() WHERE id = OLD.order_id;
  END IF;

  RETURN NEW;
END;
$function$;
