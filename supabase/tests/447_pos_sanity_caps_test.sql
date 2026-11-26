-- Suite for migration 447 (POS sanity caps: security batch 2 LOW1+LOW2).
-- Applied by supabase/harness/447_harness.sh AFTER 439..447 on a throwaway
-- clone of h435_template. Synthetic fixtures only. DISPOSABLE-DB-ONLY.

BEGIN;

create temporary table zz447(
  owner uuid, manager uuid, shop uuid, branch1 uuid, product1 uuid
);
insert into zz447 select gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
grant select on table zz447 to authenticated;
create temporary table zz447_ids(replay_op uuid);
insert into zz447_ids select gen_random_uuid();
grant select on table zz447_ids to authenticated;

insert into auth.users(id, email)
select u, 'zz447.' || n || '@example.invalid'
from (values ((select owner from zz447), 'owner'),
             ((select manager from zz447), 'manager')) as x(u, n);
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz447.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz447' || n, 'active'
from (values ((select owner from zz447), 'owner'),
             ((select manager from zz447), 'manager')) as x(u, n)
on conflict (id) do update set username = excluded.username, account_status = 'active';

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select shop from zz447), 'zz447-cafe', (select owner from zz447), 'cafe', 'active');
insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz447), (select shop from zz447), 'zz447-b1', true);
-- stock NULL: unlimited, so the cap (not stock) is what refuses big qty
insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity) values
  ((select product1 from zz447), (select shop from zz447), 'zz447-item', 'صنف', 100, NULL);

insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, is_active, must_change_password) values
  ((select shop from zz447), (select manager from zz447), 'zz447manager', 'Manager', 'branch_manager', (select branch1 from zz447), true, false);

UPDATE public.platform_settings
   SET feature_flags = '{"cashier_mode_mobile":true,"staff_accounts":true}'::jsonb
 WHERE id = 'default';

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);

  -- cash sales ride an open shift (446)
  PERFORM public.staff_shift_open(100);

  -- 1) catalog qty ABOVE the default cap refuses
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 10001)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',1000100)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: qty 10001 accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'catalog qty exceeds the 10000 cap', 'wrong error: ' || SQLERRM;
  END;

  -- 2) catalog qty AT the cap lands (10000 x 100 = 1,000,000 = total cap)
  v_res := public.staff_create_walk_in_sale(
    jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 10000)),
    jsonb_build_array(jsonb_build_object('method','cash','amount',1000000)),
    gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 1000000, 'qty-at-cap sale failed: ' || v_res::text;

  -- 3) two in-cap lines assemble an over-cap TOTAL and refuse
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(
        jsonb_build_object('product_id', v_pid, 'qty', 10000),
        jsonb_build_object('product_id', v_pid, 'qty', 10000)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',2000000)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: over-cap total accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sale total exceeds the 1000000 cap', 'wrong error: ' || SQLERRM;
  END;

  -- 4) custom label of 121 chars refuses
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(jsonb_build_object('custom', true, 'label', repeat('x', 121), 'price', 10, 'qty', 1)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',10)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: 121-char label accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom item label too long (max 120)', 'wrong error: ' || SQLERRM;
  END;

  -- 5) custom label of 120 chars lands (manager custom line)
  v_res := public.staff_create_walk_in_sale(
    jsonb_build_array(jsonb_build_object('custom', true, 'label', repeat('x', 120), 'price', 10, 'qty', 1)),
    jsonb_build_array(jsonb_build_object('method','cash','amount',10)),
    gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 10, '120-char label sale failed: ' || v_res::text;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);

-- 6) caps are flag-readable: tighten catalog_line_qty_cap to 5, no migration
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"catalog_line_qty_cap":5}'::jsonb
 WHERE id = 'default';
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 6)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',600)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: qty 6 accepted under a cap of 5';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'catalog qty exceeds the 5 cap', 'wrong error: ' || SQLERRM;
  END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);

-- 6b) 201 lines refuse at the request-size cap, whatever the lines are
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
  v_items jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);
  SELECT jsonb_agg(jsonb_build_object('product_id', v_pid, 'qty', 1))
    INTO v_items FROM generate_series(1, 201);
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      v_items,
      jsonb_build_array(jsonb_build_object('method','cash','amount',20100)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: 201 lines accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'too many lines (max 200)', 'wrong error: ' || SQLERRM;
  END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);

-- 7) sale_total_cap itself is tunable; over-cap refusal leaves NO rows
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"catalog_line_qty_cap":10000,"sale_total_cap":500}'::jsonb
 WHERE id = 'default';
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
  v_before int;
  v_op uuid := gen_random_uuid();
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);
  SELECT count(*) INTO v_before FROM public.pos_sales;
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 6)),
      jsonb_build_array(jsonb_build_object('method','cash','amount',600)),
      gen_random_uuid());
    RAISE EXCEPTION 'zz447 sentinel: total 600 accepted under a cap of 500';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz447 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sale total exceeds the 500 cap', 'wrong error: ' || SQLERRM;
  END;
  ASSERT (SELECT count(*) FROM public.pos_sales) = v_before,
    'over-cap refusal left mutations';

END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);

-- 8) a sale that LANDED before the cap drop still replays idempotently.
-- Flag fixture UPDATEs run as the service role (authenticated UPDATEs on
-- platform_settings are owner-guarded and silently no-op).
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"sale_total_cap":1000}'::jsonb
 WHERE id = 'default';
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);
  v_res := public.staff_create_walk_in_sale(
    jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 6)),
    jsonb_build_array(jsonb_build_object('method','cash','amount',600)),
    (SELECT replay_op FROM zz447_ids));
  ASSERT (v_res ->> 'total')::numeric = 600, 'in-cap sale failed: ' || v_res::text;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"sale_total_cap":500}'::jsonb
 WHERE id = 'default';
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_pid uuid := (SELECT product1 FROM zz447);
  v_before int;
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT manager FROM zz447))::text, true);
  SELECT count(*) INTO v_before FROM public.pos_sales;
  v_res := public.staff_create_walk_in_sale(
    jsonb_build_array(jsonb_build_object('product_id', v_pid, 'qty', 6)),
    jsonb_build_array(jsonb_build_object('method','cash','amount',600)),
    (SELECT replay_op FROM zz447_ids));
  ASSERT (v_res ->> 'idempotent_replay')::boolean IS TRUE,
    'replay after cap drop was not idempotent: ' || v_res::text;
  ASSERT (SELECT count(*) FROM public.pos_sales) = v_before,
    'replay wrote a second sale';
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);

SELECT '447 suite OK' AS marker;
ROLLBACK;
