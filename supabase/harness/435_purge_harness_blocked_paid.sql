-- Case 4a single blocker: ONE paid pharmacy_delivery ride with
-- driver_earnings. Runs AFTER 431. Guard 1 must refuse.
BEGIN;
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('43500000-0000-4000-8000-0000000000e1', 'zz435-harness-rider@example.invalid', '{}'),
  ('43500000-0000-4000-8000-0000000000e2', 'zz435-harness-driver@example.invalid', '{}')
ON CONFLICT (id) DO NOTHING;
-- handle_new_user creates public.users rows; ensure they exist even if
-- the trigger is absent on the template DB.
INSERT INTO public.users (id, email) VALUES
  ('43500000-0000-4000-8000-0000000000e1', 'zz435-harness-rider@example.invalid'),
  ('43500000-0000-4000-8000-0000000000e2', 'zz435-harness-driver@example.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.drivers (id, user_id, full_name)
VALUES ('43500000-0000-4000-8000-0000000000e2', '43500000-0000-4000-8000-0000000000e2', '435 harness driver')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.rides (id, rider_id, driver_id, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, service_type, status, payment_method, payment_status)
VALUES ('43500000-0000-4000-8000-0000000000e3', '43500000-0000-4000-8000-0000000000e1', '43500000-0000-4000-8000-0000000000e2', 30.0, 31.0, 30.1, 31.1, 'pharmacy_delivery', 'completed', 'cash', 'paid');
INSERT INTO public.driver_earnings (id, driver_id, ride_id, amount)
VALUES (gen_random_uuid(), '43500000-0000-4000-8000-0000000000e2', '43500000-0000-4000-8000-0000000000e3', 25);
COMMIT;
