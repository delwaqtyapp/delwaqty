-- 134_driver_deliveries_glue.sql
-- Mechanism audit: the driver app's delivery features read/write a
-- `deliveries` relation that never existed (PostgREST PGRST205), so the
-- driver hub / earnings / delivery detail screens were dead. The dispatch
-- engine writes deliveries into public.rides (ride_type='delivery') but
-- (a) never stored the order_id on the ride, so delivery completion could
-- never update the order, and (b) the app vocabulary (pending/accepted/
-- picked_up/delivered) never mapped to the rides vocabulary
-- (searching/matched/inTrip/completed).
--
-- This migration:
--   1. adds rides.order_id and patches merchant_dispatch_order_driver to
--      store it (and to dedupe per-order instead of per merchant+rider),
--   2. creates the public.deliveries compatibility view (security_invoker)
--      with the app's column set and status translation,
--   3. adds an INSTEAD OF UPDATE trigger (security definer, validates the
--      caller owns a driver profile) that maps app writes onto rides and
--      syncs the linked order's status/dispatch_status,
--   4. notifies the driver when a delivery is assigned to them,
--   5. replaces the wide-open rides write policies (qual=true FOR ALL)
--      with scoped ones; all real writes go through security-definer RPCs.

-- 1. order link --------------------------------------------------------------
ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS rides_order_id_idx ON public.rides(order_id);
CREATE INDEX IF NOT EXISTS rides_delivery_status_idx
  ON public.rides(status) WHERE ride_type = 'delivery';

-- 2. dispatch function: store + dedupe by order_id ----------------------------
CREATE OR REPLACE FUNCTION public.merchant_dispatch_order_driver(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_order
    FROM public.orders
   WHERE id = p_order_id;

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

  v_pickup_lat := COALESCE(v_merchant.latitude, 30.0444);
  v_pickup_lng := COALESCE(v_merchant.longitude, 31.2357);
  v_dropoff_lat := COALESCE(v_order.delivery_latitude, v_pickup_lat + 0.01);
  v_dropoff_lng := COALESCE(v_order.delivery_longitude, v_pickup_lng + 0.01);

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
      'delivery',
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

  -- Trigger driver dispatch if dispatch_delivery RPC exists
  BEGIN
    PERFORM public.dispatch_delivery(v_ride_id, 25.0, 15);
  EXCEPTION WHEN OTHERS THEN
    -- Ignore if no nearby drivers found immediately; ride remains 'searching'
    NULL;
  END;

  UPDATE public.orders
     SET dispatch_status = 'searching',
         status = CASE
           WHEN status IN ('pending', 'confirmed', 'accepted', 'preparing') THEN 'ready'
           ELSE status
         END,
         updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', p_order_id,
    'ride_id', v_ride_id,
    'dispatch_status', 'searching'
  );
END;
$$;

-- 3. compatibility view -------------------------------------------------------
CREATE OR REPLACE VIEW public.deliveries
WITH (security_invoker = true) AS
SELECT
  r.id,
  r.order_id,
  r.driver_id,
  COALESCE(m.name, '') AS merchant_name,
  COALESCE(NULLIF(r.pickup_address, ''), COALESCE(m.address, '')) AS merchant_address,
  COALESCE(r.recipient_name, u.full_name, '') AS customer_name,
  COALESCE(r.dropoff_address, '') AS delivery_address,
  r.dropoff_latitude AS customer_latitude,
  r.dropoff_longitude AS customer_longitude,
  CASE r.status
    WHEN 'searching' THEN 'pending'
    WHEN 'matched' THEN 'accepted'
    WHEN 'arrived' THEN 'arrived'
    WHEN 'inTrip' THEN 'picked_up'
    WHEN 'completed' THEN 'delivered'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE r.status
  END AS status,
  r.fare AS delivery_fee,
  COALESCE(r.delivery_notes, r.dropoff_notes) AS notes,
  r.created_at,
  r.accepted_at,
  r.picked_up_at,
  r.delivered_at
FROM public.rides r
LEFT JOIN public.merchants m ON m.id = r.merchant_id
LEFT JOIN public.users u ON u.id = r.rider_id
WHERE r.ride_type = 'delivery';

GRANT SELECT, UPDATE ON public.deliveries TO authenticated;

-- 4. INSTEAD OF UPDATE: map app writes onto rides -----------------------------
CREATE OR REPLACE FUNCTION public.deliveries_view_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver uuid;
  v_new_status text;
BEGIN
  SELECT id INTO v_driver
    FROM public.drivers
   WHERE user_id = auth.uid()
   LIMIT 1;
  IF v_driver IS NULL THEN
    RAISE EXCEPTION 'Not a driver';
  END IF;

  -- Rejecting an unassigned available delivery must not kill it for other
  -- drivers; rejecting one the caller had accepted hands it back.
  IF NEW.status = 'rejected' THEN
    UPDATE public.rides
       SET driver_id = NULL,
           status = 'searching',
           delivery_status = 'searching',
           accepted_at = NULL,
           updated_at = now()
     WHERE id = OLD.id
       AND driver_id = v_driver;
    RETURN NEW;
  END IF;

  v_new_status := CASE NEW.status
    WHEN 'accepted' THEN 'matched'
    WHEN 'picked_up' THEN 'inTrip'
    WHEN 'delivered' THEN 'completed'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE NULL
  END;

  UPDATE public.rides
     SET status = COALESCE(v_new_status, status),
         delivery_status = COALESCE(v_new_status, delivery_status),
         driver_id = CASE
           WHEN NEW.status = 'accepted' THEN v_driver
           ELSE driver_id
         END,
         accepted_at = COALESCE(NEW.accepted_at, accepted_at),
         picked_up_at = COALESCE(NEW.picked_up_at, picked_up_at),
         delivered_at = COALESCE(NEW.delivered_at, delivered_at)
   WHERE id = OLD.id
     AND ride_type = 'delivery'
     AND (driver_id IS NULL OR driver_id = v_driver);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Delivery unavailable or assigned to another driver';
  END IF;

  -- Sync the linked order through its allowed status vocabulary.
  IF v_new_status = 'matched' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders
       SET dispatch_status = 'ASSIGNED', updated_at = now()
     WHERE id = OLD.order_id;
  ELSIF v_new_status = 'inTrip' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders
       SET status = 'delivering', dispatch_status = 'ACCEPTED', updated_at = now()
     WHERE id = OLD.order_id;
  ELSIF v_new_status = 'completed' AND OLD.order_id IS NOT NULL THEN
    UPDATE public.orders
       SET status = 'delivered', dispatch_status = 'ACCEPTED', updated_at = now()
     WHERE id = OLD.order_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS deliveries_view_update ON public.deliveries;
CREATE TRIGGER deliveries_view_update
  INSTEAD OF UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION public.deliveries_view_update();

-- 5. driver assignment notification ------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_driver_delivery_assigned()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  IF NEW.ride_type = 'delivery'
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
$$;

DROP TRIGGER IF EXISTS notify_driver_delivery_assigned ON public.rides;
CREATE TRIGGER notify_driver_delivery_assigned
  AFTER UPDATE OF driver_id ON public.rides
  FOR EACH ROW EXECUTE FUNCTION public.notify_driver_delivery_assigned();

-- 6. rides write-policy hardening --------------------------------------------
-- Real writes flow through security-definer RPCs (dispatch engine) and the
-- deliveries view trigger above. Replace the qual=true FOR ALL policies.
DROP POLICY IF EXISTS "rides rider write" ON public.rides;
DROP POLICY IF EXISTS "Riders can create rides" ON public.rides;

CREATE POLICY "riders insert own rides" ON public.rides
  FOR INSERT TO authenticated
  WITH CHECK (rider_id = auth.uid());

CREATE POLICY "riders update own rides" ON public.rides
  FOR UPDATE TO authenticated
  USING (rider_id = auth.uid())
  WITH CHECK (rider_id = auth.uid());
