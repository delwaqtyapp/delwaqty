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

-- ============ 0) flag gate: presets default OFF =========================
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz446))::text, true);
  BEGIN PERFORM public.merchant_apply_preset('cafe', (SELECT cafe FROM zz446));
    RAISE EXCEPTION 'zz446 sentinel: preset applied with the flag off';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'presets are not enabled', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims', '{}', true);
UPDATE public.platform_settings
   SET feature_flags = feature_flags || '{"merchant_presets":true}'::jsonb
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

-- ============ 3.5) #268 mixed-case duplicate, #269 max semantics, NB-3 floor
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_espresso uuid;
  v_size_med uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz446))::text, true);
  SELECT p.id INTO v_espresso FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'espresso';
  SELECT o.id INTO v_size_med FROM public.product_modifier_options o
    JOIN public.product_modifier_groups g ON g.id = o.group_id
   WHERE g.product_id = v_espresso AND g.preset_key = 'size' AND o.preset_key = 'medium';

  -- #268: the same option twice, second time in UPPERCASE text
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s"]}]',
           v_espresso, v_size_med, upper(v_size_med::text))::jsonb,
    '[{"method":"cash","amount":43}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: case-variant duplicate accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'duplicate modifier', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;

-- #269 + NB-3 fixture: owner groups/options on the owner's own product
-- (direct service-role insert, the suites' fixture convention)
DO $$
DECLARE
  v_g uuid;
BEGIN
  INSERT INTO public.product_modifier_groups(id, product_id, name, is_required, max_selections)
  VALUES (gen_random_uuid(), (SELECT custom_product FROM zz446), 'zz446-open', false, NULL)
  RETURNING id INTO v_g;
  INSERT INTO public.product_modifier_options(group_id, name, price_adjustment) VALUES
    (v_g, 'zz446-o1', 1), (v_g, 'zz446-o2', 2), (v_g, 'zz446-o3', 3);
  INSERT INTO public.product_modifier_groups(id, product_id, name, is_required, max_selections)
  VALUES (gen_random_uuid(), (SELECT custom_product FROM zz446), 'zz446-neg', false, NULL)
  RETURNING id INTO v_g;
  INSERT INTO public.product_modifier_options(group_id, name, price_adjustment) VALUES
    (v_g, 'zz446-neg50', -50), (v_g, 'zz446-neg20', -20);
END $$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_g uuid; v_gneg uuid;
  v_o1 uuid; v_o2 uuid; v_o3 uuid; v_neg50 uuid; v_neg20 uuid;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz446))::text, true);
  SELECT g.id INTO v_g FROM public.product_modifier_groups g
   WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open';
  SELECT g.id INTO v_gneg FROM public.product_modifier_groups g
   WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-neg';
  SELECT o.id INTO v_o1 FROM public.product_modifier_options o WHERE o.group_id = v_g AND o.name = 'zz446-o1';
  SELECT o.id INTO v_o2 FROM public.product_modifier_options o WHERE o.group_id = v_g AND o.name = 'zz446-o2';
  SELECT o.id INTO v_o3 FROM public.product_modifier_options o WHERE o.group_id = v_g AND o.name = 'zz446-o3';
  SELECT o.id INTO v_neg50 FROM public.product_modifier_options o WHERE o.group_id = v_gneg AND o.name = 'zz446-neg50';
  SELECT o.id INTO v_neg20 FROM public.product_modifier_options o WHERE o.group_id = v_gneg AND o.name = 'zz446-neg20';

  -- #269: max NULL = unlimited (three picks pass), matching migration 234
  PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s","%s"]}]',
           (SELECT custom_product FROM zz446), v_o1, v_o2, v_o3)::jsonb,
    '[{"method":"cash","amount":56}]'::jsonb, gen_random_uuid());

  -- NB-3: -50 on a 50 product reaches zero -> refused; -20 leaves 30 -> ok
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s"]}]',
           (SELECT custom_product FROM zz446), v_neg50)::jsonb,
    '[{"method":"cash","amount":0}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: zero-priced line accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'line price must stay positive', 'wrong error: ' || SQLERRM; END;
  PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s"]}]',
           (SELECT custom_product FROM zz446), v_neg20)::jsonb,
    '[{"method":"cash","amount":30}]'::jsonb, gen_random_uuid());
END $$;
RESET ROLE;

-- #269: max 0 = unlimited too (service-role UPDATEs; the cashier's RLS
-- would silently no-op them)
UPDATE public.product_modifier_groups SET max_selections = 0
 WHERE product_id = (SELECT custom_product FROM zz446) AND name = 'zz446-open';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz446))::text, true);
  PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s","%s"]}]',
           (SELECT custom_product FROM zz446),
           (SELECT o.id FROM public.product_modifier_options o JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open' AND o.name = 'zz446-o1'),
           (SELECT o.id FROM public.product_modifier_options o JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open' AND o.name = 'zz446-o2'),
           (SELECT o.id FROM public.product_modifier_options o JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open' AND o.name = 'zz446-o3'))::jsonb,
    '[{"method":"cash","amount":56}]'::jsonb, gen_random_uuid());
END $$;
RESET ROLE;
-- #269: a positive max caps
UPDATE public.product_modifier_groups SET max_selections = 1
 WHERE product_id = (SELECT custom_product FROM zz446) AND name = 'zz446-open';
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT cashier FROM zz446))::text, true);
  BEGIN PERFORM public.staff_create_walk_in_sale(
    format('[{"product_id":"%s","qty":1,"modifiers":["%s","%s"]}]',
           (SELECT custom_product FROM zz446),
           (SELECT o.id FROM public.product_modifier_options o JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open' AND o.name = 'zz446-o1'),
           (SELECT o.id FROM public.product_modifier_options o JOIN public.product_modifier_groups g ON g.id = o.group_id
             WHERE g.product_id = (SELECT custom_product FROM zz446) AND g.name = 'zz446-open' AND o.name = 'zz446-o2'))::jsonb,
    '[{"method":"cash","amount":53}]'::jsonb, gen_random_uuid());
    RAISE EXCEPTION 'zz446 sentinel: positive max not enforced';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'zz446 sentinel:%' THEN RAISE; END IF;
    ASSERT SQLERRM = 'modifier group zz446-open selection count refused', 'wrong error: ' || SQLERRM; END;
END $$;
RESET ROLE;
UPDATE public.product_modifier_groups SET max_selections = NULL
 WHERE product_id = (SELECT custom_product FROM zz446) AND name = 'zz446-open';

-- ============ 4) removal: referenced soft, customized detached, rest deleted
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

-- fixture: espresso gets an FK reference (stock move), latte gets an
-- owner-added group, cappuccino gets an owner-added option inside its
-- preset size group.
DO $$
DECLARE
  v_espresso uuid; v_latte uuid; v_capp uuid; v_size uuid;
BEGIN
  SELECT p.id INTO v_espresso FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'espresso';
  SELECT p.id INTO v_latte FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'latte';
  SELECT p.id INTO v_capp FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key = 'cappuccino';
  INSERT INTO public.pos_stock_moves(merchant_id, product_id, kind, qty, note, created_by)
  VALUES ((SELECT cafe FROM zz446), v_espresso, 'count_adjustment', 1, 'zz446 ref', NULL);
  INSERT INTO public.product_modifier_groups(product_id, name, is_required, max_selections)
  VALUES (v_latte, 'zz446-owner-group', false, 1);
  SELECT g.id INTO v_size FROM public.product_modifier_groups g
   WHERE g.product_id = v_capp AND g.preset_key = 'size';
  INSERT INTO public.product_modifier_options(group_id, name, price_adjustment)
  VALUES (v_size, 'zz446-owner-option', 5);
END $$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', (SELECT owner FROM zz446))::text, true);
  v_res := public.merchant_remove_preset('cafe', (SELECT cafe FROM zz446));
  ASSERT (v_res ->> 'deleted')::int = 3
     AND (v_res ->> 'soft_removed')::int = 1
     AND (v_res ->> 'detached')::int = 2,
    'remove outcome counts wrong: ' || v_res::text;
END $$;
RESET ROLE;

DO $$
DECLARE
  v_espresso uuid; v_latte uuid; v_capp uuid;
BEGIN
  SELECT p.id INTO v_espresso FROM public.products p
   WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.preset_key IS NULL AND p.name = 'Espresso';
  -- espresso: soft-removed (referenced), markers cleared, row kept
  ASSERT EXISTS (SELECT 1 FROM public.products p
    WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.name = 'Espresso'
      AND p.is_available IS FALSE AND p.preset_source IS NULL AND p.preset_key IS NULL),
    'referenced preset product was not soft-removed';
  -- latte + cappuccino: detached (owner children kept), still available
  ASSERT EXISTS (SELECT 1 FROM public.products p
    WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.name = 'Latte'
      AND p.is_available IS TRUE AND p.preset_source IS NULL),
    'owner-customized latte was not detached';
  ASSERT EXISTS (SELECT 1 FROM public.products p
    WHERE p.merchant_id = (SELECT cafe FROM zz446) AND p.name = 'Cappuccino'
      AND p.is_available IS TRUE AND p.preset_source IS NULL),
    'owner-customized cappuccino was not detached';
  -- the other three drinks are gone entirely
  ASSERT NOT EXISTS (SELECT 1 FROM public.products p
    WHERE p.merchant_id = (SELECT cafe FROM zz446)
      AND p.name IN ('Fresh Orange Juice', 'Mango Juice', 'Mint Lemonade')),
    'unreferenced preset products survived removal';
  -- owner group + owner option survived with NO preset markers
  ASSERT EXISTS (SELECT 1 FROM public.product_modifier_groups g
    JOIN public.products p ON p.id = g.product_id
    WHERE p.merchant_id = (SELECT cafe FROM zz446) AND g.name = 'zz446-owner-group'
      AND g.preset_source IS NULL),
    'owner-added group lost';
  ASSERT EXISTS (SELECT 1 FROM public.product_modifier_options o
    WHERE o.name = 'zz446-owner-option'),
    'owner-added option lost';
  -- the preset size group on cappuccino was detached (owner option kept),
  -- its preset options deleted
  ASSERT NOT EXISTS (SELECT 1 FROM public.product_modifier_options o
    WHERE o.preset_source = 'cafe'),
    'preset options survived removal';
  ASSERT NOT EXISTS (SELECT 1 FROM public.product_modifier_groups g
    WHERE g.preset_source = 'cafe'),
    'preset groups kept their markers';
  -- the owner's own product was never touched
  ASSERT EXISTS (SELECT 1 FROM public.products WHERE id = (SELECT custom_product FROM zz446)),
    'removal touched a non-preset product';
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT cafe FROM zz446) AND e.kind = 'preset_removed'
      AND (e.detail ->> 'deleted')::int = 3
      AND (e.detail ->> 'soft_removed')::int = 1
      AND (e.detail ->> 'detached')::int = 2),
    'preset_removed audit row wrong';
END $$;

-- ============ 5) NB-6: staff_settings flips are audited ================
UPDATE public.merchants SET staff_settings = '{"cashier_custom_lines":true}'
 WHERE id = (SELECT cafe FROM zz446);
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM public.merchant_staff_events e
    WHERE e.merchant_id = (SELECT cafe FROM zz446)
      AND e.kind = 'staff_settings_changed'
      AND e.detail -> 'new' ->> 'cashier_custom_lines' = 'true'),
    'staff_settings change was not audited';
END $$;

SELECT '446 suite OK' AS marker;
ROLLBACK;
