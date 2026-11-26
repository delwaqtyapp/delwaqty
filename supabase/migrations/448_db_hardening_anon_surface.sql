-- 448: DB hardening — anon surface reduction (phase 1 of the 448/449 plan).
--
-- FINDINGS (lab, 2026-11-26):
--   MEDIUM  anon holds table-level SELECT on public.merchants: email,
--           owner_user_id, phone, staff_settings, lat/lng all readable with
--           just the public anon key (policy "status='active' OR
--           is_merchant_owner(id)").
--   LOW     merchants.staff_settings is in that row (staff feature flags).
--   LOW     service_providers exposes user_id + exact lat/lng to anon.
--   LOW     products exposes sku, barcode, reorder_level, stock_quantity to
--           anon (and to every signed-in user).
--   LOW-MED anon holds table-level INSERT/UPDATE/DELETE on 79-82 public
--           tables; RLS is the only wall.
--
-- PHASE 1 (this file, DB-only, zero breakage for installed builds):
--   1. Move merchants.staff_settings into public.merchant_staff_settings
--      (owner-only RLS, no anon grant). Re-point its 3 prod readers
--      (A0-pinned below): staff_create_walk_in_sale (the cashier custom-line
--      gate), _assert_staff_settings_shape (shape trigger),
--      _audit_staff_settings_change (audit trigger). The trigger functions
--      move to the new table; the walk-in-sale RPC reads the new table.
--      No app code reads staff_settings (verified by grep over lib/, pos/,
--      supabase/functions); merchant-staff-admin does not touch it either.
--      Owner write path: authenticated owner writes own row through RLS;
--      the shape trigger keeps validating.
--   2. Revoke anon INSERT/UPDATE/DELETE on public tables except an
--      evidence-based keep-list. Guest mode browses only; the cart is
--      local; OTP/signup writes go through edge functions (service role).
--      Before/after grant sweeps are in the test file.
--   3. products: REVOKE ALL from anon. No customer/guest code path reads
--      products (customer catalog reads product_inventory); readers are the
--      merchant app (own rows) and admin, both authenticated. The
--      authenticated column trim ships in 449 with the app change (the two
--      wildcard readers are installed builds) — same reasoning as merchants.
--   4. service_providers: recreate the customer view
--      service_providers_with_effective_pricing as a definer view with a
--      fixed column list (NO user_id, latitude, longitude) and the
--      is_available = true filter baked in; revoke base-table SELECT from
--      anon; authenticated keeps column grants on exactly what the
--      installed provider app selects/filters (category_type, user_id,
--      created_at). Owner self-read of lat/lng gets a definer RPC
--      get_my_provider_profile() for the provider app to adopt in 449.
--   5. merchants email/owner_user_id/phone/lat-lng: unchanged in 448 —
--      installed guest + customer builds wildcard-select merchants, so any
--      column revoke breaks them. 449 (app + DB, next priority) ships the
--      merchants_public view + named-column app switch, then revokes.
--
-- A0 PRECONDITIONS (prod-verified 2026-11-26):
--   * merchants.staff_settings jsonb NOT NULL DEFAULT '{}' exists (445-era).
--   * md5(pg_get_functiondef(staff_create_walk_in_sale(jsonb,jsonb,uuid,
--     numeric,uuid,uuid,text))) = 'c081f5c008cc826e5454b54949a10751' (post-447).
--   * md5(pg_get_functiondef(_assert_staff_settings_shape())) =
--     '453b7496ce33d38898d9bd6295a82075' (445 body, live on prod).
--   * md5(pg_get_functiondef(_audit_staff_settings_change())) =
--     'df28bf803c3ac6e47b994929bb6b91fc' (446 body, live on prod).
--   * public.merchant_staff_settings does not exist.
--   * All 3 prod merchants carry staff_settings = '{}' (copy is a no-op).
--
-- Single transaction; stop on first failure. Flags stay off.

BEGIN;

-- ─── A0 preconditions ─────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
                 WHERE attrelid = 'public.merchants'::regclass
                   AND attname = 'staff_settings' AND NOT attisdropped) THEN
    RAISE EXCEPTION '448 precondition failed: merchants.staff_settings missing';
  END IF;
  IF to_regclass('public.merchant_staff_settings') IS NOT NULL THEN
    RAISE EXCEPTION '448 precondition failed: merchant_staff_settings already exists';
  END IF;
  IF md5(pg_get_functiondef('public.staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text)'::regprocedure))
       IS DISTINCT FROM 'c081f5c008cc826e5454b54949a10751' THEN
    RAISE EXCEPTION '448 precondition failed: staff_create_walk_in_sale md5 mismatch (expected post-447 c081f5c0...)';
  END IF;
  IF md5(pg_get_functiondef('public._assert_staff_settings_shape()'::regprocedure))
       IS DISTINCT FROM '453b7496ce33d38898d9bd6295a82075' THEN
    RAISE EXCEPTION '448 precondition failed: _assert_staff_settings_shape md5 mismatch';
  END IF;
  IF md5(pg_get_functiondef('public._audit_staff_settings_change()'::regprocedure))
       IS DISTINCT FROM 'df28bf803c3ac6e47b994929bb6b91fc' THEN
    RAISE EXCEPTION '448 precondition failed: _audit_staff_settings_change md5 mismatch';
  END IF;
END $$;

-- ─── 1. merchant_staff_settings: new owner-only home for the column ──────
CREATE TABLE public.merchant_staff_settings (
  merchant_id uuid PRIMARY KEY REFERENCES public.merchants(id) ON DELETE CASCADE,
  settings    jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.merchant_staff_settings IS
  '448: staff feature flags (e.g. cashier_custom_lines), moved out of '
  'merchants so the public merchant row stops carrying them. Owner-only '
  'through RLS; staff/anon get no grant.';

-- Copy current values (prod today: all '{}', so this is a no-op there).
INSERT INTO public.merchant_staff_settings (merchant_id, settings)
SELECT id, staff_settings FROM public.merchants
WHERE staff_settings IS DISTINCT FROM '{}'::jsonb;

-- No default-privilege leak: created by postgres, so revoke everything
-- defensively, then grant exactly the owner path.
REVOKE ALL ON public.merchant_staff_settings FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.merchant_staff_settings TO authenticated;

ALTER TABLE public.merchant_staff_settings ENABLE ROW LEVEL SECURITY;
-- Owner reads and writes own row. The subquery needs merchants SELECT,
-- which authenticated holds today and keeps after 449 (id/owner_user_id
-- column grants survive the 449 revoke for exactly this reason).
CREATE POLICY merchant_staff_settings_owner ON public.merchant_staff_settings
  AS PERMISSIVE FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.merchants m
                 WHERE m.id = merchant_id AND m.owner_user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.merchants m
                      WHERE m.id = merchant_id AND m.owner_user_id = auth.uid()));

-- Shape check, re-pointed to the new table (same body semantics as the
-- 445 original: object only, known keys only, boolean values only).
CREATE OR REPLACE FUNCTION public._assert_staff_settings_shape()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_key text;
BEGIN
  IF jsonb_typeof(NEW.settings) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'staff_settings must be an object';
  END IF;
  FOR v_key IN SELECT k FROM jsonb_object_keys(NEW.settings) AS k LOOP
    IF v_key NOT IN ('cashier_custom_lines') THEN
      RAISE EXCEPTION 'unknown staff_settings key %', v_key;
    END IF;
    IF jsonb_typeof(NEW.settings -> v_key) IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'staff_settings.% must be a boolean', v_key;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._assert_staff_settings_shape() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_merchant_staff_settings_shape
  BEFORE INSERT OR UPDATE OF settings ON public.merchant_staff_settings
  FOR EACH ROW EXECUTE FUNCTION public._assert_staff_settings_shape();

-- Audit, re-pointed to the new table (same audit_log shape as 446:
-- kind 'staff_settings_changed', entity = merchant id, old/new payloads).
CREATE OR REPLACE FUNCTION public._audit_staff_settings_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- INSERT: the first opt-in matters as much as a flip; old is NULL.
  -- An INSERT of the default '{}' changes no setting and is not audited.
  IF TG_OP = 'INSERT' THEN
    IF NEW.settings IS DISTINCT FROM '{}'::jsonb THEN
      INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
      VALUES (NULL, NEW.merchant_id, 'staff_settings_changed',
              jsonb_build_object('old', NULL, 'new', NEW.settings),
              auth.uid());
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.settings IS DISTINCT FROM OLD.settings THEN
    INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
    VALUES (NULL, NEW.merchant_id, 'staff_settings_changed',
            jsonb_build_object('old', OLD.settings, 'new', NEW.settings),
            auth.uid());
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._audit_staff_settings_change() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER merchant_staff_settings_audit
  AFTER INSERT OR UPDATE OF settings ON public.merchant_staff_settings
  FOR EACH ROW EXECUTE FUNCTION public._audit_staff_settings_change();

-- updated_at advances on every update.
CREATE FUNCTION public._merchant_staff_settings_touch()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- clock_timestamp(), not now(): now() is transaction-start time, so a
  -- same-transaction update would leave updated_at untouched.
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public._merchant_staff_settings_touch() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_merchant_staff_settings_touch
  BEFORE UPDATE ON public.merchant_staff_settings
  FOR EACH ROW EXECUTE FUNCTION public._merchant_staff_settings_touch();

-- Old triggers and the column leave merchants.
DROP TRIGGER IF EXISTS trg_merchants_staff_settings_shape ON public.merchants;
DROP TRIGGER IF EXISTS merchants_staff_settings_audit ON public.merchants;

-- ─── 1b. staff_create_walk_in_sale: read the gate from the new table ─────
-- Only the custom-line gate changes: v_merchant.staff_settings ->
-- a LEFT JOIN'd settings value (default '{}' when the owner never opted
-- in). Everything else stays byte-identical to 447.
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
  v_staff_settings jsonb; -- 448: moved out of merchants into merchant_staff_settings
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
  -- 448: staff_settings moved to its own owner-only table; default off.
  SELECT coalesce(mss.settings, '{}'::jsonb) INTO v_staff_settings
    FROM public.merchant_staff_settings mss
   WHERE mss.merchant_id = v_staff.merchant_id;
  v_staff_settings := coalesce(v_staff_settings, '{}'::jsonb);

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
  -- 447 (security batch 2, non-blocking): bound the request size itself.
  IF jsonb_array_length(p_items) > 200 THEN
    RAISE EXCEPTION 'too many lines (max 200)';
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
  -- Positive-only flags: 0/negative/garbage falls back to the default.
  v_catalog_qty_cap := coalesce(
    (SELECT CASE WHEN public._num_or_null(feature_flags ->> 'catalog_line_qty_cap') > 0
                 THEN public._num_or_null(feature_flags ->> 'catalog_line_qty_cap') END
       FROM public.platform_settings WHERE id = 'default'), 10000);
  v_sale_total_cap := coalesce(
    (SELECT CASE WHEN public._num_or_null(feature_flags ->> 'sale_total_cap') > 0
                 THEN public._num_or_null(feature_flags ->> 'sale_total_cap') END
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
      -- when the owner opts the merchant in (merchant_staff_settings.
      -- cashier_custom_lines, default off), then under the tighter
      -- cashier per-line cap plus per-shift count and value caps.
      -- Simple-service types never reach this RPC: the type gate above
      -- refuses non-cashier types; their surface is the provider app's
      -- simple invoice, not the POS.
      IF v_staff.role <> 'branch_manager' THEN
        IF coalesce((v_staff_settings ->> 'cashier_custom_lines')::boolean, false) IS NOT TRUE THEN
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
REVOKE ALL ON FUNCTION public.staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb,jsonb,uuid,numeric,uuid,uuid,text) TO service_role, authenticated;

-- ─── 1c. drop the moved column ────────────────────────────────────────────
ALTER TABLE public.merchants DROP COLUMN staff_settings;

-- ─── 2. anon DML sweep ───────────────────────────────────────────────────
-- Evidence keep-list: EMPTY. Guest mode browses only (local cart); signup
-- and OTP run through SECURITY DEFINER RPCs (request_whatsapp_otp,
-- verify_whatsapp_otp, whatsapp_otp_status, decide_user_verification — all
-- prosecdef=true on prod), which table revokes do not affect. No app code
-- path writes any public table while signed out (grepped lib/, pos/).
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."activity_logs" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."admin_receiving_wallets" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."admin_roles" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."admin_users" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."audit_log" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."branches" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."catalog_categories" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."categories" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."chat_messages" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."chat_rooms" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."chat_typing" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."coupon_redemptions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."coupons" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."delivery_pricing" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."delivery_zones" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."dispatch_config" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."driver_delay_events" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."driver_documents" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."driver_earnings" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."driver_locations" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."driver_obligations" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."drivers" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."drug_catalog" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."favorite_drivers" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."favorites" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."financial_permissions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."financial_receiving_accounts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."geography_columns" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."geometry_columns" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."grace_accounts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."grace_audit_log" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."identifier_lookup_attempts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."live_share_sessions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."location_updates" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."merchant_ledger" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."merchant_payout_requests" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."merchant_profiles" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."merchants" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."notification_destinations" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."notifications" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."offers" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."order_dispatch" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."order_edit_events" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."order_items" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."order_tracking" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."orders" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."payment_transactions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."platform_receiving_accounts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."platform_settings" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."platform_settlements" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."pos_sales" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."product_inventory" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."product_modifier_groups" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."product_modifier_options" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."product_modifiers" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."products" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."promo_codes" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."promo_redemptions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."provider_business_profiles" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."provider_documents" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."regional_collections" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."reservations" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."restaurant_settings" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."reviews" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."ride_ratings" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."ride_requests" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."sanctions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."saved_places" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."service_audio_logs" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."service_bookings" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."service_categories" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."service_providers" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."service_reviews" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."sos_alerts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."spatial_ref_sys" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."topup_requests" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."trip_events" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."trusted_contacts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."user_addresses" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."users" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."vehicles" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."verification_attempts" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."wallet_funding_requests" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."wallet_transactions" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."wallets" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."whatsapp_otp_verifications" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."withdrawal_requests" FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON public."working_hours" FROM anon;

-- Stop the next baseline-style table from re-inheriting anon grants where
-- the platform allows it; failure is non-fatal (notice only).
DO $$
BEGIN
  ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER ON TABLES FROM anon;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '448: default-privileges revoke for supabase_admin not permitted: %', sqlerrm;
END $$;

-- ─── 3. products: anon loses everything ──────────────────────────────────
REVOKE ALL ON public.products FROM anon;

-- ─── 4. service_providers: definer customer view + anon base revoke ──────
-- 4a. Customer-facing view: definer, fixed columns, rounded coords.
-- Replaces 397's security_invoker sp.* view. Column list drops user_id;
-- latitude/longitude are rounded to 2 decimals (~1km grid) so the customer
-- page's distance sort keeps working while exact provider location leaves
-- the public surface (decision: main agent under the owner's delegation,
-- 2026-11-26; exact server-side distance RPC is 449 scope). The
-- is_available = true filter is baked in because a definer view bypasses
-- the base table's RLS; the owner branch (sp.user_id = auth.uid()) keeps
-- the provider app's servicesFor() working on their own unavailable row.
DROP VIEW public.service_providers_with_effective_pricing;
CREATE VIEW public.service_providers_with_effective_pricing AS
SELECT sp.id, sp.name, sp.category_type, sp.description,
       sp.profile_image_url, sp.rating, sp.rating_count, sp.is_verified,
       sp.is_available, sp.hourly_rate, sp.fixed_price_min,
       sp.fixed_price_max, sp.city,
       round(sp.latitude::numeric, 2)  AS latitude,
       round(sp.longitude::numeric, 2) AS longitude,
       sp.tags, sp.created_at, sp.updated_at,
       (eff.p->>'hourly_rate')::numeric AS effective_hourly_rate,
       (eff.p->>'fixed_price_min')::numeric AS effective_fixed_price_min,
       (eff.p->>'fixed_price_max')::numeric AS effective_fixed_price_max,
       eff.p->>'hourly_source' AS hourly_source,
       eff.p->>'fixed_source' AS fixed_source,
       eff.p->>'currency' AS pricing_currency
  FROM public.service_providers sp
  CROSS JOIN LATERAL (
    SELECT public.service_provider_effective_pricing(sp.id) AS p
  ) eff
 WHERE sp.is_available = true
    OR sp.user_id = auth.uid();  -- owner keeps seeing their own row when unavailable
GRANT SELECT ON public.service_providers_with_effective_pricing TO anon;
GRANT SELECT ON public.service_providers_with_effective_pricing TO authenticated;

-- 4b. Base table: anon loses SELECT entirely (guests read the view);
-- authenticated keeps only the columns the installed provider app
-- selects/filters/orders by (category_type, user_id, created_at).
REVOKE SELECT ON public.service_providers FROM anon;
REVOKE SELECT ON public.service_providers FROM authenticated;
GRANT SELECT (category_type, user_id, created_at) ON public.service_providers TO authenticated;

-- 4c. Owner self-read (exact coords included) for the provider app to
-- adopt in 449; fail-closed when the caller owns no provider row.
CREATE FUNCTION public.get_my_provider_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row public.service_providers%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  SELECT * INTO v_row FROM public.service_providers
   WHERE user_id = auth.uid()
   ORDER BY created_at LIMIT 1;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN to_jsonb(v_row);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_provider_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_provider_profile() TO authenticated;

COMMIT;
