-- Suite for migration 442 (shop staff + branch scope, dark), round 2:
-- code findings #249-#257 + security S1-S12.
-- Applied by supabase/harness/442_harness.sh AFTER 439 + 440 + 441 + 442
-- on a throwaway clone of h435_template. Synthetic fixtures only:
-- @example.invalid emails, zz442-* usernames, never real accounts.
-- DISPOSABLE-DATABASE-ONLY. Every expected-refusal block uses the
-- sentinel idiom AND asserts the intended error text (#257).

BEGIN;

create temporary table zz442(
  owner uuid, mgr uuid, cashier uuid, kitchen uuid, cashier_b2 uuid, outsider uuid, pwstaff uuid,
  merchant uuid, other_merchant uuid, branch1 uuid, branch2 uuid, other_branch uuid,
  product uuid, product2 uuid, other_product uuid, unavail_product uuid, untracked_product uuid,
  customer uuid, other_customer uuid,
  order1 uuid, order2 uuid, other_order uuid, order_null uuid
);
insert into zz442 select
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid();

-- The suite flips to the authenticated role below; let it read the fixtures.
grant select on table zz442 to authenticated;

insert into auth.users(id, email)
select u, 'zz442.' || n || '@example.invalid'
from (values
  ((select owner from zz442), 'owner'), ((select mgr from zz442), 'mgr'),
  ((select cashier from zz442), 'cashier'), ((select kitchen from zz442), 'kitchen'),
  ((select cashier_b2 from zz442), 'cashierb2'), ((select outsider from zz442), 'outsider'),
  ((select pwstaff from zz442), 'pwstaff')
) as x(u, n);

insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz442.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz442' || n, 'active'
from (values
  ((select owner from zz442), 'owner'), ((select mgr from zz442), 'mgr'),
  ((select cashier from zz442), 'cashier'), ((select kitchen from zz442), 'kitchen'),
  ((select cashier_b2 from zz442), 'cashierb2'), ((select outsider from zz442), 'outsider'),
  ((select pwstaff from zz442), 'pwstaff')
) as x(u, n)
on conflict (id) do update set username = excluded.username, account_status = 'active';

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select merchant from zz442), 'zz442-shop', (select owner from zz442), 'food', 'active'),
  ((select other_merchant from zz442), 'zz442-other-shop', NULL, 'food', 'active');

insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz442), (select merchant from zz442), 'zz442-b1', true),
  ((select branch2 from zz442), (select merchant from zz442), 'zz442-b2', false),
  ((select other_branch from zz442), (select other_merchant from zz442), 'zz442-ob', true);

insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity) values
  ((select product from zz442), (select merchant from zz442), 'zz442-tea', 'شاي', 25, 100),
  ((select product2 from zz442), (select merchant from zz442), 'zz442-rice', 'أرز', 120, 2),
  ((select other_product from zz442), (select other_merchant from zz442), 'zz442-other', 'آخر', 50, 10),
  ((select unavail_product from zz442), (select merchant from zz442), 'zz442-off', 'موقوف', 30, 5),
  ((select untracked_product from zz442), (select merchant from zz442), 'zz442-open', 'مفتوح', 15, NULL);

update public.products set is_available = false where id = (select unavail_product from zz442);

insert into public.pos_customers(id, merchant_id, name, phone) values
  ((select customer from zz442), (select merchant from zz442), 'zz442-tab-customer', '01011112222'),
  ((select other_customer from zz442), (select other_merchant from zz442), 'zz442-other-tab', '01033334444');

-- App orders for the feed/queue/advance tests; order_null is UNATTRIBUTED
-- (branch NULL) for the manager-only visibility rule (#249/S10).
insert into public.orders(id, user_id, merchant_id, status, payment_method, subtotal, total_amount, items, special_instructions, branch_id, source)
values
  ((select order1 from zz442), (select outsider from zz442), (select merchant from zz442),
   'confirmed', 'cash', 100, 100, '[{"name":"zz442-tea","quantity":2}]'::jsonb, 'بدون سكر',
   (select branch1 from zz442), 'app'),
  ((select order2 from zz442), (select outsider from zz442), (select merchant from zz442),
   'preparing', 'cash', 50, 50, '[{"name":"zz442-rice","quantity":1}]'::jsonb, NULL,
   (select branch2 from zz442), 'app'),
  ((select other_order from zz442), (select outsider from zz442), (select other_merchant from zz442),
   'confirmed', 'cash', 70, 70, '[{"name":"zz442-other","quantity":1}]'::jsonb, NULL,
   (select other_branch from zz442), 'app'),
  ((select order_null from zz442), (select outsider from zz442), (select merchant from zz442),
   'confirmed', 'cash', 40, 40, '[{"name":"zz442-tea","quantity":1}]'::jsonb, 'بدون فرع',
   NULL, 'app');

-- Staff rows (as the service-role edge function would create them).
-- pwstaff keeps must_change_password = true for the barrier test (S5).
insert into public.merchant_staff(merchant_id, user_id, username, full_name, phone, role, branch_id, must_change_password) values
  ((select merchant from zz442), (select mgr from zz442), 'zz442mgr', 'zz442 Manager', '01055550001', 'branch_manager', (select branch1 from zz442), false),
  ((select merchant from zz442), (select cashier from zz442), 'zz442cashier', 'zz442 Cashier', '01055550002', 'cashier', (select branch1 from zz442), false),
  ((select merchant from zz442), (select kitchen from zz442), 'zz442kitchen', 'zz442 Kitchen', '01055550003', 'kitchen', (select branch1 from zz442), false),
  ((select merchant from zz442), (select cashier_b2 from zz442), 'zz442cashierb2', 'zz442 Cashier B2', '01055550004', 'cashier', (select branch2 from zz442), false),
  ((select other_merchant from zz442), (select outsider from zz442), 'zz442outsider', 'zz442 Outsider', '01055550005', 'cashier', (select other_branch from zz442), false),
  ((select merchant from zz442), (select pwstaff from zz442), 'zz442pwstaff', 'zz442 PW Staff', '01055550006', 'cashier', (select branch1 from zz442), true);

-- One pre-existing audit row for the other shop, so S6 can prove merchant
-- deletion does NOT take merchant_staff_events down with it.
insert into public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
select s.id, s.merchant_id, 'created', '{"fixture":true}'::jsonb, s.user_id
  from public.merchant_staff s where s.username = 'zz442outsider';

-- ============ 0) schema guards ============
DO $$
BEGIN
  -- Staff phones stay OUT of users.phone (phone squatting guard).
  ASSERT NOT EXISTS (
    SELECT 1 FROM public.users u JOIN public.merchant_staff s ON s.user_id = u.id
     WHERE u.phone IS NOT NULL AND u.phone LIKE '010555500%'),
    'staff phone leaked into users.phone';
  -- Cashier/kitchen require a branch (CHECK).
  BEGIN
    INSERT INTO public.merchant_staff(merchant_id, user_id, username, full_name, role)
    SELECT (select merchant from zz442), (select cashier from zz442), 'zz442nobranch', 'x', 'cashier';
    RAISE EXCEPTION 'zz442 sentinel: branchless cashier allowed';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- Cross-merchant branch refused by trigger.
  BEGIN
    INSERT INTO public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id)
    SELECT (select merchant from zz442), (select cashier from zz442), 'zz442xref', 'x', 'cashier', (select other_branch from zz442);
    RAISE EXCEPTION 'zz442 sentinel: cross-merchant branch allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%does not belong to merchant%', 'wrong error: ' || SQLERRM;
  END;
  -- Shop owner cannot be staff.
  BEGIN
    INSERT INTO public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id)
    SELECT (select merchant from zz442), (select owner from zz442), 'zz442ownerstaff', 'x', 'branch_manager', NULL;
    RAISE EXCEPTION 'zz442 sentinel: owner-as-staff allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%are not staff%', 'wrong error: ' || SQLERRM;
  END;
  -- #257 inverse: staff merchant/user identity is immutable.
  BEGIN
    UPDATE public.merchant_staff SET merchant_id = (select other_merchant from zz442)
     WHERE username = 'zz442cashier';
    RAISE EXCEPTION 'zz442 sentinel: staff reparent allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%immutable%', 'wrong error: ' || SQLERRM;
  END;
  -- #257 inverse: a referenced branch cannot change merchant.
  BEGIN
    UPDATE public.branches SET merchant_id = (select other_merchant from zz442)
     WHERE id = (select branch1 from zz442);
    RAISE EXCEPTION 'zz442 sentinel: branch reparent allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%cannot change merchant%', 'wrong error: ' || SQLERRM;
  END;
END $$;

-- ============ 1) grants ============
DO $$
DECLARE
  pub text[] := ARRAY[
    'feature_enabled(text)', 'is_active_staff(uuid)', 'staff_role(uuid)',
    'staff_branch_id(uuid)', 'staff_can_branch(uuid,uuid)', 'staff_pos_read_ok(uuid,uuid)',
    'staff_app_context()',
    'staff_orders_feed(timestamptz)', 'kitchen_order_queue()',
    'staff_advance_order_status(uuid,text)',
    'staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text)',
    'staff_shift_open(numeric,uuid)', 'staff_shift_close(numeric)',
    'staff_void_sale(uuid,text)', 'staff_record_debt_payment(uuid,numeric,uuid,text)',
    'shop_end_of_day_report(uuid,date,uuid)'];
  internal text[] := ARRAY[
    '_assert_staff_branch_match()', '_assert_branch_not_reparented()',
    '_block_staff_event_mutation()',
    '_assert_table_branch_match()', '_assert_sale_links_match()', '_num_or_null(text)',
    '_authorize_staff(text,text[])'];
  sig text;
BEGIN
  FOREACH sig IN ARRAY pub LOOP
    ASSERT has_function_privilege('authenticated', ('public.' || sig)::regprocedure, 'EXECUTE'), sig;
    ASSERT NOT has_function_privilege('anon', ('public.' || sig)::regprocedure, 'EXECUTE'), sig;
  END LOOP;
  FOREACH sig IN ARRAY internal LOOP
    ASSERT NOT has_function_privilege('authenticated', ('public.' || sig)::regprocedure, 'EXECUTE'), sig;
    ASSERT NOT has_function_privilege('anon', ('public.' || sig)::regprocedure, 'EXECUTE'), sig;
  END LOOP;
  ASSERT (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
           aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
           WHERE n.nspname = 'public' AND p.proname LIKE 'staff\_%' ESCAPE '\'
             AND a.grantee = 0 AND a.privilege_type = 'EXECUTE') = 0,
    'a staff function is still PUBLIC-executable';
END $$;

-- ============ 2) flags OFF: every operational RPC refuses ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: sale without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: feed without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_shift_open(0, NULL);
    RAISE EXCEPTION 'zz442 sentinel: open without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: close without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_void_sale(gen_random_uuid(), 'x');
    RAISE EXCEPTION 'zz442 sentinel: void without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_record_debt_payment(gen_random_uuid(), 1, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: debt without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.kitchen_order_queue();
    RAISE EXCEPTION 'zz442 sentinel: queue without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_advance_order_status(gen_random_uuid(), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: advance without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM IN ('feature disabled', 'status preparing is not staff-advanceable' , 'status delivered is not staff-advanceable') OR SQLERRM LIKE '%not staff-advanceable%', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date);
    RAISE EXCEPTION 'zz442 sentinel: eod without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
  -- Policies are dark too: staff read rights do not exist with flags OFF (#250).
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'staff read sales with flags OFF';
END $$;
RESET ROLE;

-- Surface flags on but the MASTER flag off: still refused (#250).
SELECT set_config('request.jwt.claims', '{}', true);
UPDATE public.platform_settings
   SET feature_flags = '{"cashier_mode_mobile":true,"kitchen_screen":true,"branches_ui":true,"eod_report":true}'::jsonb
 WHERE id = 'default';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: feed with master flag off';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'feature disabled', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- Turn the master flag on too (the suite runs as the DB owner).
SELECT set_config('request.jwt.claims', '{}', true);
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"staff_accounts":true}'::jsonb
 WHERE id = 'default';

-- ============ 3) forced password change barrier (S5) ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT pwstaff FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: must-change-pw sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%password change required%', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: must-change-pw fed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%password change required%', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.kitchen_order_queue();
    RAISE EXCEPTION 'zz442 sentinel: must-change-pw queued';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%password change required%', 'wrong error: ' || SQLERRM; END;
  -- Bootstrap is the declared exception: it answers AND reports the flag.
  ASSERT (public.staff_app_context() -> 'staff' ->> 'must_change_password')::boolean,
    'context must report must_change_password';
  -- Policies respect the barrier too.
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'must-change-pw staff read sales';
END $$;
RESET ROLE;

-- ============ 4) kitchen + NULL-branch negatives (#249/S10) ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen FROM zz442))::text, true);
DO $$
BEGIN
  -- Kitchen never reads financial tables (#249).
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'kitchen read pos_sales';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_shifts s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'kitchen read pos_shifts';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
BEGIN
  -- Unattributed (NULL-branch) orders are manager-only (#249/S10).
  SELECT count(*) INTO v_count FROM public.staff_orders_feed(NULL);
  ASSERT v_count = 1, format('cashier feed must exclude the NULL-branch order: %s', v_count);
  -- Cashier cannot advance the unattributed order.
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order_null FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: cashier advanced NULL-branch order';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%another branch%', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
BEGIN
  -- The branch-bound manager DOES see the unattributed order (manager-only rule).
  SELECT count(*) INTO v_count FROM public.staff_orders_feed(NULL);
  ASSERT v_count = 2, format('manager feed must include the NULL-branch order: %s', v_count);
END $$;
RESET ROLE;

-- ============ 5) walk-in sale: shift gate, server prices, sums, caps, stock, idempotency ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442aa000-0000-4000-8000-000000000001';
  v_res jsonb;
  v_stock int;
BEGIN
  -- S7: cash sales require an open shift.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":25}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cash sale without shift';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%open a shift%', 'wrong error: ' || SQLERRM; END;

  PERFORM public.staff_shift_open(50, gen_random_uuid());

  -- Client-sent price is ignored; the server price (25) is charged.
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":2,"price":999}]')::jsonb,
    '[{"method":"cash","amount":50}]', v_op);
  ASSERT (v_res ->> 'id') IS NOT NULL AND (v_res ->> 'total')::numeric = 50,
    format('server-side pricing broke: %s', v_res);
  SELECT stock_quantity INTO v_stock FROM public.products
   WHERE id = (SELECT product FROM zz442);
  ASSERT v_stock = 98, format('canonical stock not decremented: %s', v_stock);
  -- Idempotent replay: same sale (byte-identical request), no double decrement.
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":2,"price":999}]')::jsonb,
    '[{"method":"cash","amount":50}]', v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean, 'replay not detected';
  SELECT stock_quantity INTO v_stock FROM public.products
   WHERE id = (SELECT product FROM zz442);
  ASSERT v_stock = 98, format('replay double-decremented stock: %s', v_stock);
  -- Same op id, DIFFERENT payload: conflict, not replay (#256).
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":9}]')::jsonb,
      '[{"method":"cash","amount":225}]', v_op);
    RAISE EXCEPTION 'zz442 sentinel: payload-swapped replay allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%reused with a different request%', 'wrong error: ' || SQLERRM; END;
  -- Persisted reconciliation (#254): payments sum to the stored total.
  ASSERT (SELECT sum(p.amount) FROM public.pos_sale_payments p
           JOIN public.pos_sales s ON s.id = p.sale_id
           WHERE s.idempotency_key = v_op::text)
       = (SELECT total_amount FROM public.pos_sales WHERE idempotency_key = v_op::text),
    'persisted payments do not reconcile to the total';
  -- Payments must sum to the total.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: unsummed payments allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%must sum to the total%', 'wrong error: ' || SQLERRM; END;
  -- Cashier discount cap (10%): 20 on 100 must fail.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":4}]')::jsonb,
      '[{"method":"cash","amount":80}]', gen_random_uuid(), 20);
    RAISE EXCEPTION 'zz442 sentinel: cashier over-cap discount allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%discount exceeds%', 'wrong error: ' || SQLERRM; END;
  -- Within cap (10 on 100) passes with a matching payment.
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":4}]')::jsonb,
    '[{"method":"instapay","amount":90}]', gen_random_uuid(), 10);
  ASSERT (v_res ->> 'total')::numeric = 90, format('in-cap discount broke: %s', v_res);
  -- Race-safe stock: only 2 rice in stock; 3 must fail atomically.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product2 FROM zz442) || '","qty":3}]')::jsonb,
      '[{"method":"cash","amount":360}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: over-stock sale allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%insufficient stock%', 'wrong error: ' || SQLERRM; END;
  SELECT stock_quantity INTO v_stock FROM public.products
   WHERE id = (SELECT product2 FROM zz442);
  ASSERT v_stock = 2, format('failed sale consumed stock: %s', v_stock);
  -- Untracked stock (NULL) sells without decrement (#251).
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT untracked_product FROM zz442) || '","qty":5}]')::jsonb,
    '[{"method":"instapay","amount":75}]', gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 75, 'untracked product sale broke';
  ASSERT (SELECT stock_quantity FROM public.products WHERE id = (SELECT untracked_product FROM zz442)) IS NULL,
    'untracked stock was touched';
  -- Unavailable product refused (#251).
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT unavail_product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":30}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: unavailable product sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%unavailable%', 'wrong error: ' || SQLERRM; END;
  -- Fractional catalog qty refused (#254).
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1.5}]')::jsonb,
      '[{"method":"cash","amount":37.5}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: fractional catalog qty allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%positive integer%', 'wrong error: ' || SQLERRM; END;
  -- Malformed / unknown product ids NEVER fall through to free text (S2).
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"product_id":"not-a-uuid","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: malformed product id fell through';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%malformed product_id%', 'wrong error: ' || SQLERRM; END;
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || gen_random_uuid() || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: unknown product sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%unknown product%', 'wrong error: ' || SQLERRM; END;
  -- Cross-tenant product refused.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT other_product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":50}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant product allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%unknown product%', 'wrong error: ' || SQLERRM; END;
  -- Non-catalog lines must be explicit custom items (S2).
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: implicit custom line allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%explicit custom%', 'wrong error: ' || SQLERRM; END;
  -- A cashier at a food shop cannot make custom lines (S2).
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cashier custom line at food shop allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%branch manager or a service-type shop%', 'wrong error: ' || SQLERRM; END;
  -- Hostile jsonb: non-numeric qty/amount refused, never a cast crash.
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":1,"qty":"abc"}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: hostile qty allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":"xyz"}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: hostile amount allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%must be a number%', 'wrong error: ' || SQLERRM; END;
  -- Deferred without a customer refused.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"deferred","amount":25}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: deferred without customer allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%requires a customer%', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 6) custom lines: manager may, zero price refused (S2) ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.staff_shift_open(0, gen_random_uuid());
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":0,"qty":1}]', '[{"method":"cash","amount":0}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: zero-price custom line allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%> 0%', 'wrong error: ' || SQLERRM; END;
  v_res := public.staff_create_walk_in_sale('[{"custom":true,"label":"خدمة","price":200,"qty":1}]',
    '[{"method":"instapay","amount":200}]', gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 200, 'manager custom line broke';
END $$;
RESET ROLE;

-- ============ 7) S1: deferred charge can never be swallowed ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442cc000-0000-4000-8000-000000000001';
  v_res jsonb;
  v_sale uuid;
BEGIN
  -- A debt payment under op X...
  PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 30, v_op);
  -- ...then a deferred sale under the SAME op X: the charge MUST land (S1).
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":2}]')::jsonb,
    '[{"method":"cash","amount":20},{"method":"deferred","amount":30}]',
    v_op, 0, (SELECT customer FROM zz442));
  ASSERT (v_res ->> 'id') IS NOT NULL, 'deferred sale under a payment op failed';
  -- Two deferred lines in one sale: ONE charge with the SUM (#253).
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":4}]')::jsonb,
    '[{"method":"deferred","amount":60},{"method":"deferred","amount":40}]',
    '442cc000-0000-4000-8000-000000000002', 0, (SELECT customer FROM zz442));
  ASSERT (v_res ->> 'id') IS NOT NULL, 'two-deferred-lines sale failed';
END $$;
RESET ROLE;

-- pos_debt_ledger is owner-read only (RPC-only for staff): persistence
-- asserts run as the DB owner.
DO $$
DECLARE
  v_sale uuid;
BEGIN
  SELECT id INTO v_sale FROM public.pos_sales
   WHERE merchant_id = (SELECT merchant FROM zz442)
     AND idempotency_key = '442cc000-0000-4000-8000-000000000001';
  ASSERT EXISTS (SELECT 1 FROM public.pos_debt_ledger l
                  WHERE l.sale_id = v_sale AND l.kind = 'charge' AND l.amount = 30),
    'deferred charge swallowed by op-id collision (S1)';
  SELECT id INTO v_sale FROM public.pos_sales
   WHERE merchant_id = (SELECT merchant FROM zz442)
     AND idempotency_key = '442cc000-0000-4000-8000-000000000002';
  ASSERT (SELECT count(*) FROM public.pos_debt_ledger l WHERE l.sale_id = v_sale AND l.kind = 'charge') = 1
     AND (SELECT amount FROM public.pos_debt_ledger l WHERE l.sale_id = v_sale AND l.kind = 'charge') = 100,
    'two deferred lines did not sum into one charge';
END $$;

-- ============ 8) shifts + variance audit incl. debt receipts (S7) ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier_b2 FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442bb000-0000-4000-8000-000000000001';
  v_res jsonb;
  v_shift uuid;
BEGIN
  v_res := public.staff_shift_open(100, v_op);
  v_shift := (v_res ->> 'id')::uuid;
  ASSERT NOT (v_res ->> 'idempotent_replay')::boolean, 'first open flagged replay';
  -- Replay returns the same shift.
  v_res := public.staff_shift_open(100, v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean AND (v_res ->> 'id')::uuid = v_shift, 'open replay broke';
  -- Same op id, different float: conflict (#256).
  BEGIN
    PERFORM public.staff_shift_open(999, v_op);
    RAISE EXCEPTION 'zz442 sentinel: payload-swapped shift replay allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%reused with a different request%', 'wrong error: ' || SQLERRM; END;
  -- A second open while one is open is refused.
  BEGIN
    PERFORM public.staff_shift_open(0, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: second open shift allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%close your current shift%', 'wrong error: ' || SQLERRM; END;
  -- One cash sale of 250 + one cash debt receipt of 70 on the shift.
  PERFORM public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":10}]')::jsonb,
    '[{"method":"cash","amount":250}]', gen_random_uuid());
  PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 70, gen_random_uuid());
  ASSERT (SELECT shift_id FROM public.pos_sales
           WHERE staff_id = (SELECT id FROM public.merchant_staff WHERE user_id = (SELECT cashier_b2 FROM zz442))
           LIMIT 1) = v_shift,
    'sale not linked to the open shift';
  -- Close: expected = 100 float + 250 cash + 70 debt receipts = 420;
  -- counted 415 -> variance -5, audited.
  v_res := public.staff_shift_close(415);
  ASSERT (v_res ->> 'expected')::numeric = 420 AND (v_res ->> 'variance')::numeric = -5,
    format('variance math broke (debt receipts missing?): %s', v_res);
  -- No open shift anymore.
  BEGIN
    PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: closed twice';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'no open shift', 'wrong error: ' || SQLERRM; END;
  -- Debt payment with no open shift refused (S7).
  BEGIN
    PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 10, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: debt receipt without shift allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%open a shift%', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                  WHERE e.kind = 'shift_closed' AND (e.detail ->> 'variance')::numeric = -5),
    'variance not audited';
END $$;

-- ============ 9) void: manager only, stock from moves, debt reversal (S3) ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
  v_sale uuid;
  v_stock int;
BEGIN
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":5}]')::jsonb,
    '[{"method":"instapay","amount":125}]', gen_random_uuid(), 0, NULL, (SELECT branch1 FROM zz442));
  v_sale := (v_res ->> 'id')::uuid;
  ASSERT v_sale IS NOT NULL, 'manager sale failed';
  v_res := public.staff_void_sale(v_sale, 'خطأ في الطلب');
  ASSERT (v_res ->> 'voided')::boolean, 'void failed';
  SELECT stock_quantity INTO v_stock FROM public.products
   WHERE id = (SELECT product FROM zz442);
  -- 100 - 2 (first) - 4 (in-cap) - 2 (S1 first) - 4 (S1 second) - 10 (shift sale) - 5 + 5 (void restore).
  ASSERT v_stock = 78, format('void did not restore canonical stock: %s', v_stock);
  BEGIN
    PERFORM public.staff_void_sale(v_sale, 'مرة أخرى');
    RAISE EXCEPTION 'zz442 sentinel: double void allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'sale already voided', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                  WHERE e.kind = 'void_sale'),
    'void not audited';
END $$;

-- Void reverses deferred debt (S3): the section-7 second sale (100 charge).
-- Ledger rows are owner-read only, so the charge lookup happens as the
-- DB owner and only the sale id crosses into the staff block.
DO $$
BEGIN
  PERFORM 1 FROM public.pos_debt_ledger l
   WHERE l.merchant_id = (SELECT merchant FROM zz442) AND l.kind = 'charge' AND l.amount = 100
   LIMIT 1;
  ASSERT FOUND, 'section-7 100 charge missing';
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
BEGIN
  PERFORM public.staff_void_sale(
    (SELECT id FROM public.pos_sales
      WHERE merchant_id = (SELECT merchant FROM zz442)
        AND idempotency_key = '442cc000-0000-4000-8000-000000000002'), 'إلغاء');
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.pos_debt_ledger r
                  WHERE r.kind = 'reversal' AND r.amount = 100
                    AND r.merchant_id = (SELECT merchant FROM zz442)),
    'void did not reverse the deferred charge';
END $$;

-- Cashier cannot void.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.staff_void_sale((SELECT id FROM public.pos_sales WHERE merchant_id = (SELECT merchant FROM zz442) AND status = 'completed' LIMIT 1), 'x');
    RAISE EXCEPTION 'zz442 sentinel: cashier voided';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 10) debt payment: replay, payload conflict, cap (S11), cross-tenant ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442dd000-0000-4000-8000-000000000001';
  v_res jsonb;
BEGIN
  v_res := public.staff_record_debt_payment((SELECT customer FROM zz442), 30, v_op);
  ASSERT NOT (v_res ->> 'idempotent_replay')::boolean, 'first debt payment flagged replay';
  v_res := public.staff_record_debt_payment((SELECT customer FROM zz442), 30, v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean, 'debt replay broke';
  -- Same op id, different amount: conflict (#256).
  BEGIN
    PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 31, v_op);
    RAISE EXCEPTION 'zz442 sentinel: payload-swapped debt replay allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%reused with a different request%', 'wrong error: ' || SQLERRM; END;
  -- Cap (default 5000).
  BEGIN
    PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 6000, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: over-cap debt payment allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%exceeds the%cap%', 'wrong error: ' || SQLERRM; END;
  -- Cross-tenant customer refused.
  BEGIN
    PERFORM public.staff_record_debt_payment((SELECT other_customer FROM zz442), 30, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant debt payment allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%does not belong to this shop%', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 11) kitchen queue: masked + branch-scoped ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
  v_items jsonb;
BEGIN
  SELECT count(*), coalesce(jsonb_agg(q.items), '[]'::jsonb)
    INTO v_count, v_items
    FROM public.kitchen_order_queue() q;
  -- Only branch1's confirmed order: order2 is branch2, other_order another
  -- shop, order_null is unattributed (manager-only, S10).
  ASSERT v_count = 1, format('kitchen queue scope broke: %s', v_count);
  -- Masked: name + qty only, no prices/phones anywhere in the items payload.
  ASSERT v_items::text NOT LIKE '%phone%' AND v_items::text NOT LIKE '%price%'
     AND v_items::text NOT LIKE '%010%', format('kitchen queue leaked: %s', v_items);
END $$;
RESET ROLE;

-- ============ 12) order status advance: whitelist + scope ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.staff_advance_order_status((SELECT order1 FROM zz442), 'preparing');
  ASSERT (v_res ->> 'status') = 'preparing', 'advance failed';
  v_res := public.staff_advance_order_status((SELECT order1 FROM zz442), 'ready');
  ASSERT (v_res ->> 'status') = 'ready', 'second advance failed';
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'delivered');
    RAISE EXCEPTION 'zz442 sentinel: non-whitelisted status allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%not staff-advanceable%', 'wrong error: ' || SQLERRM; END;
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'ready');
    RAISE EXCEPTION 'zz442 sentinel: repeat advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%illegal transition%', 'wrong error: ' || SQLERRM; END;
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT other_order FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'order not found', 'wrong error: ' || SQLERRM; END;
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order2 FROM zz442), 'ready');
    RAISE EXCEPTION 'zz442 sentinel: cross-branch advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%another branch%', 'wrong error: ' || SQLERRM; END;
  -- Kitchen cannot touch the unattributed order either (manager-only, S10).
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order_null FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: kitchen advanced NULL-branch order';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%another branch%', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 13) staff orders feed: branch scope ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier_b2 FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM public.staff_orders_feed(NULL);
  ASSERT v_count = 1, format('feed scope broke for branch2 cashier: %s', v_count);
END $$;
RESET ROLE;

-- ============ 14) staff SELECT policies: pos_* scoped, RPC-only tables closed ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'staff cannot read own-shop sales';
  -- Branch-bound cashier does NOT read the other branch's shift.
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_shifts s
                      WHERE s.merchant_id = (SELECT merchant FROM zz442)
                        AND s.branch_id = (SELECT branch2 FROM zz442)),
    'cashier read another branch shift';
  -- orders / pos_customers / pos_debt_ledger stay RPC-only for staff.
  ASSERT NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.merchant_id = (SELECT merchant FROM zz442)),
    'staff can read orders directly';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_customers c WHERE c.merchant_id = (SELECT merchant FROM zz442)),
    'staff can read pos_customers directly';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger l WHERE l.merchant_id = (SELECT merchant FROM zz442)),
    'staff can read pos_debt_ledger directly';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz442))::text, true);
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'cross-tenant staff read sales';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sale_payments p
                      JOIN public.pos_sales s ON s.id = p.sale_id
                      WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'cross-tenant staff read payments';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_shifts s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'cross-tenant staff read shifts';
END $$;
RESET ROLE;

-- ============ 15) EOD report ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, NULL);
  ASSERT (v_res #>> '{walk_in_sales,count}')::int >= 3, format('owner combined report broke: %s', v_res);
  v_res := public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, (SELECT branch1 FROM zz442));
  ASSERT (v_res ->> 'branch_id')::uuid = (SELECT branch1 FROM zz442), 'owner branch report broke';
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  -- Branch-bound manager gets their branch regardless of the param.
  v_res := public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, NULL);
  ASSERT (v_res ->> 'branch_id')::uuid = (SELECT branch1 FROM zz442), 'manager scope not forced';
  BEGIN
    PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, (SELECT branch2 FROM zz442));
    RAISE EXCEPTION 'zz442 sentinel: manager read another branch';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'branch outside your scope', 'wrong error: ' || SQLERRM; END;
  -- Cross-tenant EOD refused (#257).
  BEGIN
    PERFORM public.shop_end_of_day_report((SELECT other_merchant FROM zz442), current_date, NULL);
    RAISE EXCEPTION 'zz442 sentinel: manager read another shop';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not your shop', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, NULL);
    RAISE EXCEPTION 'zz442 sentinel: cashier read EOD';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- Disabled MANAGER cannot read EOD either (#257).
UPDATE public.merchant_staff SET is_active = false, disabled_at = now()
 WHERE user_id = (SELECT mgr FROM zz442);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, NULL);
    RAISE EXCEPTION 'zz442 sentinel: disabled manager read EOD';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
UPDATE public.merchant_staff SET is_active = true, disabled_at = NULL
 WHERE user_id = (SELECT mgr FROM zz442);

-- ============ 16) S4: feature_flags are platform-owner-only ============
-- As the DB owner (RLS bypass) but with a NON-owner JWT claim, the trigger
-- alone must refuse the flag change.
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    UPDATE public.platform_settings
       SET feature_flags = feature_flags || '{"kitchen_screen":false}'::jsonb
     WHERE id = 'default';
    RAISE EXCEPTION 'zz442 sentinel: non-owner changed feature_flags';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'Only the platform owner can change feature flags', 'wrong error: ' || SQLERRM; END;
END $$;
SELECT set_config('request.jwt.claims', '{}', true);
-- Service path (no JWT) can still manage flags.
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"kitchen_screen":true}'::jsonb
 WHERE id = 'default';
DO $$
BEGIN
  ASSERT (SELECT (feature_flags ->> 'kitchen_screen')::boolean FROM public.platform_settings WHERE id = 'default'),
    'service-path flag update broke';
END $$;

-- ============ 17) append-only audit ============
DO $$
BEGIN
  BEGIN
    UPDATE public.merchant_staff_events SET detail = '{}'::jsonb WHERE kind = 'walk_in_sale';
    RAISE EXCEPTION 'zz442 sentinel: audit update allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%append-only%', 'wrong error: ' || SQLERRM; END;
  BEGIN
    DELETE FROM public.merchant_staff_events;
    RAISE EXCEPTION 'zz442 sentinel: audit delete allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%append-only%', 'wrong error: ' || SQLERRM; END;
END $$;

-- ============ 18) S6: deleting a user or a merchant never breaks on the audit trail ============
DO $$
DECLARE
  v_events_before int;
  v_events_after int;
BEGIN
  SELECT count(*) INTO v_events_before FROM public.merchant_staff_events e
   JOIN public.merchant_staff s ON s.id = e.staff_id
   WHERE s.username = 'zz442kitchen';
  ASSERT v_events_before > 0, 'fixture: kitchen has no events';
  -- Deleting the USER cascades to the staff row; the audit rows survive
  -- with staff_id nulled by the FK cascade (permitted by the trigger).
  DELETE FROM public.users WHERE id = (SELECT kitchen FROM zz442);
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff s WHERE s.username = 'zz442kitchen'),
    'staff row not cascaded';
  SELECT count(*) INTO v_events_after FROM public.merchant_staff_events e
   WHERE e.merchant_id = (SELECT merchant FROM zz442);
  ASSERT v_events_after >= v_events_before, 'audit rows lost on user deletion';
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                      WHERE e.staff_id IS NOT NULL
                        AND e.kind = 'order_status' AND e.detail ->> 'order_id' = (SELECT order1 FROM zz442)::text),
    'kitchen events still linked after user deletion';
  -- Deleting the MERCHANT works too; its audit rows survive (plain uuid).
  -- orders.merchant_id is RESTRICT (financial record), so the fixture's
  -- other-shop order goes first; the S6 target is merchant_staff_events.
  DELETE FROM public.orders WHERE id = (SELECT other_order FROM zz442);
  DELETE FROM public.merchants WHERE id = (SELECT other_merchant FROM zz442);
  ASSERT NOT EXISTS (SELECT 1 FROM public.merchant_staff s WHERE s.username = 'zz442outsider'),
    'other-shop staff row not cascaded';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                  WHERE e.merchant_id = (SELECT other_merchant FROM zz442)),
    'other-shop audit rows lost on merchant deletion';
END $$;

-- ============ 19) DISABLED staff: old token refused by EVERY staff RPC ============
UPDATE public.merchant_staff SET is_active = false, disabled_at = now()
 WHERE user_id = (SELECT cashier FROM zz442);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_create_walk_in_sale('[{"custom":true,"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier fed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_shift_open(0, NULL);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier opened';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier closed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_void_sale(gen_random_uuid(), 'x');
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier voided';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 1, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier booked debt';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier advanced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.kitchen_order_queue();
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier queued';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'not active shop staff', 'wrong error: ' || SQLERRM; END;
  -- Context reports no staff row.
  ASSERT (public.staff_app_context() ->> 'staff') IS NULL, 'disabled staff still has context';
  -- Policies close too.
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'disabled staff still reads sales';
END $$;
RESET ROLE;

SELECT '442 suite OK' AS result;
ROLLBACK;
