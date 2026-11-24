-- Case 4b single blocker: ONE in-trip pharmacy_delivery ride. Runs
-- AFTER 431. Guard 1 must refuse (operational custody).
BEGIN;
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('43500000-0000-4000-8000-0000000000e1', 'zz435-harness-rider@example.invalid', '{}')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.users (id, email) VALUES
  ('43500000-0000-4000-8000-0000000000e1', 'zz435-harness-rider@example.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.rides (id, rider_id, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, service_type, status, payment_method, payment_status)
VALUES ('43500000-0000-4000-8000-0000000000e4', '43500000-0000-4000-8000-0000000000e1', 30.0, 31.0, 30.1, 31.1, 'pharmacy_delivery', 'inTrip', 'cash', 'pending');
COMMIT;
