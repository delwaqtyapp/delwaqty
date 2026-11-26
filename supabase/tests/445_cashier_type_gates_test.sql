-- Suite for migration 445 (cashier-type gates + per-type custom-line rule).
-- Applied by supabase/harness/445_harness.sh AFTER 439..445 on a throwaway
-- clone of h435_template. Synthetic fixtures only: @example.invalid emails,
-- zz445-* names. DISPOSABLE-DATABASE-ONLY. Sentinel idiom for refusals.

BEGIN;

create temporary table zz445(
  owner uuid, mgr uuid, cashier uuid,
  merchant uuid, branch1 uuid, product uuid
);
insert into zz445 select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
grant select on table zz445 to authenticated;

insert into auth.users(id, email)
select u, 'zz445.' || n || '@example.invalid'
from (values ((select owner from zz445), 'owner'),
             ((select mgr from zz445), 'mgr'),
             ((select cashier from zz445), 'cashier')) as x(u, n);

insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz445.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz445' || n, 'active'
from (values ((select owner from zz445), 'owner'),
             ((select mgr from zz445), 'mgr'),
             ((select cashier from zz445), 'cashier')) as x(u, n)
on conflict (id) do update set username = excluded.username, account_status = 'active';

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select merchant from zz445), 'zz445-shop', (select owner from zz445), 'restaurant', 'active');

insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz445), (select merchant from zz445), 'zz445-b1', true);

insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity) values
  ((select product from zz445), (select merchant from zz445), 'zz445-tea', 'شاي', 25, 100);

-- Staff rows as the 444 protocol would leave them: active, settled.
insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, is_active, must_change_password) values
  ((select merchant from zz445), (select mgr from zz445), 'zz445mgr', 'Mgr', 'branch_manager', NULL, true, false),
  ((select merchant from zz445), (select cashier from zz445), 'zz445cashier', 'Cashier', 'cashier', (select branch1 from zz445), true, false);

UPDATE public.platform_settings
   SET feature_flags = '{"cashier_mode_mobile":true,"staff_accounts":true}'::jsonb
 WHERE id = 'default';

-- ============ 1) partition functions ============
DO $$
BEGIN
  ASSERT public.is_cashier_type('food'), 'food must be cashier-eligible (owner decision)';
  ASSERT public.is_cashier_type('juice_shop'), 'juice_shop must be cashier-eligible';
  ASSERT public.is_cashier_type('restaurant'), 'restaurant cashier';
  ASSERT NOT public.is_cashier_type('service'), 'service not cashier';
  ASSERT NOT public.is_cashier_type(NULL), 'NULL fails closed';
  ASSERT NOT public.is_cashier_type('bogus'), 'unknown fails closed';
  ASSERT public.is_simple_service_type('service'), 'service simple';
  ASSERT public.is_simple_service_type('gas'), 'gas simple-service ok';
  ASSERT public.is_simple_service_type('carwash'), 'carwash simple-service ok';
  ASSERT public.is_simple_service_type('other'), 'other simple-service ok';
  ASSERT public.is_simple_service_type('fitness'), 'fitness simple';
  ASSERT NOT public.is_simple_service_type('food'), 'food not simple';
  ASSERT NOT public.is_simple_service_type('general'), 'general = goods ok';
  ASSERT NOT public.is_simple_service_type(NULL), 'NULL fails closed';
  ASSERT NOT public.is_simple_service_type('bogus'), 'unknown fails closed';
END $$;

-- ============ 2) staff_settings shape guard (fires for EVERY writer) ====
DO $$
BEGIN
  BEGIN UPDATE public.merchants SET staff_settings = '{"bogus":true}' WHERE id = (SELECT merchant FROM zz445);
    RAISE EXCEPTION 'zz445 sentinel: unknown staff_settings key accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'unknown staff_settings key%', 'wrong error: ' || SQLERRM; END;
  BEGIN UPDATE public.merchants SET staff_settings = '{"cashier_custom_lines":"yes"}' WHERE id = (SELECT merchant FROM zz445);
    RAISE EXCEPTION 'zz445 sentinel: non-boolean setting accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE '%must be a boolean', 'wrong error: ' || SQLERRM; END;
  BEGIN UPDATE public.merchants SET staff_settings = '[]'::jsonb WHERE id = (SELECT merchant FROM zz445);
    RAISE EXCEPTION 'zz445 sentinel: non-object settings accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff_settings must be an object', 'wrong error: ' || SQLERRM; END;
END $$;

-- ============ 3) type gates: a flip to a non-cashier type stops NEW work =
update public.merchants set type = 'service' where id = (select merchant from zz445);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_shift_open(0, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: shift opened on a service-type shop';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff sales need a cashier-type shop', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1}]', (SELECT product FROM zz445))::jsonb,
    '[{"method":"cash","amount":25}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: sale on a service-type shop';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff sales need a cashier-type shop', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
update public.merchants set type = 'restaurant' where id = (select merchant from zz445);

-- ============ 4) happy path: shift + catalog sale on a cashier type =====
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  PERFORM public.staff_shift_open(50, gen_random_uuid());
  PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1}]', (SELECT product FROM zz445))::jsonb,
    '[{"method":"cash","amount":25}]'::jsonb, gen_random_uuid());
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT stock_quantity FROM public.products WHERE id = (SELECT product FROM zz445)) = 99,
    'catalog sale did not decrement';
END $$;

-- ============ 5) custom lines: cashier default OFF, opt-in, caps ========
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"x","price":100,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":100}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: cashier custom line allowed by default';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines need a branch manager', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- owner opts the merchant in (owner-writable via the merchants policy)
update public.merchants set staff_settings = '{"cashier_custom_lines":true}'
 where id = (select merchant from zz445);

SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  PERFORM public.staff_create_walk_in_sale(   -- 100, under the 5000 line cap
    '[{"custom":true,"label":"x","price":100,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":100}]'::jsonb, gen_random_uuid());
  BEGIN PERFORM public.staff_create_walk_in_sale(  -- over the CASHIER line cap
    '[{"custom":true,"label":"big","price":6000,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":6000}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: cashier line over the tighter cap';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'custom line exceeds the % cap', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- the same 6000 line is fine for a MANAGER (global 50000 cap)
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz445))::text, true);
  PERFORM public.staff_shift_open(0, gen_random_uuid());
  PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"big","price":6000,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":6000}]'::jsonb, gen_random_uuid(),
    0, NULL, (SELECT branch1 FROM zz445));
END $$;
RESET ROLE;

-- per-shift count cap: one custom line already on the cashier's shift
SELECT set_config('request.jwt.claims', '{}', true);
update public.platform_settings
   set feature_flags = feature_flags || '{"cashier_custom_per_shift_count":1}'::jsonb
 where id = 'default';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"y","price":50,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":50}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: shift count cap not enforced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines: shift count cap reached', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
-- per-shift value cap: 100 already sold, cap 150, another 100 pushes past
-- #267 batch: a single request must not outrun the caps. Persisted on
-- this shift: 1 custom line of 100. Count cap 3: lines 1-2 pass
-- (1+1, 2+1 <= 3), line 3 is refused (3+1 > 3). Pre-fix every line saw
-- only the persisted 1 and the whole batch passed.
SELECT set_config('request.jwt.claims', '{}', true);
update public.platform_settings
   set feature_flags = feature_flags || '{"cashier_custom_per_shift_count":3,"cashier_custom_per_shift_value":100000}'::jsonb
 where id = 'default';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"b1","price":10,"qty":1},{"custom":true,"label":"b2","price":10,"qty":1},{"custom":true,"label":"b3","price":10,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":30}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: batch outran the count cap';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines: shift count cap reached', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.pos_sales s
           WHERE s.merchant_id = (SELECT merchant FROM zz445)
             AND s.items::text LIKE '%b1%') = 0,
    'refused batch leaked a sale row';
END $$;
-- #267 batch value: cap 150 with 100 persisted; two lines of 40 in ONE
-- request: 100+40 <= 150 then 140+40 > 150. Pre-fix both lines saw 100.
SELECT set_config('request.jwt.claims', '{}', true);
update public.platform_settings
   set feature_flags = feature_flags || '{"cashier_custom_per_shift_count":50,"cashier_custom_per_shift_value":150}'::jsonb
 where id = 'default';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"v1","price":40,"qty":1},{"custom":true,"label":"v2","price":40,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":80}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: batch outran the value cap';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines: shift value cap reached', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM public.pos_sales s
           WHERE s.merchant_id = (SELECT merchant FROM zz445)
             AND s.items::text LIKE '%v1%') = 0,
    'refused value batch leaked a sale row';
END $$;

SELECT set_config('request.jwt.claims', '{}', true);
update public.platform_settings
   set feature_flags = feature_flags || '{"cashier_custom_per_shift_count":50,"cashier_custom_per_shift_value":150}'::jsonb
 where id = 'default';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"z","price":100,"qty":1}]'::jsonb,
    '[{"method":"cash","amount":100}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: shift value cap not enforced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'custom lines: shift value cap reached', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 6) liveness + close report: flip mid-shift ================
-- flip the type away with the cashier's shift OPEN: new sales refuse, but
-- the close and the void are NEVER gated (security condition 3).
update public.merchants set type = 'service' where id = (select merchant from zz445);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_close jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1}]', (SELECT product FROM zz445))::jsonb,
    '[{"method":"cash","amount":25}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: sale after type flip';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'staff sales need a cashier-type shop', 'wrong error: ' || SQLERRM; END;
  -- close STILL works, and the report counts + flags the custom lines
  v_close := public.staff_shift_close(775);
  ASSERT (v_close -> 'custom_lines' ->> 'count')::int = 1,
    'close report lost the custom lines: ' || v_close::text;
  ASSERT (v_close -> 'custom_lines' ->> 'value')::numeric = 100,
    'close report custom value wrong: ' || v_close::text;
  ASSERT (v_close -> 'custom_lines' ->> 'flagged')::boolean IS TRUE,
    'close report did not flag custom lines';
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.pos_shifts s
    WHERE s.merchant_id = (SELECT merchant FROM zz445) AND s.closed_at IS NOT NULL
      AND (s.totals -> 'custom_lines' ->> 'count')::int = 1
      AND (s.totals -> 'custom_lines' ->> 'flagged')::boolean IS TRUE),
    'shift totals row lost the custom_lines flag';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT merchant FROM zz445) AND e.kind = 'shift_closed'
      AND e.detail -> 'custom_lines' IS NOT NULL),
    'shift_closed event lost the custom_lines detail';
END $$;
-- void STILL works on the flipped type (manager; restores stock exactly)
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_sale uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT mgr FROM zz445))::text, true);
  SELECT s.id INTO v_sale FROM public.pos_sales s
   WHERE s.merchant_id = (SELECT merchant FROM zz445)
     AND s.status = 'completed'
     AND s.items @> '[{"custom":false}]'::jsonb
   ORDER BY s.created_at LIMIT 1;
  ASSERT v_sale IS NOT NULL, 'no catalog sale to void';
  PERFORM public.staff_void_sale(v_sale, 'zz445 liveness void');
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT stock_quantity FROM public.products WHERE id = (SELECT product FROM zz445)) = 100,
    'void after type flip did not restore stock';
END $$;
update public.merchants set type = 'restaurant' where id = (select merchant from zz445);

-- ============ 7) #267: shiftless custom refused, shiftless catalog ok ==
-- the cashier's shift is CLOSED here (section 6 closed it). A custom line
-- needs an open shift for ANY payment method; a catalog noncash sale
-- without a shift stays allowed.
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz445))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    '[{"custom":true,"label":"x","price":10,"qty":1}]'::jsonb,
    '[{"method":"instapay","amount":10}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz445 sentinel: shiftless noncash custom allowed';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz445 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'open a shift before custom lines', 'wrong error: ' || SQLERRM; END;
  PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1}]', (SELECT product FROM zz445))::jsonb,
    '[{"method":"instapay","amount":25}]'::jsonb, gen_random_uuid());
END $$;
RESET ROLE;

SELECT '445 suite OK' AS marker;
ROLLBACK;
