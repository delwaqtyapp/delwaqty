-- 447: POS sanity caps (security batch 2, two LOWs) =======================
-- LOW1: catalog-line qty had no upper bound (1e12 passed validation and
--   overflowed subtotal arithmetic). Now: catalog qty <= the flag-readable
--   catalog_line_qty_cap (default 10000) and the whole sale total <= the
--   flag-readable sale_total_cap (default 1000000). Both live in
--   platform_settings.feature_flags, so the owner can tune them without a
--   migration; the defaults only stop absurd values.
-- LOW2: the custom-line label had no length limit (5000 chars accepted).
--   Now refused above 120 characters.
-- Scope: staff_create_walk_in_sale only. Open question for reviewers,
--   flagged in the PR body: the customer order path (migration 234 pricing
--   helper) has its own validation and is NOT changed here.
--
-- Dark/flagged as before: the RPC itself still sits behind the
-- cashier_mode_mobile surface flag and the 442-446 gates.

BEGIN;

-- ─── 0. preconditions (A0): 446 objects + exact pre-image pin ───────────
-- 447 REPLACES 446's staff_create_walk_in_sale. Refuse a DB where 442..446
-- never applied or where the live body drifted (446 pattern).
DO $a0$
BEGIN
  IF to_regclass('public.merchant_staff') IS NULL
     OR to_regclass('public.pos_shifts') IS NULL
     OR to_regclass('public.pos_sales') IS NULL
     OR to_regclass('public.products') IS NULL
     OR to_regclass('public.platform_settings') IS NULL THEN
    RAISE EXCEPTION '447 precondition failed: 442/446 tables missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'platform_settings'
                    AND column_name = 'feature_flags') THEN
    RAISE EXCEPTION '447 precondition failed: platform_settings.feature_flags missing (442)';
  END IF;
  IF md5(pg_get_functiondef('public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text)'::regprocedure))
       <> '0a9dbbdf895874107de9a754f7d4d3c2' THEN
    RAISE EXCEPTION '447 precondition failed: staff_create_walk_in_sale drifted from its 446 pre-image';
  END IF;
END
$a0$;

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
  v_catalog_qty_cap numeric;
  v_sale_total_cap numeric;
  v_charge_id bigint;
  v_custom_count int := 0;
  v_custom_value numeric := 0;
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

  -- Shift + serialization (#267): the shared per-staff advisory lock
  -- (#252/S7) and the open-shift derivation run BEFORE line validation,
  -- so the per-shift custom caps below read settled state: concurrent
  -- requests queue here instead of both passing stale totals, and the
  -- caps add this request's own accepted custom lines to the persisted
  -- ones (read once here, accumulated in the loop).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  SELECT s.id INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1;
  IF v_staff.role <> 'branch_manager' THEN
    SELECT count(*), coalesce(sum(round(
             coalesce(public._num_or_null(li.value ->> 'unit_price'), 0)
             * coalesce(public._num_or_null(li.value ->> 'qty'), 0), 2)), 0)
      INTO v_custom_count, v_custom_value
      FROM public.pos_sales s3,
           LATERAL jsonb_array_elements(s3.items) AS li(value)
     WHERE s3.shift_id = v_shift AND s3.status = 'completed'
       AND coalesce((li.value ->> 'custom')::boolean, false) IS TRUE;
  END IF;

  v_custom_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'custom_line_cap')
       FROM public.platform_settings WHERE id = 'default'), 50000);

  -- 447: flag-readable sanity caps, read once per sale (security LOW batch
  -- 2): catalog line qty and the sale total. Defaults only stop absurd
  -- values; the owner can tune them via feature_flags without a migration.
  v_catalog_qty_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'catalog_line_qty_cap')
       FROM public.platform_settings WHERE id = 'default'), 10000);
  v_sale_total_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'sale_total_cap')
       FROM public.platform_settings WHERE id = 'default'), 1000000);

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
      -- 447 (security LOW1): an unbounded catalog qty (1e12 passed
      -- validation) overflows the subtotal arithmetic.
      IF v_qty > v_catalog_qty_cap THEN
        RAISE EXCEPTION 'catalog qty exceeds the % cap', v_catalog_qty_cap;
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
          -- #268: compare the CANONICAL stored uuid text; raw input text
          -- would let a case variant of the same option pass twice.
          IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_mods) e
                      WHERE e.value ->> 'id' = v_mrow.id::text) THEN
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
        -- #269: max_selections NULL or 0 = UNLIMITED, matching the shared
        -- pricing helper (migration 234) the customer order path uses;
        -- only a positive max caps the pick count.
        IF (v_grp.is_required AND v_gcount < 1)
           OR (coalesce(v_grp.max_selections, 0) > 0
               AND v_gcount > v_grp.max_selections) THEN
          RAISE EXCEPTION 'modifier group % selection count refused', v_grp.name;
        END IF;
      END LOOP;
      -- Server-side price: the client never names a price for catalog items.
      v_price := v_product.price + v_mod_total;
      -- NB-3: negative adjustments must never zero out a line.
      IF v_price <= 0 THEN
        RAISE EXCEPTION 'line price must stay positive';
      END IF;
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
        -- #267: a cashier's custom lines ride an open shift for ANY
        -- payment method; a shiftless custom sale reads NULL history and
        -- bypasses every cap AND the shift-close report.
        IF v_shift IS NULL THEN
          RAISE EXCEPTION 'open a shift before custom lines';
        END IF;
        v_custom_cap := coalesce(
          (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_line_cap')
             FROM public.platform_settings WHERE id = 'default'), 5000);
      END IF;
      v_label := nullif(btrim(coalesce(v_item ->> 'label', '')), '');
      IF v_label IS NULL THEN
        RAISE EXCEPTION 'custom item label required';
      END IF;
      -- 447 (security LOW2): bound the stored free-text label.
      IF char_length(v_label) > 120 THEN
        RAISE EXCEPTION 'custom item label too long (max 120)';
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
      IF v_staff.role <> 'branch_manager' THEN
        -- #267: persisted + THIS request's already-accepted custom lines,
        -- both under the staff lock above; a batch cannot outrun the caps.
        IF v_custom_count + 1 > coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_count')
                FROM public.platform_settings WHERE id = 'default'), 10) THEN
          RAISE EXCEPTION 'custom lines: shift count cap reached';
        END IF;
        IF v_custom_value + round(v_price * v_qty, 2) > coalesce(
             (SELECT public._num_or_null(feature_flags ->> 'cashier_custom_per_shift_value')
                FROM public.platform_settings WHERE id = 'default'), 20000) THEN
          RAISE EXCEPTION 'custom lines: shift value cap reached';
        END IF;
        v_custom_count := v_custom_count + 1;
        v_custom_value := v_custom_value + round(v_price * v_qty, 2);
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
  -- 447 (security LOW1): the whole sale is capped too, so many
  -- in-cap lines cannot assemble an absurd total.
  IF v_total > v_sale_total_cap THEN
    RAISE EXCEPTION 'sale total exceeds the % cap', v_sale_total_cap;
  END IF;

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

  -- Shift (#252/S7): derived under the shared per-staff advisory lock
  -- BEFORE the item loop (#267); cash sales REQUIRE an open shift.
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
-- ─── grants: explicit after the replacement (446 pattern) ───────────────
REVOKE EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) TO authenticated;

COMMIT;
