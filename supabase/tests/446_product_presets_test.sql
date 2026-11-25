-- Suite for migration 446 (product presets + sale-path modifiers).
-- Applied by supabase/harness/446_harness.sh AFTER 439..446 on a throwaway
-- clone of h435_template. Synthetic fixtures only. DISPOSABLE-DB-ONLY.

BEGIN;

create temporary table zz446(
  owner uuid, cashier uuid, outsider uuid,
  cafe uuid, restaurant uuid, branch1 uuid, custom_product uuid
);
insert into zz446 select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
grant select on table zz446 to authenticated;

insert into auth.users(id, email)
select u, 'zz446.' || n || '@example.invalid'
from (values ((select owner from zz446), 'owner'),
             ((select cashier from zz446), 'cashier'),
             ((select outsider from zz446), 'outsider')) as x(u, n);
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
select u, 'zz446.' || n || '@example.invalid', 'customer', 'customer', 'approved',
       'zz446' || n, 'active'
from (values ((select owner from zz446), 'owner'),
             ((select cashier from zz446), 'cashier'),
             ((select outsider from zz446), 'outsider')) as x(u, n)
on conflict (id) do update set username = excluded.username, account_status = 'active';

insert into public.merchants(id, name, owner_user_id, type, status) values
  ((select cafe from zz446), 'zz446-cafe', (select owner from zz446), 'cafe', 'active'),
  ((select restaurant from zz446), 'zz446-rest', (select owner from zz446), 'restaurant', 'active');
insert into public.branches(id, merchant_id, name, is_primary) values
  ((select branch1 from zz446), (select cafe from zz446), 'zz446-b1', true);
-- the owner's OWN product: preset removal must never touch it
insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity) values
  ((select custom_product from zz446), (select cafe from zz446), 'zz446-own', 'خاص', 50, 10);

insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, is_active, must_change_password) values
  ((select cafe from zz446), (select cashier from zz446), 'zz446cashier', 'Cashier', 'cashier', (select branch1 from zz446), true, false);

UPDATE public.platform_settings
   SET feature_flags = '{"cashier_mode_mobile":true,"staff_accounts":true}'::jsonb
 WHERE id = 'default';

-- ============ 1) apply: authorization + type match ======================
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz446))::text, true);
  BEGIN PERFORM public.merchant_apply_preset('cafe', (SELECT cafe FROM zz446));
    RAISE EXCEPTION 'zz446 sentinel: non-owner applied a preset';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'merchant not found', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz446))::text, true);
  BEGIN PERFORM public.merchant_apply_preset('cafe', (SELECT restaurant FROM zz446));
    RAISE EXCEPTION 'zz446 sentinel: cafe preset on a restaurant';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'preset does not match this shop type', 'wrong error: ' || SQLERRM; END;
  BEGIN PERFORM public.merchant_apply_preset('nonsense', (SELECT cafe FROM zz446));
    RAISE EXCEPTION 'zz446 sentinel: unknown preset accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'unknown preset', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 2) happy path + idempotency + audit =======================
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz446))::text, true);
  v_res := public.merchant_apply_preset('cafe', (SELECT cafe FROM zz446));
  ASSERT (v_res ->> 'products_inserted')::int = 6, 'first apply wrong: ' || v_res::text;
  v_res := public.merchant_apply_preset('cafe', (SELECT cafe FROM zz446));
  ASSERT (v_res ->> 'products_inserted')::int = 0
     AND (v_res ->> 'products_existing')::int = 6,
    're-apply not idempotent: ' || v_res::text;
END $$;
RESET ROLE;
DO $$
DECLARE
  v_espresso uuid;
BEGIN
  SELECT id INTO v_espresso FROM public.products
   WHERE merchant_id = (SELECT cafe FROM zz446) AND preset_key = 'espresso';
  ASSERT v_espresso IS NOT NULL, 'espresso missing';
  ASSERT (SELECT count(*) FROM public.product_modifier_groups WHERE product_id = v_espresso) = 2,
    'espresso groups missing';
  ASSERT (SELECT count(*) FROM public.product_modifier_options o
            JOIN public.product_modifier_groups g ON g.id = o.group_id
           WHERE g.product_id = v_espresso) = 6, 'espresso options missing';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT cafe FROM zz446) AND e.kind = 'preset_applied'
      AND (e.detail ->> 'products_inserted')::int = 6),
    'preset_applied audit row missing';
END $$;

-- ============ 3) sale path: modifiers priced server-side ================
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_size_med uuid;
  v_shot uuid;
  v_other_opt uuid;
  v_espresso uuid;
  v_latte uuid;
  v_res jsonb;
  v_sale uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz446))::text, true);
  SELECT p.id INTO v_espresso FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'espresso';
  SELECT p.id INTO v_latte FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'latte';
  SELECT o.id INTO v_size_med FROM public.product_modifier_options o
    JOIN public.product_modifier_groups g ON g.id = o.group_id
   WHERE g.product_id = v_espresso AND g.preset_key = 'size' AND o.preset_key = 'medium';
  SELECT o.id INTO v_shot FROM public.product_modifier_options o
    JOIN public.product_modifier_groups g ON g.id = o.group_id
   WHERE g.product_id = v_espresso AND g.preset_key = 'extras' AND o.preset_key = 'shot';
  SELECT o.id INTO v_other_opt FROM public.product_modifier_options o
    JOIN public.product_modifier_groups g ON g.id = o.group_id
   WHERE g.product_id = v_latte AND g.preset_key = 'size' AND o.preset_key = 'small';

  PERFORM public.staff_shift_open(0, gen_random_uuid());

  -- a client-named price is NEVER read: base + medium(10) + shot(8) = 43
  v_res := public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"price":9999,"modifiers":["%s","%s"]}]',
           v_espresso, v_size_med, v_shot)::jsonb,
    '[{"method":"cash","amount":43}]'::jsonb, gen_random_uuid());
  ASSERT (v_res ->> 'total')::numeric = 43, 'modifier pricing wrong: ' || v_res::text;
  v_sale := (v_res ->> 'id')::uuid;
  ASSERT (SELECT (s.items -> 0 ->> 'unit_price')::numeric FROM public.pos_sales s WHERE s.id = v_sale) = 43,
    'stored unit_price wrong';
  ASSERT (SELECT jsonb_array_length(s.items -> 0 -> 'modifiers') FROM public.pos_sales s WHERE s.id = v_sale) = 2,
    'stored modifiers missing';
  ASSERT (SELECT (s.items -> 0 -> 'modifiers' -> 0 ->> 'price_adjustment')::numeric
            FROM public.pos_sales s WHERE s.id = v_sale) IN (0, 10, 8),
    'client price leaked into the stored modifiers';

  -- modifier of ANOTHER product refused
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s"]}]', v_espresso, v_size_med, v_other_opt)::jsonb,
    '[{"method":"cash","amount":43}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: foreign modifier accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'unknown modifier for this product', 'wrong error: ' || SQLERRM; END;

  -- required size group missing refused
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1}]', v_espresso)::jsonb,
    '[{"method":"cash","amount":25}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: required group skipped';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'modifier group % selection count refused', 'wrong error: ' || SQLERRM; END;

  -- two sizes exceed max_selections
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s","%s"]}]',
           v_espresso, v_size_med, v_shot,
           (SELECT o.id FROM public.product_modifier_options o
              JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = v_espresso AND g.preset_key = 'size' AND o.preset_key = 'large'))::jsonb,
    '[{"method":"cash","amount":58}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: max selections not enforced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM LIKE 'modifier group % selection count refused', 'wrong error: ' || SQLERRM; END;

  -- duplicate modifier refused
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s","%s"]}]', v_espresso, v_size_med, v_shot, v_shot)::jsonb,
    '[{"method":"cash","amount":51}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: duplicate modifier accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'duplicate modifier', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- ============ 4) removal: ONLY preset rows, owner-only ==================
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT outsider FROM zz446))::text, true);
  BEGIN PERFORM public.merchant_remove_preset('cafe', (SELECT cafe FROM zz446));
    RAISE EXCEPTION 'zz446 sentinel: non-owner removed a preset';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'merchant not found', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz446))::text, true);
  v_res := public.merchant_remove_preset('cafe', (SELECT cafe FROM zz446));
  ASSERT (v_res ->> 'products_removed')::int = 6, 'remove count wrong: ' || v_res::text;
END $$;
RESET ROLE;
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.products WHERE id = (SELECT custom_product FROM zz446)),
    'removal touched a non-preset product';
  ASSERT NOT EXISTS (SELECT 1 FROM public.products
    WHERE merchant_id = (SELECT cafe FROM zz446) AND preset_source = 'cafe'),
    'preset products survived removal';
  ASSERT NOT EXISTS (SELECT 1 FROM public.product_modifier_options o
    WHERE o.preset_source = 'cafe' AND EXISTS (
      SELECT 1 FROM public.product_modifier_groups g
        JOIN public.products p ON p.id = g.product_id
       WHERE g.id = o.group_id AND p.merchant_id = (SELECT cafe FROM zz446))),
    'preset options survived removal';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT cafe FROM zz446) AND e.kind = 'preset_removed'),
    'preset_removed audit row missing';
END $$;

SELECT '446 suite OK' AS marker;
ROLLBACK;
