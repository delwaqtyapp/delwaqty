-- 442 (dark, owner-approved feature 2026-11-25 21:42; security conditional
-- GO on design v1): shop staff accounts + branch scope CORE schema.
--
-- One shared shop DATA scope (the merchant) with INDIVIDUAL staff auth
-- accounts created by the owner through the merchant-staff-admin edge
-- function (name + username + one-time password, NO email, phone kept only
-- as a contact field inside merchant_staff - NEVER written to users.phone,
-- so staff phones cannot squat the platform-wide phone login index).
-- Login uses the 440 username+password path; nothing here extends the
-- resolver: staff usernames live in users.username like everyone else's.
--
-- Design/authority notes (security conditional GO, 2026-11-25):
--   - No role/merchant/branch in JWT claims: every policy and RPC reads
--     live merchant_staff.is_active state through the helpers below, so
--     disable is effective on the next statement. The edge function
--     additionally bans the auth user and deletes refresh tokens.
--   - Staff are RPC-only for orders/customers/debt in v1: NO staff
--     policies on orders, pos_customers, pos_debt_ledger. Branch-scoped
--     SELECT policies are added ONLY to pos_sales, pos_sale_payments and
--     pos_shifts; the harness pins the pg_policies dump of every touched
--     table before/after to prove existing policies are unchanged.
--   - RPCs derive merchant/branch/role from the caller's staff row;
--     parameters are validated against it, never trusted.
--   - merchant_staff_events is append-only: UPDATE/DELETE revoked from
--     everyone and blocked by trigger.
--   - kitchen_order_queue() is a SECURITY DEFINER function (no new view)
--     with hard-coded masked columns - kitchen staff never see customer
--     phone/address.
--   - Feature flags live in platform_settings.feature_flags (admin-write;
--     the anon-readable app_public_config view is deliberately NOT
--     widened). Every operational RPC checks its flag server-side; flags
--     default OFF, so this migration is inert until flags are flipped.
--
-- This migration is NOT applied to prod without the owner's explicit
-- order, and stays inert until the edge function deploy + flag flips,
-- which are also owner-gated.

BEGIN;

-- A0 pre-image guard: none of the new objects may already exist.
DO $a0$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
              WHERE table_schema = 'public'
                AND table_name IN ('merchant_staff', 'merchant_staff_events', 'dine_in_tables')) THEN
    RAISE EXCEPTION '442 precondition failed: staff tables already exist';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public'
                AND p.proname IN ('feature_enabled', 'is_active_staff', 'staff_role',
                  'staff_branch_id', 'staff_can_branch', 'staff_app_context',
                  'staff_orders_feed', 'kitchen_order_queue', 'staff_advance_order_status',
                  'staff_create_walk_in_sale', 'staff_shift_open', 'staff_shift_close',
                  'staff_void_sale', 'staff_record_debt_payment', 'shop_end_of_day_report',
                  '_assert_staff_branch_match', '_block_staff_event_mutation',
                  '_assert_table_branch_match', '_assert_sale_links_match')) THEN
    RAISE EXCEPTION '442 precondition failed: a 442 function already exists';
  END IF;
END
$a0$;

-- ===================== feature flags (default OFF) =====================

ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS feature_flags jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.platform_settings.feature_flags IS
  'Dark-launch flags (442): staff_accounts, cashier_mode_mobile, kitchen_screen, branches_ui, eod_report, first_use_tips. All default off; every operational 442 RPC checks its flag server-side.';

-- ===================== staff tables =====================

CREATE TABLE public.merchant_staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  username text NOT NULL,
  full_name text NOT NULL,
  phone text, -- contact only; NEVER mirrored into users.phone (phone squatting)
  role text NOT NULL CHECK (role IN ('branch_manager','cashier','kitchen')),
  branch_id uuid REFERENCES public.branches(id),
  is_active boolean NOT NULL DEFAULT true,
  must_change_password boolean NOT NULL DEFAULT true,
  disabled_at timestamptz,
  disabled_by uuid REFERENCES public.users(id),
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  -- cashier and kitchen are bound to exactly one branch; a branch manager
  -- with NULL branch manages all branches of the shop.
  CHECK (role = 'branch_manager' OR branch_id IS NOT NULL),
  UNIQUE (merchant_id, user_id),
  UNIQUE (merchant_id, username)
);

-- Staff phones are CONTACT data, unique per shop when present (a shop may
-- not register two staff on the same phone); phones may repeat across
-- shops (staff accounts are independent per shop, design Q6).
CREATE UNIQUE INDEX merchant_staff_phone_key
  ON public.merchant_staff (merchant_id, phone) WHERE phone IS NOT NULL;

-- branch_id must belong to the same merchant; staff must not be a shop
-- owner or an admin (staff accounts are staff-only).
CREATE FUNCTION public._assert_staff_branch_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches b
     WHERE b.id = NEW.branch_id AND b.merchant_id = NEW.merchant_id
  ) THEN
    RAISE EXCEPTION 'branch % does not belong to merchant %', NEW.branch_id, NEW.merchant_id;
  END IF;
  IF EXISTS (SELECT 1 FROM public.merchants m WHERE m.owner_user_id = NEW.user_id) THEN
    RAISE EXCEPTION 'a shop owner cannot be a staff account';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_users a WHERE a.user_id = NEW.user_id) THEN
    RAISE EXCEPTION 'an admin cannot be a staff account';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER merchant_staff_branch_match
  BEFORE INSERT OR UPDATE ON public.merchant_staff
  FOR EACH ROW EXECUTE FUNCTION public._assert_staff_branch_match();

CREATE TABLE public.merchant_staff_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  staff_id uuid NOT NULL REFERENCES public.merchant_staff(id) ON DELETE CASCADE,
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN (
    'created','role_changed','branch_changed','disabled','enabled','password_reset',
    'walk_in_sale','void_sale','debt_payment','shift_opened','shift_closed','order_status')),
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Append-only: nobody updates or deletes audit rows, not even the owner
-- (REVOKE below + this trigger belt-and-braces).
CREATE FUNCTION public._block_staff_event_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RAISE EXCEPTION 'merchant_staff_events is append-only';
END;
$function$;

CREATE TRIGGER merchant_staff_events_append_only
  BEFORE UPDATE OR DELETE ON public.merchant_staff_events
  FOR EACH ROW EXECUTE FUNCTION public._block_staff_event_mutation();

CREATE TABLE public.dine_in_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  label text NOT NULL,
  seats integer NOT NULL DEFAULT 4 CHECK (seats > 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (branch_id, label)
);

CREATE FUNCTION public._assert_table_branch_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.branches b
                  WHERE b.id = NEW.branch_id AND b.merchant_id = NEW.merchant_id) THEN
    RAISE EXCEPTION 'branch % does not belong to merchant %', NEW.branch_id, NEW.merchant_id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER dine_in_tables_branch_match
  BEFORE INSERT OR UPDATE ON public.dine_in_tables
  FOR EACH ROW EXECUTE FUNCTION public._assert_table_branch_match();

-- ===================== branch/staff attribution on existing tables =====================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'app'
    CHECK (source IN ('app','walk_in','dine_in'));

ALTER TABLE public.pos_sales
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS staff_id uuid REFERENCES public.merchant_staff(id);

ALTER TABLE public.pos_shifts
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS opened_by_staff uuid REFERENCES public.merchant_staff(id);

-- Same-merchant enforcement for the new nullable links (composite FK would
-- need new UNIQUE constraints on hot tables; triggers keep the invariant
-- without touching existing indexes).
CREATE FUNCTION public._assert_sale_links_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches b WHERE b.id = NEW.branch_id AND b.merchant_id = NEW.merchant_id
  ) THEN
    RAISE EXCEPTION 'branch % does not belong to merchant %', NEW.branch_id, NEW.merchant_id;
  END IF;
  IF TG_TABLE_NAME = 'pos_sales' THEN
    IF NEW.staff_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.merchant_staff s WHERE s.id = NEW.staff_id AND s.merchant_id = NEW.merchant_id
    ) THEN
      RAISE EXCEPTION 'staff % does not belong to merchant %', NEW.staff_id, NEW.merchant_id;
    END IF;
  END IF;
  IF TG_TABLE_NAME = 'pos_shifts' THEN
    IF NEW.opened_by_staff IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.merchant_staff s WHERE s.id = NEW.opened_by_staff AND s.merchant_id = NEW.merchant_id
    ) THEN
      RAISE EXCEPTION 'staff % does not belong to merchant %', NEW.opened_by_staff, NEW.merchant_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER pos_sales_links_match
  BEFORE INSERT OR UPDATE OF branch_id, staff_id, merchant_id ON public.pos_sales
  FOR EACH ROW EXECUTE FUNCTION public._assert_sale_links_match();
CREATE TRIGGER pos_shifts_links_match
  BEFORE INSERT OR UPDATE OF branch_id, opened_by_staff, merchant_id ON public.pos_shifts
  FOR EACH ROW EXECUTE FUNCTION public._assert_sale_links_match();
CREATE TRIGGER orders_branch_match
  BEFORE INSERT OR UPDATE OF branch_id, merchant_id ON public.orders
  FOR EACH ROW
  WHEN (NEW.branch_id IS NOT NULL)
  EXECUTE FUNCTION public._assert_sale_links_match();

-- ===================== helpers (live state; never JWT claims) =====================

-- Numeric parsing that never throws on hostile client jsonb.
CREATE FUNCTION public._num_or_null(p_text text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_text ~ '^-?[0-9]+(\.[0-9]+)?$' THEN p_text::numeric END;
$function$;

CREATE FUNCTION public.feature_enabled(p_key text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN coalesce(
    (SELECT (feature_flags ->> p_key)::boolean
       FROM public.platform_settings WHERE id = 'default'),
    false);
END;
$function$;

CREATE FUNCTION public.is_active_staff(p_merchant_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.merchant_staff s
     WHERE s.merchant_id = p_merchant_id
       AND s.user_id = auth.uid()
       AND s.is_active
  );
END;
$function$;

CREATE FUNCTION public.staff_role(p_merchant_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN (SELECT s.role FROM public.merchant_staff s
           WHERE s.merchant_id = p_merchant_id
             AND s.user_id = auth.uid()
             AND s.is_active
           LIMIT 1);
END;
$function$;

CREATE FUNCTION public.staff_branch_id(p_merchant_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN (SELECT s.branch_id FROM public.merchant_staff s
           WHERE s.merchant_id = p_merchant_id
             AND s.user_id = auth.uid()
             AND s.is_active
           LIMIT 1);
END;
$function$;

-- Branch scope: a NULL branch on the ROW means shop-level data, visible to
-- any staff of the shop; a NULL branch on the STAFF row (branch manager)
-- means all branches. Cashiers and kitchen staff always carry a branch.
CREATE FUNCTION public.staff_can_branch(p_merchant_id uuid, p_branch_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_branch uuid;
BEGIN
  SELECT s.branch_id INTO v_branch FROM public.merchant_staff s
   WHERE s.merchant_id = p_merchant_id
     AND s.user_id = auth.uid()
     AND s.is_active
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  IF v_branch IS NULL THEN
    RETURN true; -- branch manager over all branches
  END IF;
  RETURN p_branch_id IS NULL OR p_branch_id = v_branch;
END;
$function$;

-- ===================== staff RLS policies =====================

ALTER TABLE public.merchant_staff ENABLE ROW LEVEL SECURITY;
-- Read: the owner, or the staff member reading their own row. ALL writes
-- go through the merchant-staff-admin edge function (service role).
CREATE POLICY merchant_staff_read ON public.merchant_staff FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

ALTER TABLE public.merchant_staff_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY merchant_staff_events_owner_read ON public.merchant_staff_events
  FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id));

ALTER TABLE public.dine_in_tables ENABLE ROW LEVEL SECURITY;
CREATE POLICY dine_in_tables_read ON public.dine_in_tables FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_active_staff(merchant_id));
CREATE POLICY dine_in_tables_owner_write ON public.dine_in_tables FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

-- Staff SELECT policies: ONLY these three tables (security Q5). orders,
-- pos_customers and pos_debt_ledger stay RPC-only for staff.
CREATE POLICY pos_sales_staff_read ON public.pos_sales FOR SELECT TO authenticated
  USING (public.is_active_staff(merchant_id)
         AND public.staff_can_branch(merchant_id, branch_id));
CREATE POLICY pos_sale_payments_staff_read ON public.pos_sale_payments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pos_sales s
                  WHERE s.id = sale_id
                    AND public.is_active_staff(s.merchant_id)
                    AND public.staff_can_branch(s.merchant_id, s.branch_id)));
CREATE POLICY pos_shifts_staff_read ON public.pos_shifts FOR SELECT TO authenticated
  USING (public.is_active_staff(merchant_id)
         AND public.staff_can_branch(merchant_id, branch_id));

-- ===================== staff RPCs (derive, never trust) =====================

-- Bootstrap for the app: who am I, which flags are on. Ungated by flags on
-- purpose: it reveals only the caller's own staff row and the flag states
-- the app needs to decide what to show.
CREATE FUNCTION public.staff_app_context()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('staff', NULL);
  END IF;
  RETURN jsonb_build_object(
    'staff', jsonb_build_object(
      'id', v_staff.id, 'merchant_id', v_staff.merchant_id,
      'role', v_staff.role, 'branch_id', v_staff.branch_id,
      'full_name', v_staff.full_name,
      'must_change_password', v_staff.must_change_password),
    'flags', jsonb_build_object(
      'cashier_mode_mobile', public.feature_enabled('cashier_mode_mobile'),
      'kitchen_screen', public.feature_enabled('kitchen_screen'),
      'branches_ui', public.feature_enabled('branches_ui'),
      'eod_report', public.feature_enabled('eod_report')));
END;
$function$;

-- Polling feed for the one-screen orders view (cashier/manager). Replaces
-- realtime for staff in v1.
CREATE FUNCTION public.staff_orders_feed(p_since timestamptz DEFAULT NULL)
 RETURNS TABLE(
   id uuid, status text, payment_method text, payment_status text,
   total_amount numeric, items jsonb, customer_name text, customer_phone text,
   source text, branch_id uuid, created_at timestamptz, updated_at timestamptz)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active cashier staff';
  END IF;
  RETURN QUERY
  SELECT o.id, o.status, o.payment_method, o.payment_status, o.total_amount,
         o.items, u.full_name, u.phone, o.source, o.branch_id, o.created_at, o.updated_at
    FROM public.orders o
    LEFT JOIN public.users u ON u.id = o.user_id
   WHERE o.merchant_id = v_staff.merchant_id
     AND (v_staff.branch_id IS NULL OR o.branch_id IS NULL OR o.branch_id = v_staff.branch_id)
     AND o.updated_at >= coalesce(p_since, now() - interval '24 hours')
   ORDER BY o.updated_at DESC
   LIMIT 200;
END;
$function$;

-- Kitchen queue: masked columns HARD-CODED (no customer phone/address, no
-- prices), forward pipeline statuses only, branch-scoped.
CREATE FUNCTION public.kitchen_order_queue()
 RETURNS TABLE(
   id uuid, status text, items jsonb, notes text,
   minutes_open integer, created_at timestamptz)
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF NOT public.feature_enabled('kitchen_screen') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('kitchen','cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active shop staff';
  END IF;
  RETURN QUERY
  SELECT o.id, o.status,
         (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'name', coalesce(it.item ->> 'name', it.item ->> 'name_ar', ''),
                    'qty', coalesce(public._num_or_null(it.item ->> 'quantity')::int,
                                    public._num_or_null(it.item ->> 'qty')::int, 1))), '[]'::jsonb)
            FROM jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) AS it(item)),
         o.special_instructions,
         greatest(0, (extract(epoch from now() - o.created_at) / 60)::int),
         o.created_at
    FROM public.orders o
   WHERE o.merchant_id = v_staff.merchant_id
     AND o.status IN ('confirmed','preparing','ready')
     AND (v_staff.branch_id IS NULL OR o.branch_id IS NULL OR o.branch_id = v_staff.branch_id)
   ORDER BY o.created_at ASC
   LIMIT 100;
END;
$function$;

-- Status advance: whitelisted kitchen pairs only; merchant + branch checked
-- on the order row itself; the 390 forward-only trigger still applies.
CREATE FUNCTION public.staff_advance_order_status(p_order_id uuid, p_new_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_order public.orders%ROWTYPE;
BEGIN
  IF NOT public.feature_enabled('kitchen_screen') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF p_new_status NOT IN ('preparing','ready') THEN
    RAISE EXCEPTION 'status % is not staff-advanceable', p_new_status;
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('kitchen','cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active shop staff';
  END IF;
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.merchant_id IS DISTINCT FROM v_staff.merchant_id THEN
    RAISE EXCEPTION 'order not found';
  END IF;
  IF v_staff.branch_id IS NOT NULL AND v_order.branch_id IS NOT NULL
     AND v_order.branch_id <> v_staff.branch_id THEN
    RAISE EXCEPTION 'order belongs to another branch';
  END IF;
  IF NOT ((v_order.status = 'confirmed' AND p_new_status = 'preparing')
       OR (v_order.status = 'preparing' AND p_new_status = 'ready')) THEN
    RAISE EXCEPTION 'illegal transition % -> %', v_order.status, p_new_status;
  END IF;
  UPDATE public.orders SET status = p_new_status, updated_at = now()
   WHERE id = p_order_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'order_status',
          jsonb_build_object('order_id', p_order_id, 'from', v_order.status, 'to', p_new_status),
          auth.uid());
  RETURN jsonb_build_object('id', p_order_id, 'status', p_new_status);
END;
$function$;

-- Walk-in sale: server-side prices for product items, payments must sum to
-- the total, per-role discount caps, race-safe stock, idempotent on the
-- client op id, audited.
CREATE FUNCTION public.staff_create_walk_in_sale(
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
  v_branch uuid;
  v_item jsonb;
  v_product public.products%ROWTYPE;
  v_label text;
  v_qty numeric;
  v_price numeric;
  v_subtotal numeric := 0;
  v_discount numeric := coalesce(p_discount, 0);
  v_total numeric;
  v_pay jsonb;
  v_pay_sum numeric := 0;
  v_methods text[] := '{}';
  v_sale_id uuid;
  v_shift uuid;
  v_normalized jsonb := '[]'::jsonb;
  v_existing uuid;
  CASHIER_DISCOUNT_CAP constant numeric := 0.10;
  MANAGER_DISCOUNT_CAP constant numeric := 0.50;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active cashier staff';
  END IF;

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

  -- Idempotency: the same op id returns the original sale.
  SELECT s.id INTO v_existing FROM public.pos_sales s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.idempotency_key = p_client_op_id::text
   LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('id', v_existing, 'idempotent_replay', true);
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items required';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_qty := coalesce(public._num_or_null(v_item ->> 'qty'), 0);
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'qty must be a positive number';
    END IF;
    IF v_item ? 'product_id' AND public._num_or_null('1') IS NOT NULL
       AND (v_item ->> 'product_id') ~ '^[0-9a-fA-F-]{36}$' THEN
      -- Server-side price: the client never names a price for catalog items.
      SELECT * INTO v_product FROM public.products
       WHERE id = (v_item ->> 'product_id')::uuid
         AND merchant_id = v_staff.merchant_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown product %', v_item ->> 'product_id';
      END IF;
      v_price := v_product.price;
      v_label := coalesce(v_product.name_ar, v_product.name);
      -- Race-safe stock: one atomic guarded UPDATE, no check-then-act.
      UPDATE public.product_inventory
         SET stock_quantity = stock_quantity - v_qty, updated_at = now()
       WHERE product_id = v_product.id
         AND merchant_id = v_staff.merchant_id
         AND stock_quantity >= v_qty;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'insufficient stock for %', v_label;
      END IF;
      -- Per-line stock move (client op id stays NULL: sale-level
      -- idempotency is guarded above and this is one transaction).
      INSERT INTO public.pos_stock_moves
        (merchant_id, product_id, kind, qty, note, created_by)
      VALUES
        (v_staff.merchant_id, v_product.id, 'sale', -v_qty,
         'walk-in sale', auth.uid());
    ELSE
      -- Free-text line (service-shop simple invoice): client price is
      -- accepted and the sale is audited as containing custom items.
      v_label := coalesce(nullif(btrim(v_item ->> 'label'), ''), 'item');
      v_price := coalesce(public._num_or_null(v_item ->> 'price'), -1);
      IF v_price < 0 THEN
        RAISE EXCEPTION 'custom item price must be a number >= 0';
      END IF;
    END IF;
    v_subtotal := v_subtotal + v_price * v_qty;
    v_normalized := v_normalized || jsonb_build_object(
      'product_id', v_item ->> 'product_id', 'label', v_label,
      'qty', v_qty, 'unit_price', v_price);
  END LOOP;

  IF v_discount < 0 OR v_discount > v_subtotal * (CASE v_staff.role
        WHEN 'cashier' THEN CASHIER_DISCOUNT_CAP
        ELSE MANAGER_DISCOUNT_CAP END) THEN
    RAISE EXCEPTION 'discount exceeds the % cap', v_staff.role;
  END IF;
  v_total := v_subtotal - v_discount;

  IF p_payments IS NULL OR jsonb_typeof(p_payments) <> 'array'
     OR jsonb_array_length(p_payments) = 0 THEN
    RAISE EXCEPTION 'payments required';
  END IF;
  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    IF (v_pay ->> 'method') NOT IN ('cash','instapay','vodafone_cash','card','deferred') THEN
      RAISE EXCEPTION 'unknown payment method %', v_pay ->> 'method';
    END IF;
    IF coalesce(public._num_or_null(v_pay ->> 'amount'), -1) < 0 THEN
      RAISE EXCEPTION 'payment amount must be a number >= 0';
    END IF;
    v_pay_sum := v_pay_sum + public._num_or_null(v_pay ->> 'amount');
    v_methods := v_methods || (v_pay ->> 'method');
  END LOOP;
  IF abs(v_pay_sum - v_total) > 0.001 THEN
    RAISE EXCEPTION 'payments (%) must sum to the total (%)', v_pay_sum, v_total;
  END IF;
  IF 'deferred' = ANY(v_methods) AND p_pos_customer_id IS NULL THEN
    RAISE EXCEPTION 'deferred payment requires a customer';
  END IF;
  IF p_pos_customer_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.pos_customers c
     WHERE c.id = p_pos_customer_id AND c.merchant_id = v_staff.merchant_id
  ) THEN
    RAISE EXCEPTION 'customer does not belong to this shop';
  END IF;

  SELECT s.id INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id
     AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1;

  INSERT INTO public.pos_sales
    (merchant_id, cashier_user_id, items, subtotal, discount, total_amount,
     payment_method, notes, status, idempotency_key, shift_id, branch_id,
     staff_id, pos_customer_id)
  VALUES
    (v_staff.merchant_id, auth.uid(), v_normalized, v_subtotal, v_discount,
     v_total, CASE WHEN array_length(v_methods, 1) = 1 THEN v_methods[1] ELSE 'mixed' END,
     p_notes, 'completed',
     p_client_op_id::text, v_shift, v_branch, v_staff.id, p_pos_customer_id)
  RETURNING id INTO v_sale_id;

  FOR v_pay IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
    INSERT INTO public.pos_sale_payments (sale_id, method, amount)
    VALUES (v_sale_id, v_pay ->> 'method', public._num_or_null(v_pay ->> 'amount'));
  END LOOP;

  IF 'deferred' = ANY(v_methods) THEN
    INSERT INTO public.pos_debt_ledger
      (merchant_id, customer_id, sale_id, client_op_id, kind, amount, note, created_by)
    SELECT v_staff.merchant_id, p_pos_customer_id, v_sale_id, p_client_op_id,
           'charge', public._num_or_null(p ->> 'amount'), 'أجل - بيع محلي', auth.uid()
      FROM jsonb_array_elements(p_payments) AS p
     WHERE (p ->> 'method') = 'deferred'
    ON CONFLICT DO NOTHING;
  END IF;

  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'walk_in_sale',
          jsonb_build_object('sale_id', v_sale_id, 'total', v_total,
                             'methods', v_methods, 'branch_id', v_branch),
          auth.uid());

  RETURN jsonb_build_object('id', v_sale_id, 'total', v_total, 'idempotent_replay', false);
END;
$function$;

-- Shifts: one open shift per staff member; close computes the expected
-- drawer from actual cash payments and audits the variance.
CREATE FUNCTION public.staff_shift_open(p_opening_float numeric DEFAULT 0, p_client_op_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_id uuid;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active cashier staff';
  END IF;
  IF coalesce(p_opening_float, -1) < 0 THEN
    RAISE EXCEPTION 'opening float must be >= 0';
  END IF;
  IF p_client_op_id IS NOT NULL THEN
    SELECT s.id INTO v_id FROM public.pos_shifts s
     WHERE s.merchant_id = v_staff.merchant_id AND s.client_op_id = p_client_op_id
     LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('id', v_id, 'idempotent_replay', true);
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.pos_shifts s
              WHERE s.merchant_id = v_staff.merchant_id
                AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL) THEN
    RAISE EXCEPTION 'close your current shift before opening a new one';
  END IF;
  INSERT INTO public.pos_shifts
    (merchant_id, client_op_id, opened_by, opening_float, branch_id, opened_by_staff)
  VALUES
    (v_staff.merchant_id, p_client_op_id, auth.uid(), p_opening_float,
     v_staff.branch_id, v_staff.id)
  RETURNING id INTO v_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_opened',
          jsonb_build_object('shift_id', v_id, 'float', p_opening_float), auth.uid());
  RETURN jsonb_build_object('id', v_id, 'idempotent_replay', false);
END;
$function$;

CREATE FUNCTION public.staff_shift_close(p_closing_cash numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_shift public.pos_shifts%ROWTYPE;
  v_cash numeric;
  v_totals jsonb;
  v_expected numeric;
  v_variance numeric;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active cashier staff';
  END IF;
  IF coalesce(p_closing_cash, -1) < 0 THEN
    RAISE EXCEPTION 'closing cash must be >= 0';
  END IF;
  SELECT * INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'no open shift';
  END IF;
  SELECT coalesce(sum(sub.amount) FILTER (WHERE sub.method = 'cash'), 0),
         coalesce(jsonb_object_agg(sub.method, sub.method_total), '{}'::jsonb)
    INTO v_cash, v_totals
    FROM (SELECT p2.method, sum(p2.amount) AS method_total, sum(p2.amount) AS amount
            FROM public.pos_sale_payments p2
            JOIN public.pos_sales s2 ON s2.id = p2.sale_id
           WHERE s2.shift_id = v_shift.id AND s2.status = 'completed'
           GROUP BY p2.method) sub;
  v_expected := v_shift.opening_float + v_cash;
  v_variance := p_closing_cash - v_expected;
  UPDATE public.pos_shifts
     SET closed_at = now(), closing_cash = p_closing_cash,
         expected_cash = v_expected, totals = v_totals
   WHERE id = v_shift.id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_closed',
          jsonb_build_object('shift_id', v_shift.id, 'expected', v_expected,
                             'counted', p_closing_cash, 'variance', v_variance),
          auth.uid());
  RETURN jsonb_build_object('id', v_shift.id, 'expected', v_expected,
                            'counted', p_closing_cash, 'variance', v_variance);
END;
$function$;

-- Void: managers only; restores stock; audited.
CREATE FUNCTION public.staff_void_sale(p_sale_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_sale public.pos_sales%ROWTYPE;
  v_item jsonb;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active AND role = 'branch_manager'
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'only a branch manager can void a sale';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'void reason required';
  END IF;
  SELECT * INTO v_sale FROM public.pos_sales WHERE id = p_sale_id FOR UPDATE;
  IF NOT FOUND OR v_sale.merchant_id IS DISTINCT FROM v_staff.merchant_id THEN
    RAISE EXCEPTION 'sale not found';
  END IF;
  IF v_staff.branch_id IS NOT NULL AND v_sale.branch_id IS NOT NULL
     AND v_sale.branch_id <> v_staff.branch_id THEN
    RAISE EXCEPTION 'sale belongs to another branch';
  END IF;
  IF v_sale.voided_at IS NOT NULL THEN
    RAISE EXCEPTION 'sale already voided';
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(v_sale.items, '[]'::jsonb)) LOOP
    IF (v_item ->> 'product_id') ~ '^[0-9a-fA-F-]{36}$' THEN
      UPDATE public.product_inventory
         SET stock_quantity = stock_quantity + coalesce(public._num_or_null(v_item ->> 'qty'), 0),
             updated_at = now()
       WHERE product_id = (v_item ->> 'product_id')::uuid
         AND merchant_id = v_staff.merchant_id;
      INSERT INTO public.pos_stock_moves
        (merchant_id, product_id, kind, qty, note, created_by)
      VALUES
        (v_staff.merchant_id, (v_item ->> 'product_id')::uuid, 'void_restore',
         coalesce(public._num_or_null(v_item ->> 'qty'), 0), 'void ' || p_sale_id, auth.uid());
    END IF;
  END LOOP;
  UPDATE public.pos_sales
     SET voided_at = now(), voided_by = auth.uid(), void_reason = p_reason,
         status = 'voided', updated_at = now()
   WHERE id = p_sale_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'void_sale',
          jsonb_build_object('sale_id', p_sale_id, 'reason', p_reason,
                             'total', v_sale.total_amount),
          auth.uid());
  RETURN jsonb_build_object('id', p_sale_id, 'voided', true);
END;
$function$;

-- أجل debt payment (cash received against a tab): cashier + manager; audited.
CREATE FUNCTION public.staff_record_debt_payment(
  p_customer_id uuid, p_amount numeric, p_client_op_id uuid, p_note text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_id bigint;
BEGIN
  IF NOT public.feature_enabled('cashier_mode_mobile') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role IN ('cashier','branch_manager')
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active cashier staff';
  END IF;
  IF coalesce(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_client_op_id IS NULL THEN
    RAISE EXCEPTION 'client op id required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pos_customers c
                  WHERE c.id = p_customer_id AND c.merchant_id = v_staff.merchant_id) THEN
    RAISE EXCEPTION 'customer does not belong to this shop';
  END IF;
  INSERT INTO public.pos_debt_ledger
    (merchant_id, customer_id, client_op_id, kind, amount, note, created_by)
  VALUES
    (v_staff.merchant_id, p_customer_id, p_client_op_id, 'payment',
     p_amount, p_note, auth.uid())
  ON CONFLICT (merchant_id, client_op_id) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    SELECT l.id INTO v_id FROM public.pos_debt_ledger l
     WHERE l.merchant_id = v_staff.merchant_id AND l.client_op_id = p_client_op_id;
    RETURN jsonb_build_object('id', v_id, 'idempotent_replay', true);
  END IF;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'debt_payment',
          jsonb_build_object('customer_id', p_customer_id, 'amount', p_amount),
          auth.uid());
  RETURN jsonb_build_object('id', v_id, 'idempotent_replay', false);
END;
$function$;

-- End-of-day report: owner (any branch or combined) or branch manager
-- (own branch only). The merchant parameter is VALIDATED against the
-- caller, never trusted. Day bounds use the database timezone.
CREATE FUNCTION public.shop_end_of_day_report(
  p_merchant_id uuid, p_day date, p_branch_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_owner boolean;
  v_staff public.merchant_staff%ROWTYPE;
  v_scope uuid;
  v_sales jsonb;
  v_app_orders jsonb;
  v_shifts jsonb;
BEGIN
  IF NOT public.feature_enabled('eod_report') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  v_is_owner := public.is_merchant_owner(p_merchant_id);
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active AND merchant_id = p_merchant_id
     AND role = 'branch_manager'
   ORDER BY created_at DESC LIMIT 1;
  IF NOT v_is_owner AND NOT FOUND THEN
    RAISE EXCEPTION 'only the owner or a branch manager can read the day report';
  END IF;
  IF NOT v_is_owner THEN
    -- A branch manager sees only their own branch.
    IF v_staff.branch_id IS NOT NULL THEN
      IF p_branch_id IS NOT NULL AND p_branch_id <> v_staff.branch_id THEN
        RAISE EXCEPTION 'branch outside your scope';
      END IF;
      v_scope := v_staff.branch_id;
    ELSE
      v_scope := p_branch_id; -- all-branches manager may pick one or combined
    END IF;
  ELSE
    v_scope := p_branch_id;
  END IF;

  SELECT jsonb_build_object(
      'count', count(*), 'total', coalesce(sum(s.total_amount), 0),
      'by_method', coalesce((SELECT jsonb_object_agg(p.method, p.total) FROM (
        SELECT p2.method, sum(p2.amount) AS total
          FROM public.pos_sale_payments p2
          JOIN public.pos_sales s2 ON s2.id = p2.sale_id
         WHERE s2.merchant_id = p_merchant_id AND s2.status = 'completed'
           AND s2.created_at >= p_day::timestamptz
           AND s2.created_at < (p_day + 1)::timestamptz
           AND (v_scope IS NULL OR s2.branch_id = v_scope)
         GROUP BY p2.method) p), '{}'::jsonb))
    INTO v_sales
    FROM public.pos_sales s
   WHERE s.merchant_id = p_merchant_id AND s.status = 'completed'
     AND s.created_at >= p_day::timestamptz
     AND s.created_at < (p_day + 1)::timestamptz
     AND (v_scope IS NULL OR s.branch_id = v_scope);

  SELECT jsonb_build_object('count', count(*), 'total', coalesce(sum(o.total_amount), 0))
    INTO v_app_orders
    FROM public.orders o
   WHERE o.merchant_id = p_merchant_id AND o.status = 'delivered'
     AND o.source = 'app'
     AND o.created_at >= p_day::timestamptz
     AND o.created_at < (p_day + 1)::timestamptz
     AND (v_scope IS NULL OR o.branch_id = v_scope);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'opened_at', s.opened_at, 'closed_at', s.closed_at,
      'expected', s.expected_cash, 'counted', s.closing_cash,
      'variance', s.closing_cash - s.expected_cash)), '[]'::jsonb)
    INTO v_shifts
    FROM public.pos_shifts s
   WHERE s.merchant_id = p_merchant_id
     AND s.opened_at >= p_day::timestamptz
     AND s.opened_at < (p_day + 1)::timestamptz
     AND (v_scope IS NULL OR s.branch_id = v_scope);

  RETURN jsonb_build_object(
    'merchant_id', p_merchant_id, 'day', p_day, 'branch_id', v_scope,
    'walk_in_sales', v_sales, 'app_orders', v_app_orders, 'shifts', v_shifts);
END;
$function$;

-- ===================== grants: explicit and narrow =====================

REVOKE ALL ON TABLE public.merchant_staff FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.merchant_staff_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.dine_in_tables FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.merchant_staff TO authenticated;
GRANT SELECT ON TABLE public.merchant_staff_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.dine_in_tables TO authenticated; -- gated by the owner-only write policy

REVOKE EXECUTE ON FUNCTION public._assert_staff_branch_match() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._block_staff_event_mutation() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._assert_table_branch_match() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._assert_sale_links_match() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._num_or_null(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feature_enabled(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_active_staff(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_role(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_branch_id(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_can_branch(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_app_context() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_orders_feed(timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.kitchen_order_queue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_advance_order_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_shift_open(numeric, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_shift_close(numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_void_sale(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_record_debt_payment(uuid, numeric, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.shop_end_of_day_report(uuid, date, uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.feature_enabled(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_staff(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_branch_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_can_branch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_app_context() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_orders_feed(timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kitchen_order_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_advance_order_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_shift_open(numeric, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_shift_close(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_void_sale(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_record_debt_payment(uuid, numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_end_of_day_report(uuid, date, uuid) TO authenticated;

COMMIT;
