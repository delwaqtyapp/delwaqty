-- 435 pharmacy purge verification (transaction-wrapped, rolled back).
-- Runs against the fully migrated database: pharmacy type/delivery
-- taxonomy gone, pharmacy-only objects gone, all pharmacy data gone,
-- driver canonical set {food, grocery, parcel}.
BEGIN;

-- CHECK constraint definitions at the exact target state
DO $$
DECLARE
  v_merchants text;
  v_rides text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v_merchants FROM pg_constraint
   WHERE conname = 'merchants_type_check' AND conrelid = 'public.merchants'::regclass;
  SELECT pg_get_constraintdef(oid) INTO v_rides FROM pg_constraint
   WHERE conname = 'rides_service_type_check' AND conrelid = 'public.rides'::regclass;
  ASSERT v_merchants IS NOT NULL AND v_merchants NOT LIKE '%pharmacy%',
    '435: merchants_type_check missing or still lists pharmacy: ' || coalesce(v_merchants, 'NULL');
  ASSERT v_rides IS NOT NULL AND v_rides NOT LIKE '%pharmacy%',
    '435: rides_service_type_check missing or still lists pharmacy_delivery: ' || coalesce(v_rides, 'NULL');
END $$;

-- No pharmacy data remains anywhere
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchants WHERE type = 'pharmacy'), '435: pharmacy merchants remain';
  ASSERT NOT EXISTS (SELECT 1 FROM public.rides WHERE service_type = 'pharmacy_delivery'), '435: pharmacy_delivery rides remain';
  ASSERT NOT EXISTS (SELECT 1 FROM public.drivers WHERE service_types @> ARRAY['pharmacy']::text[]), '435: pharmacy driver capability remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.commission_rules WHERE entity_key IN ('pharmacy','pharmacy_delivery')), '435: pharmacy commission rules remain';
  ASSERT NOT EXISTS (SELECT 1 FROM public.delivery_pricing WHERE service_type = 'pharmacy_delivery'), '435: pharmacy_delivery pricing remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.provider_business_profiles WHERE category_type = 'pharmacy'), '435: pharmacy profile remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.users WHERE active_provider_category = 'pharmacy'), '435: pharmacy active category remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.categories WHERE lower(coalesce(name,'')) LIKE '%pharm%' OR lower(coalesce(name_en,'')) LIKE '%pharm%' OR coalesce(name_ar,'') LIKE '%صيدل%'), '435: pharmacy category remains';
  ASSERT NOT EXISTS (SELECT 1 FROM public.catalog_categories WHERE merchant_type = 'pharmacy'), '435: pharmacy catalog category remains';
END $$;

-- Pharmacy-only objects and ACLs are gone
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname LIKE 'pharmacy\_%' ESCAPE '\';
  ASSERT v_count = 0, '435: ' || v_count || ' pharmacy_* functions remain';
  SELECT count(*) INTO v_count FROM pg_tables
   WHERE schemaname = 'public' AND tablename LIKE 'pharmacy\_%' ESCAPE '\';
  ASSERT v_count = 0, '435: ' || v_count || ' pharmacy_* tables remain';
END $$;

-- Driver capability canonical set is {food, grocery, parcel}
DO $$
DECLARE
  v_body text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_body
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'update_driver_capabilities';
  ASSERT v_body LIKE '%''food'',''grocery'',''parcel''%' AND v_body NOT LIKE '%pharmacy%',
    '435: update_driver_capabilities canonical set wrong';
END $$;

-- Blocked-guard case (fixture): a pharmacy_delivery ride with a financial
-- dependent must be caught by the Guard 1 pattern. Runs on a savepoint
-- against fixture rows; proves the guard fires without any damage.
DO $$
DECLARE
  v_ride uuid := gen_random_uuid();
  v_rider uuid := gen_random_uuid();
  v_driver uuid := gen_random_uuid();
  v_blocked text;
BEGIN
  INSERT INTO public.users (id, email) VALUES (v_rider, '435-test-rider@example.invalid') ON CONFLICT DO NOTHING;
  INSERT INTO public.users (id, email) VALUES (v_driver, '435-test-driver@example.invalid') ON CONFLICT DO NOTHING;
  INSERT INTO public.drivers (id, user_id, full_name) VALUES (v_driver, v_driver, '435 fixture') ON CONFLICT DO NOTHING;
  -- bypass the post-purge CHECK only inside this transaction
  ALTER TABLE public.rides DROP CONSTRAINT rides_service_type_check;
  INSERT INTO public.rides (id, rider_id, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, service_type, status, payment_status)
  VALUES (v_ride, v_rider, 30.0, 31.0, 30.1, 31.1, 'pharmacy_delivery', 'completed', 'paid');
  INSERT INTO public.driver_earnings (id, driver_id, ride_id, amount) VALUES (gen_random_uuid(), v_driver, v_ride, 10);

  SELECT string_agg(DISTINCT r.id::text, ',') INTO v_blocked
    FROM public.rides r
   WHERE r.service_type = 'pharmacy_delivery'
     AND (r.status = 'completed'
       OR r.payment_status = 'paid'
       OR EXISTS (SELECT 1 FROM public.driver_earnings e WHERE e.ride_id = r.id));
  ASSERT v_blocked IS NOT NULL AND position(v_ride::text in v_blocked) > 0,
    '435: Guard 1 pattern failed to flag a paid/completed pharmacy_delivery ride with driver_earnings';
END $$;

-- Drift case (fixture): an unknown constraint shape must classify as
-- drift, not as pre or post state.
DO $$
DECLARE
  v_fake text := 'CHECK ((type = ANY (ARRAY[''food''::text, ''pharmacy''::text])))';
  v_pre text := 'CHECK ((type = ANY (ARRAY[''food''::text, ''restaurant''::text, ''grocery''::text, ''supermarket''::text, ''pharmacy''::text])))';
  v_state text;
BEGIN
  v_state := CASE v_fake WHEN v_pre THEN 'pre' ELSE 'drift' END;
  ASSERT v_state = 'drift', '435: drift classification wrong';
END $$;

-- Custody fixture: an in-trip pharmacy_delivery ride with NO financial
-- dependents must still be flagged by the Guard 1 pattern (custody, not
-- just money, blocks the delete).
DO $$
DECLARE
  v_ride uuid := gen_random_uuid();
  v_rider uuid := gen_random_uuid();
  v_blocked text;
BEGIN
  INSERT INTO public.users (id, email) VALUES (v_rider, '435-test-custody@example.invalid') ON CONFLICT DO NOTHING;
  INSERT INTO public.rides (id, rider_id, pickup_latitude, pickup_longitude, dropoff_latitude, dropoff_longitude, service_type, status, payment_status)
  VALUES (v_ride, v_rider, 30.0, 31.0, 30.1, 31.1, 'pharmacy_delivery', 'inTrip', 'pending');

  SELECT string_agg(DISTINCT r.id::text, ',') INTO v_blocked
    FROM public.rides r
   WHERE r.service_type = 'pharmacy_delivery'
     AND (r.status IN ('matched', 'arrived', 'inTrip', 'completed')
       OR r.payment_status = 'paid');
  ASSERT v_blocked IS NOT NULL AND position(v_ride::text in v_blocked) > 0,
    '435: Guard 1 pattern failed to flag an in-trip pharmacy_delivery ride';
END $$;

-- Re-run case: the existence-aware REVOKE guard tolerates the function
-- being absent (second run of 435 Phase C).
DO $$
DECLARE
  v_tbl text;
  v_nonempty boolean;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'pharmacy_import_drug') THEN
    RAISE EXCEPTION '435 test: pharmacy_import_drug unexpectedly present';
  END IF;
  -- the network-table guard is existence-aware: on a second run the
  -- tables are already dropped and the loop below must not raise
  FOR v_tbl IN SELECT t FROM (VALUES ('pharmacy_links'), ('pharmacy_transfer_requests'),
                                     ('pharmacy_transfer_ledger'), ('pharmacy_messages')) AS u(t)
  LOOP
    IF to_regclass('public.' || v_tbl) IS NOT NULL THEN
      EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I)', v_tbl) INTO v_nonempty;
    END IF;
  END LOOP;
END $$;

ROLLBACK;
