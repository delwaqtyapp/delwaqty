-- 446: product presets + sale-path modifiers (PR-B part 2) =================
-- Dark/flagged, migrations first. Security condition 6:
--  * presets apply owner-only with is_merchant_owner on the server-derived
--    merchant; the preset must match the merchant type (the cafe preset is
--    for cafe/juice_shop only);
--  * idempotent unique keys (preset_source + preset_key) so re-applying a
--    preset is a no-op;
--  * removal deletes ONLY preset_source rows;
--  * modifier prices are read from the DB at sale time; group min/max rules
--    are enforced server-side; a modifier must belong to the product sold;
--  * REVOKE-first on the new tables; an audit row on every apply/remove;
--  * negative tests in supabase/tests/446_product_presets_test.sql.

-- ─── 1. audit kinds (precondition pin, then drop+add) ─────────────────
DO $g$
DECLARE
  v_chk text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v_chk FROM pg_constraint
   WHERE conname = 'merchant_staff_events_kind_check' AND conrelid = 'public.merchant_staff_events'::regclass;
  IF v_chk IS DISTINCT FROM 'CHECK ((kind = ANY (ARRAY[''created''::text, ''role_changed''::text, ''branch_changed''::text, ''disabled''::text, ''enabled''::text, ''password_reset''::text, ''walk_in_sale''::text, ''void_sale''::text, ''debt_payment''::text, ''shift_opened''::text, ''shift_closed''::text, ''order_status''::text, ''refused''::text, ''password_changed''::text])))' THEN
    RAISE EXCEPTION '446 precondition failed: merchant_staff_events_kind_check drifted: %', v_chk;
  END IF;
END $g$;
ALTER TABLE public.merchant_staff_events DROP CONSTRAINT merchant_staff_events_kind_check;
ALTER TABLE public.merchant_staff_events ADD CONSTRAINT merchant_staff_events_kind_check
  CHECK ((kind = ANY (ARRAY['created'::text, 'role_changed'::text, 'branch_changed'::text,
    'disabled'::text, 'enabled'::text, 'password_reset'::text, 'walk_in_sale'::text,
    'void_sale'::text, 'debt_payment'::text, 'shift_opened'::text, 'shift_closed'::text,
    'order_status'::text, 'refused'::text, 'password_changed'::text,
    'preset_applied'::text, 'preset_removed'::text])));

-- ─── 2. preset markers on the EXISTING modifier system ───────────────
-- The baseline already has product_modifier_groups (is_required,
-- max_selections) + product_modifier_options (price_adjustment) with
-- owner-write RLS; 446 adds only the preset provenance columns and the
-- idempotency keys, no parallel tables.
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS preset_source text,
  ADD COLUMN IF NOT EXISTS preset_key text;
ALTER TABLE public.product_modifier_groups
  ADD COLUMN IF NOT EXISTS preset_source text,
  ADD COLUMN IF NOT EXISTS preset_key text;
ALTER TABLE public.product_modifier_options
  ADD COLUMN IF NOT EXISTS preset_source text,
  ADD COLUMN IF NOT EXISTS preset_key text;

-- Idempotent preset keys (condition 6): one row per (scope, source, key).
CREATE UNIQUE INDEX products_preset_uq
  ON public.products (merchant_id, preset_source, preset_key)
  WHERE preset_source IS NOT NULL;
CREATE UNIQUE INDEX pmod_groups_preset_uq
  ON public.product_modifier_groups (product_id, preset_source, preset_key)
  WHERE preset_source IS NOT NULL;
CREATE UNIQUE INDEX pmod_options_preset_uq
  ON public.product_modifier_options (group_id, preset_source, preset_key)
  WHERE preset_source IS NOT NULL;

-- ─── 3. preset apply/remove (owner-only, type-matched, audited) ───────
CREATE FUNCTION public._resolve_owned_merchant(p_merchant_id uuid)
 RETURNS public.merchants
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_m public.merchants%ROWTYPE;
  v_n int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  -- Ownership is verified server-side; a caller-supplied id is a CLAIM
  -- until is_merchant_owner proves it (condition 6).
  IF p_merchant_id IS NOT NULL THEN
    SELECT * INTO v_m FROM public.merchants WHERE id = p_merchant_id;
    IF NOT FOUND OR NOT public.is_merchant_owner(v_m.id) THEN
      RAISE EXCEPTION 'merchant not found';
    END IF;
    RETURN v_m;
  END IF;
  SELECT count(*) INTO v_n FROM public.merchants WHERE owner_user_id = v_caller;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'merchant required';
  END IF;
  SELECT * INTO v_m FROM public.merchants WHERE owner_user_id = v_caller;
  RETURN v_m;
END;
$function$;
REVOKE ALL ON FUNCTION public._resolve_owned_merchant(uuid) FROM PUBLIC, anon, authenticated;

-- The cafe preset: drinks with a required size group and an optional
-- extras group. Type-matched to cafe/juice_shop (condition 6).
CREATE FUNCTION public.merchant_apply_preset(p_preset text, p_merchant_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_m public.merchants%ROWTYPE;
  v_catalog jsonb;
  v_prod record;
  v_grp record;
  v_mod record;
  v_pid uuid;
  v_gid uuid;
  v_inserted int := 0;
  v_existing int := 0;
BEGIN
  v_m := public._resolve_owned_merchant(p_merchant_id);
  IF p_preset IS DISTINCT FROM 'cafe' THEN
    RAISE EXCEPTION 'unknown preset';
  END IF;
  IF v_m.type NOT IN ('cafe','juice_shop') THEN
    RAISE EXCEPTION 'preset does not match this shop type';
  END IF;
  v_catalog := '[
    {"key":"espresso","name":"Espresso","name_ar":"إسبريسو","price":25},
    {"key":"latte","name":"Latte","name_ar":"لاتيه","price":35},
    {"key":"cappuccino","name":"Cappuccino","name_ar":"كابتشينو","price":35},
    {"key":"orange_juice","name":"Fresh Orange Juice","name_ar":"عصير برتقال طازج","price":30},
    {"key":"mango_juice","name":"Mango Juice","name_ar":"عصير مانجو","price":35},
    {"key":"mint_lemonade","name":"Mint Lemonade","name_ar":"ليمون بالنعناع","price":28}
  ]'::jsonb;
  FOR v_prod IN SELECT value FROM jsonb_array_elements(v_catalog) LOOP
    INSERT INTO public.products
      (merchant_id, name, name_ar, price, stock_quantity, is_available, preset_source, preset_key)
    VALUES
      (v_m.id, v_prod.value ->> 'name', v_prod.value ->> 'name_ar',
       (v_prod.value ->> 'price')::numeric, NULL, true, 'cafe', v_prod.value ->> 'key')
    ON CONFLICT (merchant_id, preset_source, preset_key) WHERE preset_source IS NOT NULL
    DO NOTHING
    RETURNING id INTO v_pid;
    IF v_pid IS NULL THEN
      SELECT p2.id INTO v_pid FROM public.products p2
       WHERE p2.merchant_id = v_m.id AND p2.preset_source = 'cafe'
         AND p2.preset_key = v_prod.value ->> 'key';
      v_existing := v_existing + 1;
    ELSE
      v_inserted := v_inserted + 1;
    END IF;
    -- every drink: required size group (base price = small), optional extras
    FOR v_grp IN SELECT value FROM jsonb_array_elements('[
      {"key":"size","name":"Size","name_ar":"الحجم","min":1,"max":1,"mods":[
        {"key":"small","name":"Small","name_ar":"صغير","delta":0},
        {"key":"medium","name":"Medium","name_ar":"وسط","delta":10},
        {"key":"large","name":"Large","name_ar":"كبير","delta":15}]},
      {"key":"extras","name":"Extras","name_ar":"إضافات","min":0,"max":3,"mods":[
        {"key":"shot","name":"Extra shot","name_ar":"شوت إضافي","delta":8},
        {"key":"cream","name":"Whipped cream","name_ar":"كريمة مخفوقة","delta":10},
        {"key":"caramel","name":"Caramel","name_ar":"كراميل","delta":6}]}
    ]'::jsonb) LOOP
      INSERT INTO public.product_modifier_groups
        (product_id, name, name_ar, is_required, max_selections, preset_source, preset_key)
      VALUES
        (v_pid, v_grp.value ->> 'name', v_grp.value ->> 'name_ar',
         ((v_grp.value ->> 'min')::int > 0), (v_grp.value ->> 'max')::int,
         'cafe', v_grp.value ->> 'key')
      ON CONFLICT (product_id, preset_source, preset_key) WHERE preset_source IS NOT NULL
      DO NOTHING
      RETURNING id INTO v_gid;
      IF v_gid IS NULL THEN
        SELECT g2.id INTO v_gid FROM public.product_modifier_groups g2
         WHERE g2.product_id = v_pid AND g2.preset_source = 'cafe'
           AND g2.preset_key = v_grp.value ->> 'key';
      END IF;
      FOR v_mod IN SELECT value FROM jsonb_array_elements(v_grp.value -> 'mods') LOOP
        INSERT INTO public.product_modifier_options
          (group_id, name, name_ar, price_adjustment, preset_source, preset_key)
        VALUES
          (v_gid, v_mod.value ->> 'name', v_mod.value ->> 'name_ar',
           (v_mod.value ->> 'delta')::numeric, 'cafe', v_mod.value ->> 'key')
        ON CONFLICT (group_id, preset_source, preset_key) WHERE preset_source IS NOT NULL
        DO NOTHING;
      END LOOP;
    END LOOP;
  END LOOP;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (NULL, v_m.id, 'preset_applied',
          jsonb_build_object('preset', 'cafe', 'products_inserted', v_inserted,
                             'products_existing', v_existing),
          auth.uid());
  RETURN jsonb_build_object('ok', true, 'preset', 'cafe',
                            'products_inserted', v_inserted,
                            'products_existing', v_existing);
END;
$function$;
REVOKE ALL ON FUNCTION public.merchant_apply_preset(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_apply_preset(text, uuid) TO authenticated;

-- Removal deletes ONLY preset_source rows (condition 6); the owner's own
-- products and groups are never touched. Groups/modifiers cascade.
CREATE FUNCTION public.merchant_remove_preset(p_preset text, p_merchant_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_m public.merchants%ROWTYPE;
  v_n int;
BEGIN
  v_m := public._resolve_owned_merchant(p_merchant_id);
  IF p_preset IS DISTINCT FROM 'cafe' THEN
    RAISE EXCEPTION 'unknown preset';
  END IF;
  WITH del AS (
    DELETE FROM public.products
     WHERE merchant_id = v_m.id AND preset_source = p_preset
    RETURNING id
  )
  SELECT count(*) INTO v_n FROM del;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (NULL, v_m.id, 'preset_removed',
          jsonb_build_object('preset', p_preset, 'products_removed', v_n),
          auth.uid());
  RETURN jsonb_build_object('ok', true, 'preset', p_preset, 'products_removed', v_n);
END;
$function$;
REVOKE ALL ON FUNCTION public.merchant_remove_preset(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_remove_preset(text, uuid) TO authenticated;


-- ─── 4. sale path: modifiers priced server-side (condition 6) ──────
CREATE OR REPLACE FUNCTION public.staff_create_walk_in_sale(
  p_items jsonb,
  p_payments jsonb,
  p_client_op_id uuid,
  p_discount numeric DEFAULT 0,
  p_pos_customer_id uuid DEFAULT NULL,
  p_branch_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_merchant public.merchants%ROWTYPE;
  v_branch uuid;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_label text;
  v_qty numeric;
  v_price numeric;
  v_subtotal numeric := 0;
  v_discount numeric := round(coalesce(p_discount, 0), 2);
  v_total numeric;
  v_pay jsonb;
  v_pay_sum numeric := 0;
  v_pay_amount numeric;
  v_methods text[] := '{}';
  v_deferred numeric := 0;
  v_sale_id uuid;
  v_shift uuid;
  v_normalized jsonb := '[]'::jsonb;
  v_stock_ops jsonb := '[]'::jsonb;
  v_applied numeric := 0;
  v_op jsonb;
  v_existing public.pos_sales%ROWTYPE;
  v_request_hash text;
  v_custom_cap numeric;
  v_charge_id bigint;
  v_custom_count int := 0;
  v_custom_value numeric := 0;
  v_shift_caps uuid;
  v_mods jsonb;
  v_mod_total numeric;
  v_mod jsonb;
  v_mrow record;
  v_grp record;
  v_gcount int;
  CASHIER_DISCOUNT_CAP constant numeric := 0.10;
  MANAGER_DISCOUNT_CAP constant numeric := 0.50;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);

  -- Branch: derived from the staff row; a manager over all branches must
  -- pass one and it is validated against the merchant.
  v_branch := v_staff.branch_id;
  IF v_branch IS NULL THEN
    IF p_branch_id IS NULL THEN
      RAISE EXCEPTION 'branch required for an all-branches manager';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.branches b
                    WHERE b.id = p_branch_id AND b.merchant_id = v_staff.merchant_id) THEN
      RAISE EXCEPTION 'branch does not belong to this shop';
    END IF;
    v_branch := p_branch_id;
  END IF;

  IF p_client_op_id IS NULL THEN
    RAISE EXCEPTION 'client op id required';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = v_staff.merchant_id;

  -- 445 gate (security condition 3): same current-type check as
  -- staff_shift_open. A flip mid-shift never strands the drawer: close
  -- and void stay ungated, but no NEW sale is taken.
  IF NOT public.is_cashier_type(v_merchant.type) THEN
    RAISE EXCEPTION 'staff sales need a cashier-type shop';
  END IF;

  -- Canonical request fingerprint (#256): the replay contract compares the
  -- WHOLE request, not just the op id.
  v_request_hash := md5(jsonb_build_object(
    'items', p_items, 'payments', p_payments, 'discount', v_discount,
    'customer', p_pos_customer_id, 'branch', v_branch, 'notes', p_notes)::text);

  -- Same-staff serialization for this op id: concurrent first calls queue
  -- here instead of racing to unique_violation (#256).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.merchant_id::text || ':' || p_client_op_id::text, 442001));

  -- Idempotency: replay only for the SAME staff member with the SAME
  -- payload; anything else with this op id is a conflict.
  SELECT * INTO v_existing FROM public.pos_sales s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.idempotency_key = p_client_op_id::text
   LIMIT 1;
  IF FOUND THEN
    IF v_existing.staff_id IS DISTINCT FROM v_staff.id
       OR v_existing.branch_id IS DISTINCT FROM v_branch
       OR v_existing.request_hash IS DISTINCT FROM v_request_hash THEN
      RAISE EXCEPTION 'idempotency key reused with a different request';
    END IF;
    RETURN jsonb_build_object('id', v_existing.id, 'total', v_existing.total_amount,
                              'idempotent_replay', true);
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items required';
  END IF;

  v_custom_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'custom_line_cap')
       FROM public.platform_settings WHERE id = 'default'), 50000);

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_applied := 0;
    v_mods := '[]'::jsonb;
    v_mod_total := 0;
    IF v_item ? 'product_id' THEN
      -- S2/#255: a product_id key is a catalog line, ALWAYS. Malformed or
      -- unknown ids refuse; they never fall through to free-text pricing.
      IF (v_item ->> 'product_id') !~ '^[0-9a-fA-F-]{36}$' THEN
        RAISE EXCEPTION 'malformed product_id %', v_item ->> 'product_id';
      END IF;
      v_qty := public._num_or_null(v_item ->> 'qty');
      IF v_qty IS NULL OR v_qty <= 0 OR v_qty <> trunc(v_qty) THEN
        RAISE EXCEPTION 'catalog qty must be a positive integer';
      END IF;
      SELECT * INTO v_product FROM public.products
       WHERE id = (v_item ->> 'product_id')::uuid
         AND merchant_id = v_staff.merchant_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown product %', v_item ->> 'product_id';
      END IF;
      IF v_product.is_available IS NOT TRUE THEN
        RAISE EXCEPTION 'product unavailable %', coalesce(v_product.name_ar, v_product.name);
      END IF;
      -- 446 modifiers: the client sends IDS ONLY; names and prices come
      -- from the DB at sale time (condition 6). Every modifier must
      -- belong to THIS product through its group, and each group of the
      -- product enforces its min/max selection count -- including a
      -- required group on a line that sent no modifiers at all.
      IF v_item ? 'modifiers' THEN
        IF jsonb_typeof(v_item -> 'modifiers') <> 'array' THEN
          RAISE EXCEPTION 'modifiers must be an array of ids';
        END IF;
        FOR v_mod IN SELECT value FROM jsonb_array_elements(v_item -> 'modifiers') LOOP
          IF (v_mod #>> '{}') IS NULL OR (v_mod #>> '{}') !~ '^[0-9a-fA-F-]{36}$' THEN
            RAISE EXCEPTION 'malformed modifier id';
          END IF;
          SELECT o2.id, o2.name, o2.price_adjustment, g2.id AS gid
            INTO v_mrow
            FROM public.product_modifier_options o2
            JOIN public.product_modifier_groups g2 ON g2.id = o2.group_id
           WHERE o2.id = (v_mod #>> '{}')::uuid
             AND g2.product_id = v_product.id;
          IF NOT FOUND THEN
            RAISE EXCEPTION 'unknown modifier for this product';
          END IF;
          IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_mods) e
                      WHERE e.value ->> 'id' = (v_mod #>> '{}')) THEN
            RAISE EXCEPTION 'duplicate modifier';
          END IF;
          v_mods := v_mods || jsonb_build_object(
            'id', v_mrow.id, 'name', v_mrow.name,
            'price_adjustment', v_mrow.price_adjustment, 'group_id', v_mrow.gid);
          v_mod_total := v_mod_total + v_mrow.price_adjustment;
        END LOOP;
      END IF;
      FOR v_grp IN SELECT g3.id, g3.name, g3.is_required, g3.max_selections
                     FROM public.product_modifier_groups g3
                    WHERE g3.product_id = v_product.id LOOP
        SELECT count(*) INTO v_gcount FROM jsonb_array_elements(v_mods) e
         WHERE (e.value ->> 'group_id')::uuid = v_grp.id;
        IF (v_grp.is_required AND v_gcount < 1)
           OR v_gcount > coalesce(v_grp.max_selections, 1) THEN
          RAISE EXCEPTION 'modifier group % selection count refused', v_grp.name;
        END IF;
      END LOOP;
      -- Server-side price: the client never names a price for catalog items.
      v_price := v_product.price + v_mod_total;
      v_label := coalesce(v_product.name_ar, v_product.name);
      -- Stock ops are collected and applied after the sale row exists so
      -- the moves can link back to it (S3); same transaction = atomic.
      IF v_product.stock_quantity IS NOT NULL THEN
        v_applied := v_qty;
        v_stock_ops := v_stock_ops || jsonb_build_object(
          'product_id', v_product.id, 'qty', v_qty, 'label', v_label);
      END IF;
    ELSE
      -- Free-text line (service-shop simple invoice): EXPLICIT custom only
      -- (S2), price > 0, manager or service-type shop, value-capped.
      IF coalesce((v_item ->> 'custom')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'non-catalog lines must be explicit custom items';
      END IF;
      -- 445 per-type custom-line rule (security condition 4): managers
      -- keep custom lines under the global cap. A CASHIER gets them only
      -- when the owner opts the merchant in (staff_settings.
      -- cashier_custom_lines, default off), then under the tighter
      -- cashier per-line cap plus per-shift count and value caps.
      -- Simple-service types never reach this RPC: the type gate above
      -- refuses non-cashier types; their surface is the provider app's
      -- simple invoice, not the POS.
      IF v_staff.role <> 'branch_manager' THEN
        IF coalesce((v_merchant.staff_settings ->> 'cashier_custom_lines')::boolean, false) IS NOT TRUE THEN
          RAISE EXCEPTION 'custom lines need a branch manager';
        END IF;
        v_custom_cap := coalesce(
          (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_line_cap')
             FROM public.platform_settings WHERE id = 'default'), 5000);
        -- Per-shift caps count the cashier's OWN open shift (none yet:
        -- zero). The shift row is re-derived later under the advisory
        -- lock; caps are a fraud brake, not a serialization point.
        SELECT s2.id INTO v_shift_caps FROM public.pos_shifts s2
         WHERE s2.merchant_id = v_staff.merchant_id
           AND s2.opened_by_staff = v_staff.id AND s2.closed_at IS NULL
         ORDER BY s2.opened_at DESC LIMIT 1;
        SELECT count(*), coalesce(sum(round(
                 coalesce(public._num_or_null(li.value ->> 'unit_price'), 0)
                 * coalesce(public._num_or_null(li.value ->> 'qty'), 0), 2)), 0)
          INTO v_custom_count, v_custom_value
          FROM public.pos_sales s3,
               LATERAL jsonb_array_elements(s3.items) AS li(value)
         WHERE s3.shift_id = v_shift_caps AND s3.status = 'completed'
           AND coalesce((li.value ->> 'custom')::boolean, false) IS TRUE;
        IF v_custom_count >= coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_count')
                FROM public.platform_settings WHERE id = 'default'), 10) THEN
          RAISE EXCEPTION 'custom lines: shift count cap reached';
        END IF;
      END IF;
      v_label := nullif(btrim(coalesce(v_item ->> 'label', '')), '');
      IF v_label IS NULL THEN
        RAISE EXCEPTION 'custom item label required';
      END IF;
      v_price := round(coalesce(public._num_or_null(v_item ->> 'price'), -1), 2);
      IF v_price <= 0 THEN
        RAISE EXCEPTION 'custom item price must be a number > 0';
      END IF;
      v_qty := round(coalesce(public._num_or_null(v_item ->> 'qty'), 0), 3);
      IF v_qty <= 0 THEN
        RAISE EXCEPTION 'qty must be a positive number';
      END IF;
      IF v_price * v_qty > v_custom_cap THEN
        RAISE EXCEPTION 'custom line exceeds the % cap', v_custom_cap;
      END IF;
      IF v_staff.role <> 'branch_manager'
         AND v_custom_value + round(v_price * v_qty, 2) > coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_value')
                FROM public.platform_settings WHERE id = 'default'), 20000) THEN
        RAISE EXCEPTION 'custom lines: shift value cap reached';
      END IF;
    END IF;
    v_subtotal := v_subtotal + round(v_price * v_qty, 2);
    -- Applied-stock metadata (#251): every staff-sale line records what
    -- the sale ACTUALLY decremented -- the qty for tracked catalog lines,
    -- an explicit 0 for untracked and custom lines -- so a later void
    -- (either gate) never has to guess, and tracking that starts after
    -- the sale cannot credit invented stock.
    -- 'custom' marks the free-text lines so the shift close report can
    -- count and flag them (445); pre-445 rows simply lack the key.
    v_normalized := v_normalized || jsonb_build_object(
      'product_id', v_item ->> 'product_id', 'label', v_label,
      'qty', v_qty, 'unit_price', v_price, 'stock_applied', v_applied,
      'modifiers', v_mods,
      'custom', NOT (v_item ? 'product_id'));
  END LOOP;

  IF v_discount < 0 OR v_discount > v_subtotal * (CASE v_staff.role
        WHEN 'cashier' THEN CASHIER_DISCOUNT_CAP
        ELSE MANAGER_DISCOUNT_CAP END) THEN
    RAISE EXCEPTION 'discount exceeds the % cap', v_staff.role;
  END IF;
  v_total := round(v_subtotal - v_discount, 2);

  IF p_payments IS NULL OR jsonb_typeof(p_payments) <> 'array'
     OR jsonb_array_length(p_payments) = 0 THEN
    RAISE EXCEPTION 'payments required';
  END IF;
  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    IF (v_pay ->> 'method') NOT IN ('cash','instapay','vodafone_cash','card','deferred') THEN
      RAISE EXCEPTION 'unknown payment method %', v_pay ->> 'method';
    END IF;
    v_pay_amount := round(coalesce(public._num_or_null(v_pay ->> 'amount'), -1), 2);
    IF v_pay_amount < 0 THEN
      RAISE EXCEPTION 'payment amount must be a number >= 0';
    END IF;
    v_pay_sum := v_pay_sum + v_pay_amount;
    v_methods := v_methods || (v_pay ->> 'method');
    IF (v_pay ->> 'method') = 'deferred' THEN
      v_deferred := v_deferred + v_pay_amount;
    END IF;
  END LOOP;
  IF abs(v_pay_sum - v_total) > 0.001 THEN
    RAISE EXCEPTION 'payments (%) must sum to the total (%)', v_pay_sum, v_total;
  END IF;
  IF v_deferred > 0 AND p_pos_customer_id IS NULL THEN
    RAISE EXCEPTION 'deferred payment requires a customer';
  END IF;
  IF p_pos_customer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pos_customers c
     WHERE c.id = p_pos_customer_id AND c.merchant_id = v_staff.merchant_id
  ) THEN
    RAISE EXCEPTION 'customer does not belong to this shop';
  END IF;

  -- Shift (#252/S7): one shared advisory lock serializes open/sale/close
  -- per staff member; cash sales REQUIRE an open shift.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  SELECT s.id INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1;
  IF 'cash' = ANY(v_methods) AND v_shift IS NULL THEN
    RAISE EXCEPTION 'open a shift before taking cash';
  END IF;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, notes, status, idempotency_key, shift_id, branch_id,
     staff_id, pos_customer_id, request_hash)
  VALUES
    (v_staff.merchant_id, auth.uid(), v_normalized, v_subtotal, v_discount,
     v_total, CASE WHEN array_length(v_methods, 1) = 1 THEN v_methods[1] ELSE 'mixed' END,
     p_notes, 'completed', p_client_op_id::text, v_shift, v_branch,
     v_staff.id, p_pos_customer_id, v_request_hash)
  RETURNING id INTO v_sale_id;

  -- Canonical stock (S12): atomic guarded decrement on
  -- products.stock_quantity; the move records what was ACTUALLY applied
  -- and links to the sale for exact void restore (S3).
  FOR v_op IN SELECT value FROM jsonb_array_elements(v_stock_ops) LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity - (v_op ->> 'qty')::int, updated_at = now()
     WHERE id = (v_op ->> 'product_id')::uuid
       AND stock_quantity >= (v_op ->> 'qty')::int;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'insufficient stock for %', v_op ->> 'label';
    END IF;
    INSERT INTO public.pos_stock_moves
      (merchant_id, product_id, kind, qty, note, created_by, sale_id)
    VALUES
      (v_staff.merchant_id, (v_op ->> 'product_id')::uuid, 'sale',
       -(v_op ->> 'qty')::numeric, 'walk-in sale', auth.uid(), v_sale_id);
  END LOOP;

  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    INSERT INTO public.pos_sale_payments (sale_id, method, amount)
    VALUES (v_sale_id, v_pay ->> 'method', round(public._num_or_null(v_pay ->> 'amount'), 2));
  END LOOP;

  -- أجل (S1): ONE summed charge per sale under its OWN derived key from
  -- the sale id — it can never collide with a debt payment's op id, and a
  -- conflict raises instead of silently dropping the charge.
  IF v_deferred > 0 THEN
    INSERT INTO public.pos_debt_ledger
      (merchant_id, customer_id, sale_id, client_op_id, kind, amount, note, created_by)
    VALUES
      (v_staff.merchant_id, p_pos_customer_id, v_sale_id,
       md5('charge:' || v_sale_id::text)::uuid, 'charge', v_deferred,
       'أجل - بيع محلي', auth.uid())
    ON CONFLICT (merchant_id, client_op_id) DO NOTHING
    RETURNING id INTO v_charge_id;
    IF v_charge_id IS NULL THEN
      RAISE EXCEPTION 'deferred charge conflict for sale %', v_sale_id;
    END IF;
  END IF;

  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'walk_in_sale',
          jsonb_build_object('sale_id', v_sale_id, 'total', v_total,
                             'methods', v_methods, 'branch_id', v_branch),
          auth.uid());

  RETURN jsonb_build_object('id', v_sale_id, 'total', v_total, 'idempotent_replay', false);
EXCEPTION WHEN unique_violation THEN
  -- A concurrent first call slipped past the advisory lock window or the
  -- op id is already taken by a different request (#256): never mask it.
  SELECT * INTO v_existing FROM public.pos_sales s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.idempotency_key = p_client_op_id::text
   LIMIT 1;
  IF FOUND AND v_existing.staff_id IS NOT DISTINCT FROM v_staff.id
     AND v_existing.branch_id IS NOT DISTINCT FROM v_branch
     AND v_existing.request_hash IS NOT DISTINCT FROM v_request_hash THEN
    RETURN jsonb_build_object('id', v_existing.id, 'total', v_existing.total_amount,
                              'idempotent_replay', true);
  END IF;
  RAISE EXCEPTION 'idempotency key reused with a different request';
END;
$function$;
