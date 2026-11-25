-- Suite for migration 442 (shop staff + branch scope, dark).
-- Applied by supabase/harness/442_harness.sh AFTER 439 + 440 + 441 + 442
-- on a throwaway clone of h435_template. Synthetic fixtures only:
-- @example.invalid emails, zz442-* usernames, never real accounts.
-- DISPOSABLE-DATABASE-ONLY: auth.users fixtures persist for the length of
-- the transaction; run on a throwaway clone, never on staging or prod.
-- Every expected-refusal block uses the sentinel idiom: if the probed
-- statement SUCCEEDS, the sentinel message re-raises and the suite fails.

BEGIN;

create temporary table zz442(
  owner uuid, mgr uuid, cashier uuid, kitchen uuid, cashier_b2 uuid, outsider uuid,
  merchant uuid, other_merchant uuid, branch1 uuid, branch2 uuid, other_branch uuid,
  product uuid, product2 uuid, other_product uuid, customer uuid, other_customer uuid,
  order1 uuid, order2 uuid, other_order uuid
);
insert into zz442 select
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
  ((select cashier_b2 from zz442), 'cashierb2'), ((select outsider from zz442), 'outsider')
) as x(u, n);

insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz442.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz442' || n, 'active'
from (values
  ((select owner from zz442), 'owner'), ((select mgr from zz442), 'mgr'),
  ((select cashier from zz442), 'cashier'), ((select kitchen from zz442), 'kitchen'),
  ((select cashier_b2 from zz442), 'cashierb2'), ((select outsider from zz442), 'outsider')
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
  ((select other_product from zz442), (select other_merchant from zz442), 'zz442-other', 'آخر', 50, 10);

insert into public.product_inventory(product_id, merchant_id, stock_quantity, is_in_stock) values
  ((select product from zz442), (select merchant from zz442), 100, true),
  ((select product2 from zz442), (select merchant from zz442), 2, true)
on conflict (product_id) do update set stock_quantity = excluded.stock_quantity;

insert into public.pos_customers(id, merchant_id, name, phone) values
  ((select customer from zz442), (select merchant from zz442), 'zz442-tab-customer', '01011112222'),
  ((select other_customer from zz442), (select other_merchant from zz442), 'zz442-other-tab', '01033334444');

-- App orders for the feed/queue/advance tests.
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
   (select other_branch from zz442), 'app');

-- Staff rows (as the service-role edge function would create them).
insert into public.merchant_staff(merchant_id, user_id, username, full_name, phone, role, branch_id) values
  ((select merchant from zz442), (select mgr from zz442), 'zz442mgr', 'zz442 Manager', '01055550001', 'branch_manager', (select branch1 from zz442)),
  ((select merchant from zz442), (select cashier from zz442), 'zz442cashier', 'zz442 Cashier', '01055550002', 'cashier', (select branch1 from zz442)),
  ((select merchant from zz442), (select kitchen from zz442), 'zz442kitchen', 'zz442 Kitchen', '01055550003', 'kitchen', (select branch1 from zz442)),
  ((select merchant from zz442), (select cashier_b2 from zz442), 'zz442cashierb2', 'zz442 Cashier B2', '01055550004', 'cashier', (select branch2 from zz442)),
  ((select other_merchant from zz442), (select outsider from zz442), 'zz442outsider', 'zz442 Outsider', '01055550005', 'cashier', (select other_branch from zz442));

-- ============ 0) schema guards ============
DO $$
BEGIN
  -- Staff phones stay OUT of users.phone (phone squatting guard).
  ASSERT NOT EXISTS (
    SELECT 1 FROM public.users u JOIN public.merchant_staff s ON s.user_id = u.id
     WHERE u.phone IS NOT NULL AND u.phone IN ('01055550001','01055550002','01055550003','01055550004','01055550005')),
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
  END;
  -- Shop owner cannot be staff.
  BEGIN
    INSERT INTO public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id)
    SELECT (select merchant from zz442), (select owner from zz442), 'zz442ownerstaff', 'x', 'branch_manager', NULL;
    RAISE EXCEPTION 'zz442 sentinel: owner-as-staff allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;

-- ============ 1) grants ============
DO $$
DECLARE
  pub text[] := ARRAY[
    'feature_enabled(text)', 'is_active_staff(uuid)', 'staff_role(uuid)',
    'staff_branch_id(uuid)', 'staff_can_branch(uuid,uuid)', 'staff_app_context()',
    'staff_orders_feed(timestamptz)', 'kitchen_order_queue()',
    'staff_advance_order_status(uuid,text)',
    'staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text)',
    'staff_shift_open(numeric,uuid)', 'staff_shift_close(numeric)',
    'staff_void_sale(uuid,text)', 'staff_record_debt_payment(uuid,numeric,uuid,text)',
    'shop_end_of_day_report(uuid,date,uuid)'];
  internal text[] := ARRAY[
    '_assert_staff_branch_match()', '_block_staff_event_mutation()',
    '_assert_table_branch_match()', '_assert_sale_links_match()', '_num_or_null(text)'];
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

-- ============ 2) flags default OFF: every operational RPC refuses ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: sale without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: feed without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_shift_open(0, NULL);
    RAISE EXCEPTION 'zz442 sentinel: open without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: close without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_void_sale(gen_random_uuid(), 'x');
    RAISE EXCEPTION 'zz442 sentinel: void without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_record_debt_payment(gen_random_uuid(), 1, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: debt without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.kitchen_order_queue();
    RAISE EXCEPTION 'zz442 sentinel: queue without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_advance_order_status(gen_random_uuid(), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: advance without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date);
    RAISE EXCEPTION 'zz442 sentinel: eod without flag';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;

-- Turn the flags on (admin-write surface; the suite runs as the DB owner).
UPDATE public.platform_settings
   SET feature_flags = '{"staff_accounts":true,"cashier_mode_mobile":true,"kitchen_screen":true,"branches_ui":true,"eod_report":true}'::jsonb
 WHERE id = 'default';

-- ============ 3) walk-in sale: server prices, sums, caps, stock, idempotency ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442aa000-0000-4000-8000-000000000001';
  v_res jsonb;
  v_stock int;
BEGIN
  -- Client-sent price is ignored; the server price (25) is charged.
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":2,"price":999}]')::jsonb,
    '[{"method":"cash","amount":50}]', v_op);
  ASSERT (v_res ->> 'id') IS NOT NULL AND (v_res ->> 'total')::numeric = 50,
    format('server-side pricing broke: %s', v_res);
  SELECT stock_quantity INTO v_stock FROM public.product_inventory
   WHERE product_id = (SELECT product FROM zz442);
  ASSERT v_stock = 98, format('stock not decremented: %s', v_stock);
  -- Idempotent replay returns the same sale, no double stock decrement.
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":2}]')::jsonb,
    '[{"method":"cash","amount":50}]', v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean, 'replay not detected';
  SELECT stock_quantity INTO v_stock FROM public.product_inventory
   WHERE product_id = (SELECT product FROM zz442);
  ASSERT v_stock = 98, format('replay double-decremented stock: %s', v_stock);
  -- Payments must sum to the total.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: unsummed payments allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Cashier discount cap (10%): 20 on 100 must fail.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":4}]')::jsonb,
      '[{"method":"cash","amount":80}]', gen_random_uuid(), 20);
    RAISE EXCEPTION 'zz442 sentinel: cashier over-cap discount allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
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
  END;
  SELECT stock_quantity INTO v_stock FROM public.product_inventory
   WHERE product_id = (SELECT product2 FROM zz442);
  ASSERT v_stock = 2, format('failed sale consumed stock: %s', v_stock);
  -- Hostile jsonb: non-numeric qty/amount refused, never a cast crash.
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":"abc"}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: hostile qty allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":"xyz"}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: hostile amount allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Cross-tenant product refused.
  BEGIN
    PERFORM public.staff_create_walk_in_sale(
      ('[{"product_id":"' || (SELECT other_product FROM zz442) || '","qty":1}]')::jsonb,
      '[{"method":"cash","amount":50}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant product allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Split payment incl. deferred with a customer books the debt.
  v_res := public.staff_create_walk_in_sale(
    '[{"label":"خدمة","price":200,"qty":1}]',
    '[{"method":"cash","amount":150},{"method":"deferred","amount":50}]',
    gen_random_uuid(), 0, (SELECT customer FROM zz442));
  ASSERT (v_res ->> 'total')::numeric = 200, format('split sale broke: %s', v_res);
  -- Deferred without a customer refused.
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":10,"qty":1}]',
      '[{"method":"deferred","amount":10}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: deferred without customer allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- The ledger row itself is invisible to staff (RLS), so check it as the owner.
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.pos_debt_ledger l
                  WHERE l.merchant_id = (SELECT merchant FROM zz442)
                    AND l.customer_id = (SELECT customer FROM zz442)
                    AND l.kind = 'charge' AND l.amount = 50), 'deferred charge not booked';
END $$;

-- Kitchen role cannot sell.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen::text FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: kitchen sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ============ 4) shifts + variance audit ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier_b2::text FROM zz442))::text, true);
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
  v_res := public.staff_shift_open(999, v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean AND (v_res ->> 'id')::uuid = v_shift, 'open replay broke';
  -- A second open while one is open is refused.
  BEGIN
    PERFORM public.staff_shift_open(0, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: second open shift allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- One cash sale of 250 on the shift.
  PERFORM public.staff_create_walk_in_sale(
    '[{"label":"طلب","price":250,"qty":1}]', '[{"method":"cash","amount":250}]', gen_random_uuid());
  ASSERT (SELECT shift_id FROM public.pos_sales
           WHERE staff_id = (SELECT id FROM public.merchant_staff WHERE user_id = (SELECT cashier_b2 FROM zz442))
           LIMIT 1) = v_shift,
    'sale not linked to the open shift';
  -- Close: expected = 100 float + 250 cash = 350; counted 345 -> variance -5, audited.
  v_res := public.staff_shift_close(345);
  ASSERT (v_res ->> 'expected')::numeric = 350 AND (v_res ->> 'variance')::numeric = -5,
    format('variance math broke: %s', v_res);
  -- No open shift anymore.
  BEGIN
    PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: closed twice';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- Audit rows are owner-read only; verify as the DB owner.
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                  WHERE e.kind = 'shift_closed' AND (e.detail ->> 'variance')::numeric = -5),
    'variance not audited';
END $$;

-- ============ 5) void: manager only, stock restored, audited ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr::text FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
  v_sale uuid;
  v_stock int;
BEGIN
  v_res := public.staff_create_walk_in_sale(
    ('[{"product_id":"' || (SELECT product FROM zz442) || '","qty":5}]')::jsonb,
    '[{"method":"cash","amount":125}]', gen_random_uuid(), 0, NULL, (SELECT branch1 FROM zz442));
  v_sale := (v_res ->> 'id')::uuid;
  ASSERT v_sale IS NOT NULL, 'manager sale failed';
  v_res := public.staff_void_sale(v_sale, 'خطأ في الطلب');
  ASSERT (v_res ->> 'voided')::boolean, 'void failed';
  SELECT stock_quantity INTO v_stock FROM public.product_inventory
   WHERE product_id = (SELECT product FROM zz442);
  -- 100 - 2 (first sale) - 4 (in-cap sale) - 5 (this sale) + 5 (void restore).
  ASSERT v_stock = 94, format('void did not restore stock: %s', v_stock);
  BEGIN
    PERFORM public.staff_void_sale(v_sale, 'مرة أخرى');
    RAISE EXCEPTION 'zz442 sentinel: double void allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
                  WHERE e.kind = 'void_sale' AND e.detail ->> 'sale_id' =
                    (SELECT id::text FROM public.pos_sales WHERE merchant_id = (SELECT merchant FROM zz442) AND status = 'voided' LIMIT 1)),
    'void not audited';
END $$;

-- Cashier cannot void.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.staff_void_sale((SELECT id FROM public.pos_sales WHERE merchant_id = (SELECT merchant FROM zz442) LIMIT 1), 'x');
    RAISE EXCEPTION 'zz442 sentinel: cashier voided';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ============ 6) debt payment: happy + idempotent + cross-tenant ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
DECLARE
  v_op uuid := '442cc000-0000-4000-8000-000000000001';
  v_res jsonb;
BEGIN
  v_res := public.staff_record_debt_payment((SELECT customer FROM zz442), 30, v_op);
  ASSERT NOT (v_res ->> 'idempotent_replay')::boolean, 'first debt payment flagged replay';
  v_res := public.staff_record_debt_payment((SELECT customer FROM zz442), 30, v_op);
  ASSERT (v_res ->> 'idempotent_replay')::boolean, 'debt replay broke';
  BEGIN
    PERFORM public.staff_record_debt_payment((SELECT other_customer FROM zz442), 30, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant debt payment allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ============ 7) kitchen queue: masked + branch-scoped ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen::text FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
  v_items jsonb;
BEGIN
  SELECT count(*), coalesce(jsonb_agg(q.items), '[]'::jsonb)
    INTO v_count, v_items
    FROM public.kitchen_order_queue() q;
  -- Only branch1's confirmed order is in scope (order2 is branch2, other_order another shop).
  ASSERT v_count = 1, format('kitchen queue scope broke: %s', v_count);
  -- Masked: name + qty only, no prices/phones anywhere in the items payload.
  ASSERT v_items::text NOT LIKE '%phone%' AND v_items::text NOT LIKE '%price%'
     AND v_items::text NOT LIKE '%010%', format('kitchen queue leaked: %s', v_items);
END $$;
RESET ROLE;

-- ============ 8) order status advance: whitelist + scope ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT kitchen::text FROM zz442))::text, true);
DO $$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.staff_advance_order_status((SELECT order1 FROM zz442), 'preparing');
  ASSERT (v_res ->> 'status') = 'preparing', 'advance failed';
  -- confirmed -> ready skip-ahead is refused (order2 is preparing in branch2,
  -- so use order1 once it is preparing: preparing -> delivered must refuse).
  v_res := public.staff_advance_order_status((SELECT order1 FROM zz442), 'ready');
  ASSERT (v_res ->> 'status') = 'ready', 'second advance failed';
  -- Non-whitelisted target refused.
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'delivered');
    RAISE EXCEPTION 'zz442 sentinel: non-whitelisted status allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Repeating the same advance (ready -> ready) is refused.
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'ready');
    RAISE EXCEPTION 'zz442 sentinel: repeat advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Cross-tenant order refused.
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT other_order FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: cross-tenant advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  -- Cross-branch order refused for a branch-bound kitchen.
  BEGIN
    PERFORM public.staff_advance_order_status((SELECT order2 FROM zz442), 'ready');
    RAISE EXCEPTION 'zz442 sentinel: cross-branch advance allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ============ 9) staff orders feed: handoff PII for cashier, branch scope ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM public.staff_orders_feed(NULL);
  ASSERT v_count = 1, format('feed scope broke for branch1 cashier: %s', v_count);
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier_b2::text FROM zz442))::text, true);
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM public.staff_orders_feed(NULL);
  ASSERT v_count = 1, format('feed scope broke for branch2 cashier: %s', v_count);
END $$;
RESET ROLE;

-- ============ 10) staff SELECT policies: pos_* scoped, orders NOT visible ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'staff cannot read own-shop sales';
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
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider::text FROM zz442))::text, true);
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'cross-tenant staff read sales';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_shifts s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'cross-tenant staff read shifts';
END $$;
RESET ROLE;

-- ============ 11) EOD report ============
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner::text FROM zz442))::text, true);
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
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr::text FROM zz442))::text, true);
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
  END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN
    PERFORM public.shop_end_of_day_report((SELECT merchant FROM zz442), current_date, NULL);
    RAISE EXCEPTION 'zz442 sentinel: cashier read EOD';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;

-- ============ 12) append-only audit ============
DO $$
BEGIN
  BEGIN
    UPDATE public.merchant_staff_events SET detail = '{}'::jsonb;
    RAISE EXCEPTION 'zz442 sentinel: audit update allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.merchant_staff_events;
    RAISE EXCEPTION 'zz442 sentinel: audit delete allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF;
  END;
END $$;

-- ============ 13) DISABLED staff: old token refused by EVERY staff RPC ============
UPDATE public.merchant_staff SET is_active = false, disabled_at = now()
 WHERE user_id = (SELECT cashier FROM zz442);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier::text FROM zz442))::text, true);
DO $$
BEGIN
  BEGIN PERFORM public.staff_create_walk_in_sale('[{"label":"x","price":1,"qty":1}]', '[{"method":"cash","amount":1}]', gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier sold';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_orders_feed(NULL);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier fed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_shift_open(0, NULL);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier opened';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_shift_close(0);
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier closed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_void_sale(gen_random_uuid(), 'x');
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier voided';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_record_debt_payment((SELECT customer FROM zz442), 1, gen_random_uuid());
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier booked debt';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.staff_advance_order_status((SELECT order1 FROM zz442), 'preparing');
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier advanced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.kitchen_order_queue();
    RAISE EXCEPTION 'zz442 sentinel: disabled cashier queued';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz442 sentinel:%' THEN RAISE; END IF; END;
  -- Context reports no staff row.
  ASSERT (public.staff_app_context() ->> 'staff') IS NULL, 'disabled staff still has context';
  -- Policies close too.
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_sales s WHERE s.merchant_id = (SELECT merchant FROM zz442)),
    'disabled staff still reads sales';
END $$;
RESET ROLE;

SELECT '442 suite OK' AS result;
ROLLBACK;
