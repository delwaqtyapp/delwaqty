-- Migration 160: expose the rider-provided recipient phone on the deliveries view.
--
-- Audit finding: drivers see a blank customer name whenever rides.recipient_name
-- is empty (the view's users join can never resolve under security_invoker RLS:
-- users is self+admin read-only) and have NO customer phone at all, so a driver
-- cannot call about a delivery. rides.recipient_name/recipient_phone are values
-- the RIDER provides exactly for the delivery contact, so exposing them to the
-- assigned driver carries no extra PII. The users fallback stays as-is for
-- roles that can read users (admin).
--
-- NOTE: the Dart DriverDelivery entity does not map customer_phone yet; the UI
-- half lands with the next app change batch (prompt #7 lineage).

CREATE OR REPLACE VIEW public.deliveries
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
   FROM rides r
     LEFT JOIN merchants m ON m.id = r.merchant_id
     LEFT JOIN users u ON u.id = r.rider_id
  WHERE r.ride_type = 'delivery'::text;
