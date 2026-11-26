-- Suite for migration 448 (DB hardening: anon surface reduction).
-- Applied by supabase/harness/448_harness.sh AFTER 439..448 on a throwaway
-- clone of h435_template. Synthetic fixtures only. DISPOSABLE-DB-ONLY.
--
-- Covers:
--   1. merchants.staff_settings is gone; merchant_staff_settings exists,
--      owner-only (RLS), no anon grant; shape + audit triggers re-pointed.
--   2. staff_create_walk_in_sale reads the custom-line gate from the new
--      table (cashier refused by default, allowed after the owner opts in
--      THROUGH the RLS owner write path).
--   3. anon holds no INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER anywhere in
--      public; guest read paths (merchants browse, provider view) work.
--   4. products: anon loses everything; authenticated keeps reading.
--   5. service_providers: anon base read refused; view serves anon with
--      rounded coords and no user_id; authenticated column trim;
--      get_my_provider_profile returns exact coords to the owner only.

BEGIN;

create temporary table zz448(
  owner uuid, cashier uuid, customer uuid, provider_user uuid,
  shop uuid, branch1 uuid, product1 uuid, provider uuid
);
insert into zz448 select gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
grant select on table zz448 to authenticated, anon;

insert into auth.users(id, email)
select u, 'zz448.' || n || '@example.invalid'
from (values ((select owner from zz448), 'owner'),
             ((select cashier from zz448), 'cashier'),
             ((select customer from zz448), 'customer'),
             ((select provider_user from zz448), 'provider')) as x(u, n);
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz448.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz448' || n, 'active'
from (values ((select owner from zz448), 'owner'),
             ((select cashier from zz448), 'cashier'),
             ((select customer from zz448), 'customer'),
             ((select provider_user from zz448), 'provider')) as x(u, n)
on conflict (id) do update set username = excluded.username, account_status = 'active';

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select shop from zz448), 'zz448-cafe', (select owner from zz448), 'cafe', 'active');
insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz448), (select shop from zz448), 'zz448-b1', true);
insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity) values
  ((select product1 from zz448), (select shop from zz448), 'zz448-item', 'صنف', 100, NULL);
insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, is_active, must_change_password) values
  ((select shop from zz448), (select cashier from zz448), 'zz448cashier', 'Cashier', 'cashier', (select branch1 from zz448), true, false);
insert into public.service_providers(id, user_id, name, category_type, is_available, latitude, longitude) values
  ((select provider from zz448), (select provider_user from zz448), 'zz448-plumber', 'plumbing',
   true, 30.0444196, 31.2357116);

UPDATE public.platform_settings
   SET feature_flags = '{"cashier_mode_mobile":true,"staff_accounts":true}'::jsonb
 WHERE id = 'default';

-- ─── 1. the column moved ──────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM pg_attribute
                     WHERE attrelid = 'public.merchants'::regclass
                       AND attname = 'staff_settings' AND NOT attisdropped),
    'merchants.staff_settings still present';
  ASSERT (SELECT relrowsecurity FROM pg_class
          WHERE oid = 'public.merchant_staff_settings'::regclass),
    'merchant_staff_settings RLS off';
  ASSERT NOT has_table_privilege('anon', 'public.merchant_staff_settings', 'SELECT'),
    'anon can read merchant_staff_settings';
END $$;

-- ─── 2. shape trigger on the new table (as superuser fixture writes) ─────
DO $$
BEGIN
  BEGIN
    INSERT INTO public.merchant_staff_settings (merchant_id, settings)
    VALUES ((SELECT shop FROM zz448), '[]'::jsonb);
    RAISE EXCEPTION 'zz448 sentinel: array settings accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff_settings must be an object', 'wrong error: ' || SQLERRM;
  END;
  BEGIN
    INSERT INTO public.merchant_staff_settings (merchant_id, settings)
    VALUES ((SELECT shop FROM zz448), '{"nope": true}'::jsonb);
    RAISE EXCEPTION 'zz448 sentinel: unknown key accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'unknown staff_settings key%', 'wrong error: ' || SQLERRM;
  END;
  BEGIN
    INSERT INTO public.merchant_staff_settings (merchant_id, settings)
    VALUES ((SELECT shop FROM zz448), '{"cashier_custom_lines": "yes"}'::jsonb);
    RAISE EXCEPTION 'zz448 sentinel: non-boolean accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'staff_settings.% must be a boolean', 'wrong error: ' || SQLERRM;
  END;
END $$;

-- ─── 3. owner write path through RLS + audit trigger ─────────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_first timestamptz;
  v_second timestamptz;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz448))::text, true);
  -- real first opt-in: INSERT with the gate ON, no prior row
  INSERT INTO public.merchant_staff_settings (merchant_id, settings)
  VALUES ((SELECT shop FROM zz448), '{"cashier_custom_lines": true}'::jsonb);
  SELECT updated_at INTO v_first FROM public.merchant_staff_settings
   WHERE merchant_id = (SELECT shop FROM zz448);
  PERFORM pg_sleep(0.05);
  UPDATE public.merchant_staff_settings
     SET settings = '{"cashier_custom_lines": true}'::jsonb
   WHERE merchant_id = (SELECT shop FROM zz448);
  ASSERT FOUND, 'owner update through RLS did not land';
  SELECT updated_at INTO v_second FROM public.merchant_staff_settings
   WHERE merchant_id = (SELECT shop FROM zz448);
  ASSERT v_second > v_first, 'updated_at did not advance on update';
END $$;
RESET ROLE;

DO $$
DECLARE
  v_insert_payload jsonb;
  v_update_payload jsonb;
BEGIN
  -- the FIRST INSERT ({} -> true) is audited with old NULL
  SELECT detail INTO v_insert_payload FROM public.merchant_staff_events
   WHERE kind = 'staff_settings_changed'
     AND merchant_id = (SELECT shop FROM zz448)
     AND detail -> 'old' = 'null'::jsonb
   ORDER BY created_at ASC LIMIT 1;
  ASSERT v_insert_payload IS NOT NULL, 'first opt-in INSERT was not audited';
  ASSERT v_insert_payload -> 'new' ->> 'cashier_custom_lines' = 'true',
    'insert audit payload wrong: ' || v_insert_payload::text;
  -- the later no-change UPDATE (true -> true) adds no event
  ASSERT (SELECT count(*) FROM public.merchant_staff_events
          WHERE kind = 'staff_settings_changed'
            AND merchant_id = (SELECT shop FROM zz448)) = 1,
    'no-change update should not be audited';
END $$;

-- ─── 4. customer (non-owner) cannot read or write it ─────────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_n int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT customer FROM zz448))::text, true);
  SELECT count(*) INTO v_n FROM public.merchant_staff_settings
   WHERE merchant_id = (SELECT shop FROM zz448);
  ASSERT v_n = 0, 'customer read another merchant''s staff settings';
  BEGIN
    INSERT INTO public.merchant_staff_settings (merchant_id, settings)
    VALUES ((SELECT shop FROM zz448), '{"cashier_custom_lines": true}'::jsonb);
    RAISE EXCEPTION 'zz448 sentinel: customer insert accepted';
  EXCEPTION WHEN insufficient_privilege OR raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
  UPDATE public.merchant_staff_settings
     SET settings = '{"cashier_custom_lines": false}'::jsonb
   WHERE merchant_id = (SELECT shop FROM zz448);
  ASSERT NOT FOUND, 'customer update matched a row';
END $$;
RESET ROLE;

-- ─── 5. the walk-in-sale gate reads the new table ─────────────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz448);
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz448))::text, true);
  PERFORM public.staff_shift_open(100);
  -- owner opted in above (settings.cashier_custom_lines = true): a small
  -- custom line now lands for a cashier with an open shift.
  v_res := public.staff_create_walk_in_sale(
    jsonb_build_array(jsonb_build_object('custom', true, 'label', 'zz448 delivery fix', 'price', 10, 'qty', 1)),
    jsonb_build_array(jsonb_build_object('method','cash','amount',10)),
    gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 10, 'opted-in custom line failed: ' || v_res::text;

  -- flip the gate off through the owner path: the next custom line refuses.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz448))::text, true);
  UPDATE public.merchant_staff_settings
     SET settings = '{"cashier_custom_lines": false}'::jsonb
   WHERE merchant_id = (SELECT shop FROM zz448);
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz448))::text, true);
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(jsonb_build_object('custom', true, 'label', 'zz448 second fix', 'price', 10, 'qty', 1)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',10)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz448 sentinel: custom line accepted with gate off';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines need a branch manager', 'wrong error: ' || SQLERRM;
  END;
END $$;
RESET ROLE;

-- ─── 6. anon sweep: no write-class privileges anywhere in public ─────────
DO $$
DECLARE
  v_bad text;
BEGIN
  SELECT string_agg(table_name || ':' || privilege_type, ',') INTO v_bad
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND grantee = 'anon'
    AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE','TRIGGER');
  ASSERT v_bad IS NULL, 'anon still holds write-class grants: ' || v_bad;
END $$;

-- ─── 7. guest read paths keep working ─────────────────────────────────────
SET LOCAL ROLE anon;
DO $$
DECLARE
  v_n int;
  v_row record;
BEGIN
  PERFORM set_config('request.jwt.claims', '{}', true);
  -- guest merchant browse: the installed customer app wildcard-selects,
  -- so prove SELECT m.* itself works as anon (not just count(*))
  SELECT m.* INTO v_row FROM public.merchants m WHERE status = 'active' LIMIT 1;
  ASSERT v_row.id IS NOT NULL, 'anon merchant wildcard read broke';
  -- guest provider browse through the definer view
  SELECT count(*) INTO v_n FROM public.service_providers_with_effective_pricing;
  ASSERT v_n >= 1, 'anon provider view read broke';
  -- the view must not expose user_id, and coords are rounded to 2dp
  SELECT * INTO v_row FROM public.service_providers_with_effective_pricing
   WHERE id = (SELECT provider FROM zz448);
  ASSERT v_row.latitude = 30.04 AND v_row.longitude = 31.24,
    'coords not rounded: ' || v_row.latitude || ',' || v_row.longitude;
  BEGIN
    PERFORM user_id FROM public.service_providers_with_effective_pricing LIMIT 1;
    RAISE EXCEPTION 'zz448 sentinel: view still exposes user_id';
  EXCEPTION WHEN undefined_column THEN NULL;
            WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
  -- anon base-table reads of service_providers and products are refused
  BEGIN
    PERFORM count(*) FROM public.service_providers;
    RAISE EXCEPTION 'zz448 sentinel: anon read service_providers';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
            WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM count(*) FROM public.products;
    RAISE EXCEPTION 'zz448 sentinel: anon read products';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
            WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
  -- anon writes are refused (RLS-free proof: privilege error, not 0 rows)
  BEGIN
    INSERT INTO public.merchants(id, name, type, status)
    VALUES (gen_random_uuid(), 'zz448-anon', 'cafe', 'active');
    RAISE EXCEPTION 'zz448 sentinel: anon inserted merchants';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
            WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ─── 7b. owner sees own UNAVAILABLE row; nobody else does ───────────────
UPDATE public.service_providers SET is_available = false
 WHERE id = (SELECT provider FROM zz448);

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_n int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT provider_user FROM zz448))::text, true);
  SELECT count(*) INTO v_n FROM public.service_providers_with_effective_pricing
   WHERE id = (SELECT provider FROM zz448);
  ASSERT v_n = 1, 'owner lost their unavailable provider row';

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT customer FROM zz448))::text, true);
  SELECT count(*) INTO v_n FROM public.service_providers_with_effective_pricing
   WHERE id = (SELECT provider FROM zz448);
  ASSERT v_n = 0, 'other user saw an unavailable provider';
END $$;
RESET ROLE;

SET LOCAL ROLE anon;
DO $$
DECLARE
  v_n int;
BEGIN
  PERFORM set_config('request.jwt.claims', '{}', true);
  SELECT count(*) INTO v_n FROM public.service_providers_with_effective_pricing
   WHERE id = (SELECT provider FROM zz448);
  ASSERT v_n = 0, 'anon saw an unavailable provider';
END $$;
RESET ROLE;

UPDATE public.service_providers SET is_available = true
 WHERE id = (SELECT provider FROM zz448);

-- ─── 8. authenticated trims on service_providers ──────────────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_n int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT provider_user FROM zz448))::text, true);
  -- provider app capability check keeps working (category_type + user_id
  -- filter + created_at ordering are exactly the granted columns)
  SELECT count(*) INTO v_n FROM (
    SELECT category_type FROM public.service_providers
     WHERE user_id = (SELECT provider_user FROM zz448)
     ORDER BY created_at LIMIT 1) s;
  ASSERT v_n = 1, 'provider capability read broke';
  -- ...but lat/lng left the signed-in surface
  BEGIN
    PERFORM latitude FROM public.service_providers LIMIT 1;
    RAISE EXCEPTION 'zz448 sentinel: authenticated read provider latitude';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
            WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz448 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ─── 9. get_my_provider_profile: owner only, exact coords ────────────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_profile jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT provider_user FROM zz448))::text, true);
  v_profile := public.get_my_provider_profile();
  ASSERT v_profile IS NOT NULL, 'owner got NULL profile';
  ASSERT (v_profile ->> 'latitude')::numeric = 30.0444196,
    'owner did not get exact coords: ' || v_profile ->> 'latitude';

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT customer FROM zz448))::text, true);
  v_profile := public.get_my_provider_profile();
  ASSERT v_profile IS NULL, 'non-provider got a provider profile';
END $$;
RESET ROLE;

-- ─── 10. products: authenticated (merchant dashboard) still reads ─────────
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_n int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz448))::text, true);
  SELECT count(*) INTO v_n FROM public.products
   WHERE merchant_id = (SELECT shop FROM zz448);
  ASSERT v_n = 1, 'merchant app product read broke';
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claims', '{}', true);

SELECT '448 suite OK' AS marker;
ROLLBACK;
