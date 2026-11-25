-- 442: shop staff accounts + branch scope (DARK, flag-gated).
--
-- Owner decision 2026-11-25 (relayed by the main agent): build the
-- shop/staff/cashier-link feature, dark/flagged, migrations first.
-- Security reviewer CONDITIONAL GO 2026-11-25 (design v2); code reviewer
-- findings #249-#257 + security findings S1-S12 folded into this version.
-- Applied NOWHERE without an explicit owner order. All flags default OFF.
--
-- Canonical stock (S12 / #251): products.stock_quantity is the ONE
-- authoritative stock counter — the same column online create_order (234)
-- and the desktop cashier sync (346) decrement. The rules match 234:
-- is_available NOT TRUE refuses the line; stock_quantity NULL means
-- untracked (no decrement, no refusal); tracked stock decrements in ONE
-- atomic guarded UPDATE (stock_quantity >= qty), never check-then-act.
-- product_inventory is NOT touched by staff RPCs.
--
-- Branch visibility (S10 / #249): a NULL branch on a ROW means
-- unattributed shop-level data and is MANAGER-ONLY; a NULL branch on the
-- STAFF row (branch manager) means all branches; cashiers and kitchen
-- always carry a branch and see only it.
--
-- Authorization (#250 / S5): every staff RPC except the bootstrap
-- (staff_app_context) and the password-change path (edge function,
-- separate PR) goes through _authorize_staff: master flag staff_accounts
-- + the surface flag + live is_active + role allowlist +
-- must_change_password barrier. The pos_* read policies enforce the same
-- via staff_pos_read_ok.

BEGIN;

-- ===================== staff =====================

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

-- Staff phones are CONTACT data, unique per shop when present; phones may
-- repeat across shops (staff accounts are independent per shop, design Q6).
CREATE UNIQUE INDEX merchant_staff_phone_key
  ON public.merchant_staff (merchant_id, phone) WHERE phone IS NOT NULL;

-- branch_id must belong to the same merchant; staff must not be a shop
-- owner or an admin; merchant_id/user_id are immutable once created
-- (re-parenting a staff row would re-scope its audit trail, #257).
CREATE FUNCTION public._assert_staff_branch_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
                           OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
    RAISE EXCEPTION 'merchant_id and user_id are immutable on staff rows';
  END IF;
  IF NEW.branch_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.branches b WHERE b.id = NEW.branch_id AND b.merchant_id = NEW.merchant_id
  ) THEN
    RAISE EXCEPTION 'branch % does not belong to merchant %', NEW.branch_id, NEW.merchant_id;
  END IF;
  IF EXISTS (SELECT 1 FROM public.merchants m
              WHERE m.id = NEW.merchant_id AND m.owner_user_id = NEW.user_id)
     OR public.is_admin(NEW.user_id) THEN
    RAISE EXCEPTION 'the shop owner and platform admins are not staff';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER merchant_staff_branch_match
  BEFORE INSERT OR UPDATE ON public.merchant_staff
  FOR EACH ROW EXECUTE FUNCTION public._assert_staff_branch_match();

-- Inverse check (#257): a branch referenced by staff or tables cannot be
-- re-parented to another merchant.
CREATE FUNCTION public._assert_branch_not_reparented()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.merchant_id IS DISTINCT FROM OLD.merchant_id
     AND (EXISTS (SELECT 1 FROM public.merchant_staff s WHERE s.branch_id = OLD.id)
          OR EXISTS (SELECT 1 FROM public.dine_in_tables t WHERE t.branch_id = OLD.id)) THEN
    RAISE EXCEPTION 'branch % is referenced by staff/tables and cannot change merchant', OLD.id;
  END IF;
  RETURN NEW;
END;
$function$;

-- ===================== staff audit (append-only) =====================

CREATE TABLE public.merchant_staff_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- Nullable FK with SET NULL: deleting a staff row nulls the link and
  -- KEEPS the audit row (S6). merchant_id/actor_id are deliberately plain
  -- uuids (no FK): merchant or actor deletion must never cascade into or
  -- be blocked by the audit trail.
  staff_id uuid REFERENCES public.merchant_staff(id) ON DELETE SET NULL,
  merchant_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN (
    'created','role_changed','branch_changed','disabled','enabled','password_reset',
    'walk_in_sale','void_sale','debt_payment','shift_opened','shift_closed','order_status')),
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Append-only (S6): nobody updates or deletes audit rows. The single
-- exception is the referential ON DELETE SET NULL on staff_id, which may
-- null ONLY that column; every other update and every delete raises.
CREATE FUNCTION public._block_staff_event_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.staff_id IS NULL AND OLD.staff_id IS NOT NULL
     AND NEW.merchant_id IS NOT DISTINCT FROM OLD.merchant_id
     AND NEW.kind IS NOT DISTINCT FROM OLD.kind
     AND NEW.detail IS NOT DISTINCT FROM OLD.detail
     AND NEW.actor_id IS NOT DISTINCT FROM OLD.actor_id
     AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at THEN
    RETURN NEW; -- FK SET NULL cascade only
  END IF;
  RAISE EXCEPTION 'merchant_staff_events is append-only';
END;
$function$;

CREATE TRIGGER merchant_staff_events_no_mutation
  BEFORE UPDATE OR DELETE ON public.merchant_staff_events
  FOR EACH ROW EXECUTE FUNCTION public._block_staff_event_mutation();

-- ===================== dine-in tables (restaurants) =====================

CREATE TABLE public.dine_in_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  label text NOT NULL,
  seats integer NOT NULL DEFAULT 4 CHECK (seats > 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (branch_id, label)
);

CREATE FUNCTION public._assert_table_branch_match()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.branches b WHERE b.id = NEW.branch_id AND b.merchant_id = NEW.merchant_id
  ) THEN
    RAISE EXCEPTION 'branch % does not belong to merchant %', NEW.branch_id, NEW.merchant_id;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER dine_in_tables_branch_match
  BEFORE INSERT OR UPDATE ON public.dine_in_tables
  FOR EACH ROW EXECUTE FUNCTION public._assert_table_branch_match();

CREATE TRIGGER branches_no_reparent
  BEFORE UPDATE OF merchant_id ON public.branches
  FOR EACH ROW EXECUTE FUNCTION public._assert_branch_not_reparented();

-- ===================== branch/staff attribution on existing tables =====================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'app'
    CHECK (source IN ('app','walk_in','dine_in'));

ALTER TABLE public.pos_sales
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS staff_id uuid REFERENCES public.merchant_staff(id),
  -- Canonical request fingerprint for idempotent replay: same client op id
  -- with a DIFFERENT payload is a conflict, not a replay (#256).
  ADD COLUMN IF NOT EXISTS request_hash text;

ALTER TABLE public.pos_shifts
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id),
  ADD COLUMN IF NOT EXISTS opened_by_staff uuid REFERENCES public.merchant_staff(id);

-- Debt receipts tie to the shift that received the cash (S7).
ALTER TABLE public.pos_debt_ledger
  ADD COLUMN IF NOT EXISTS shift_id uuid REFERENCES public.pos_shifts(id);

-- Stock moves link back to the sale so voids restore exactly what the sale
-- actually decremented, whatever item-key shape the client used (S3).
ALTER TABLE public.pos_stock_moves
  ADD COLUMN IF NOT EXISTS sale_id uuid REFERENCES public.pos_sales(id);

-- At most ONE open shift per staff member (race-proof at the DB level, #252).
CREATE UNIQUE INDEX pos_shifts_one_open_per_staff_uq
  ON public.pos_shifts (opened_by_staff)
  WHERE closed_at IS NULL AND opened_by_staff IS NOT NULL;

-- Same-merchant enforcement for the new nullable links (composite FK would
-- need new UNIQUE constraints on hot tables; triggers keep the invariant
-- without touching existing indexes). NOTE: each NEW column is touched
-- only under its own table guard — plpgsql resolves record fields at
-- execution time and orders has no staff_id.
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

-- ===================== feature flags (owner-guarded, S4) =====================

ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS feature_flags jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.platform_settings.feature_flags IS
  'Feature rollout flags (all default off). Owner-only writes via guard_platform_settings_owner_fields (442/S4). Also carries numeric tunables: debt_payment_cap (default 5000), custom_line_cap (default 50000).';

-- S4: feature_flags joins the owner-only fields. The guard is a live global
-- function; pin its pre-image before replacing (learning: full md5 +
-- signature + properties), then assert the new body covers feature_flags.
DO $v442$
BEGIN
  IF md5(pg_get_functiondef('public.guard_platform_settings_owner_fields()'::regprocedure))
       <> '797da2f7a1fb8c6eaf14b33121345bb8' THEN
    RAISE EXCEPTION '442 precondition failed: guard_platform_settings_owner_fields drifted from its live pre-image (393-era body, verified on prod)';
  END IF;
END
$v442$;

CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    IF TG_OP = 'UPDATE' AND NEW.require_provider_documents IS DISTINCT FROM OLD.require_provider_documents THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    ELSIF TG_OP = 'INSERT' AND NEW.require_provider_documents IS TRUE THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change provider document requirements';
      END IF;
    END IF;
    -- 393: cancellation/refusal suspension durations are owner-only.
    IF NEW.cancel_suspension_days IS DISTINCT FROM OLD.cancel_suspension_days THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the cancellation suspension duration';
      END IF;
    END IF;
    IF NEW.refusal_suspension_days IS DISTINCT FROM OLD.refusal_suspension_days THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change the refusal suspension duration';
      END IF;
    END IF;
    -- 442/S4: feature flags (and tunables) are owner-only; country admins
    -- can UPDATE platform_settings but must never flip a rollout flag.
    IF TG_OP = 'UPDATE' AND NEW.feature_flags IS DISTINCT FROM OLD.feature_flags THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can change feature flags';
      END IF;
    ELSIF TG_OP = 'INSERT' AND NEW.feature_flags IS DISTINCT FROM '{}'::jsonb THEN
      IF NOT public._is_owner_uid(auth.uid()) THEN
        RAISE EXCEPTION 'Only the platform owner can set feature flags';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DO $v442$
BEGIN
  IF pg_get_functiondef('public.guard_platform_settings_owner_fields()'::regprocedure)
       NOT LIKE '%feature_flags%' THEN
    RAISE EXCEPTION '442 post-check failed: owner guard does not cover feature_flags';
  END IF;
END
$v442$;

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

-- Branch scope (S10): a NULL p_branch_id means an UNATTRIBUTED row and is
-- manager-only; a NULL staff branch (branch manager) sees all branches;
-- cashiers/kitchen see only their own branch.
CREATE FUNCTION public.staff_can_branch(p_merchant_id uuid, p_branch_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_branch uuid;
  v_role text;
BEGIN
  SELECT s.branch_id, s.role INTO v_branch, v_role FROM public.merchant_staff s
   WHERE s.merchant_id = p_merchant_id
     AND s.user_id = auth.uid()
     AND s.is_active
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  IF v_branch IS NULL THEN
    RETURN true; -- all-branches manager
  END IF;
  IF p_branch_id IS NULL THEN
    RETURN v_role = 'branch_manager'; -- unattributed rows are manager-only
  END IF;
  RETURN v_branch = p_branch_id;
END;
$function$;

-- Shared staff authorization (#250/S5): master flag + surface flag + live
-- is_active + role allowlist + forced-password-change barrier. EVERY staff
-- RPC uses this; the only exceptions are staff_app_context (bootstrap that
-- tells the app a password change is due) and the password-change path in
-- the edge function (separate PR), which clears must_change_password.
CREATE FUNCTION public._authorize_staff(p_surface_flag text, p_roles text[])
 RETURNS public.merchant_staff
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF NOT public.feature_enabled('staff_accounts')
     OR NOT public.feature_enabled(p_surface_flag) THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = auth.uid() AND is_active
     AND role = ANY(p_roles)
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not active shop staff';
  END IF;
  IF v_staff.must_change_password THEN
    RAISE EXCEPTION 'password change required before staff work';
  END IF;
  RETURN v_staff;
END;
$function$;

-- The pos_* financial read policies (#249/#250): manager/cashier roles
-- ONLY (kitchen never reads financials), master + surface flags ON,
-- live is_active, password-change barrier, branch scope incl. the
-- unattributed-rows-are-manager-only rule.
CREATE FUNCTION public.staff_pos_read_ok(p_merchant_id uuid, p_branch_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF NOT public.feature_enabled('staff_accounts')
     OR NOT public.feature_enabled('cashier_mode_mobile') THEN
    RETURN false;
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff s
   WHERE s.merchant_id = p_merchant_id
     AND s.user_id = auth.uid()
     AND s.is_active
     AND NOT s.must_change_password
     AND s.role IN ('cashier','branch_manager')
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  IF v_staff.branch_id IS NULL THEN
    RETURN true;
  END IF;
  IF p_branch_id IS NULL THEN
    RETURN v_staff.role = 'branch_manager';
  END IF;
  RETURN v_staff.branch_id = p_branch_id;
END;
$function$;

-- ===================== RLS =====================

ALTER TABLE public.merchant_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_staff_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dine_in_tables ENABLE ROW LEVEL SECURITY;

-- Staff rows: the owner reads all of them; a staff member reads only
-- their own row. NO direct authenticated writes: staff management goes
-- through the service-role edge function.
CREATE POLICY merchant_staff_read ON public.merchant_staff FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

CREATE POLICY merchant_staff_events_owner_read ON public.merchant_staff_events
  FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_admin());

CREATE POLICY dine_in_tables_read ON public.dine_in_tables FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR public.is_active_staff(merchant_id));
CREATE POLICY dine_in_tables_owner_write ON public.dine_in_tables FOR ALL TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

-- Staff SELECT on existing POS tables (#249/#250): manager/cashier only,
-- flags on, password barrier, branch-scoped. No staff INSERT/UPDATE/
-- DELETE policies: mutations go through the SECURITY DEFINER RPCs.
-- orders / pos_customers / pos_debt_ledger get NO staff policies (Q5).
CREATE POLICY pos_sales_staff_read ON public.pos_sales FOR SELECT TO authenticated
  USING (public.staff_pos_read_ok(merchant_id, branch_id));
CREATE POLICY pos_sale_payments_staff_read ON public.pos_sale_payments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.pos_sales s
                  WHERE s.id = sale_id
                    AND public.staff_pos_read_ok(s.merchant_id, s.branch_id)));
CREATE POLICY pos_shifts_staff_read ON public.pos_shifts FOR SELECT TO authenticated
  USING (public.staff_pos_read_ok(merchant_id, branch_id));

-- ===================== staff RPCs =====================

-- Bootstrap for the app: who am I, which flags are on, is a password
-- change due. DECLARED EXCEPTION to the _authorize_staff barrier (#250):
-- it reveals only the caller's own staff row and flag states and is the
-- way the app learns it must route to the password-change screen.
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
      'staff_accounts', public.feature_enabled('staff_accounts'),
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
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  RETURN QUERY
  SELECT o.id, o.status, o.payment_method, o.payment_status, o.total_amount,
         o.items, u.full_name, u.phone, o.source, o.branch_id, o.created_at, o.updated_at
    FROM public.orders o
    LEFT JOIN public.users u ON u.id = o.user_id
   WHERE o.merchant_id = v_staff.merchant_id
     AND public.staff_can_branch(v_staff.merchant_id, o.branch_id)
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
  v_staff := public._authorize_staff('kitchen_screen', ARRAY['kitchen','cashier','branch_manager']);
  RETURN QUERY
  SELECT o.id, o.status,
         (SELECT coalesce(jsonb_agg(jsonb_build_object(
                    'name', coalesce(it.item ->> 'name', it.item ->> 'name_ar', ''),
                    -- S9: clamp BEFORE the ::int cast (hostile qty overflow).
                    'qty', least(9999, greatest(0, coalesce(
                                    public._num_or_null(it.item ->> 'quantity'),
                                    public._num_or_null(it.item ->> 'qty'), 1)))::int)), '[]'::jsonb)
            FROM jsonb_array_elements(coalesce(o.items, '[]'::jsonb)) AS it(item)),
         o.special_instructions,
         greatest(0, (extract(epoch from now() - o.created_at) / 60)::int),
         o.created_at
    FROM public.orders o
   WHERE o.merchant_id = v_staff.merchant_id
     AND o.status IN ('confirmed','preparing','ready')
     AND public.staff_can_branch(v_staff.merchant_id, o.branch_id)
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
  IF p_new_status NOT IN ('preparing','ready') THEN
    RAISE EXCEPTION 'status % is not staff-advanceable', p_new_status;
  END IF;
  v_staff := public._authorize_staff('kitchen_screen', ARRAY['kitchen','cashier','branch_manager']);
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.merchant_id IS DISTINCT FROM v_staff.merchant_id THEN
    RAISE EXCEPTION 'order not found';
  END IF;
  IF NOT public.staff_can_branch(v_staff.merchant_id, v_order.branch_id) THEN
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

-- Walk-in sale: server-side prices for catalog items, payments must sum to
-- the total, per-role discount caps, race-safe stock on the CANONICAL
-- products.stock_quantity, idempotent on (staff-scoped) client op id with
-- payload reconciliation, shift-linked, audited.
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
  v_op jsonb;
  v_existing public.pos_sales%ROWTYPE;
  v_request_hash text;
  v_custom_cap numeric;
  v_charge_id bigint;
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

  -- Canonical request fingerprint (#256): the replay contract compares the
  -- WHOLE request, not just the op id.
  v_request_hash := md5(jsonb_build_object(
    'items', p_items, 'payments', p_payments, 'discount', v_discount,
    'customer', p_pos_customer_id, 'branch', v_branch)::text);

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
      -- Server-side price: the client never names a price for catalog items.
      v_price := v_product.price;
      v_label := coalesce(v_product.name_ar, v_product.name);
      -- Stock ops are collected and applied after the sale row exists so
      -- the moves can link back to it (S3); same transaction = atomic.
      IF v_product.stock_quantity IS NOT NULL THEN
        v_stock_ops := v_stock_ops || jsonb_build_object(
          'product_id', v_product.id, 'qty', v_qty, 'label', v_label);
      END IF;
    ELSE
      -- Free-text line (service-shop simple invoice): EXPLICIT custom only
      -- (S2), price > 0, manager or service-type shop, value-capped.
      IF coalesce((v_item ->> 'custom')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'non-catalog lines must be explicit custom items';
      END IF;
      IF v_staff.role <> 'branch_manager' AND v_merchant.type <> 'service' THEN
        RAISE EXCEPTION 'custom lines need a branch manager or a service-type shop';
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
    END IF;
    v_subtotal := v_subtotal + round(v_price * v_qty, 2);
    v_normalized := v_normalized || jsonb_build_object(
      'product_id', v_item ->> 'product_id', 'label', v_label,
      'qty', v_qty, 'unit_price', v_price);
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

-- Shifts: one open shift per staff member (partial unique index AND a
-- shared advisory lock across open/sale/close, #252); close computes the
-- expected drawer from actual cash payments + debt receipts and audits
-- the variance.
CREATE FUNCTION public.staff_shift_open(p_opening_float numeric DEFAULT 0, p_client_op_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_id uuid;
  v_float numeric;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  v_float := round(coalesce(p_opening_float, -1), 2);
  IF v_float < 0 THEN
    RAISE EXCEPTION 'opening float must be >= 0';
  END IF;
  -- Serialize with sale/close for this staff member (#252).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  IF p_client_op_id IS NOT NULL THEN
    SELECT s.id, s.opening_float INTO v_id, v_float FROM public.pos_shifts s
     WHERE s.merchant_id = v_staff.merchant_id AND s.client_op_id = p_client_op_id
     LIMIT 1;
    IF FOUND THEN
      -- Replay must reconcile the payload (#256): same op id, different
      -- float, or another staff member's shift is a conflict.
      IF v_float IS DISTINCT FROM round(coalesce(p_opening_float, -1), 2)
         OR NOT EXISTS (SELECT 1 FROM public.pos_shifts s2
                         WHERE s2.id = v_id AND s2.opened_by_staff = v_staff.id) THEN
        RAISE EXCEPTION 'idempotency key reused with a different request';
      END IF;
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
    (v_staff.merchant_id, p_client_op_id, auth.uid(), round(p_opening_float, 2),
     v_staff.branch_id, v_staff.id)
  RETURNING id INTO v_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_opened',
          jsonb_build_object('shift_id', v_id, 'float', p_opening_float), auth.uid());
  RETURN jsonb_build_object('id', v_id, 'idempotent_replay', false);
EXCEPTION WHEN unique_violation THEN
  -- Two concurrent opens: the partial unique index fired; the winner's
  -- shift exists now (#252).
  RAISE EXCEPTION 'close your current shift before opening a new one';
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
  v_debt_cash numeric;
  v_totals jsonb;
  v_expected numeric;
  v_variance numeric;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  IF coalesce(p_closing_cash, -1) < 0 THEN
    RAISE EXCEPTION 'closing cash must be >= 0';
  END IF;
  -- Serialize with open/sale for this staff member (#252).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
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
  -- S7: cash debt receipts taken on this shift count in the drawer.
  SELECT coalesce(sum(l.amount), 0) INTO v_debt_cash
    FROM public.pos_debt_ledger l
   WHERE l.shift_id = v_shift.id AND l.kind = 'payment';
  v_expected := v_shift.opening_float + v_cash + v_debt_cash;
  v_variance := round(p_closing_cash, 2) - v_expected;
  UPDATE public.pos_shifts
     SET closed_at = now(), closing_cash = round(p_closing_cash, 2),
         expected_cash = v_expected,
         totals = v_totals || jsonb_build_object('debt_receipts', v_debt_cash)
   WHERE id = v_shift.id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'shift_closed',
          jsonb_build_object('shift_id', v_shift.id, 'expected', v_expected,
                             'counted', p_closing_cash, 'variance', v_variance,
                             'debt_receipts', v_debt_cash),
          auth.uid());
  RETURN jsonb_build_object('id', v_shift.id, 'expected', v_expected,
                            'counted', p_closing_cash, 'variance', v_variance);
END;
$function$;

-- Void: managers only; restores exactly the stock the sale's own stock
-- moves applied (S3); reverses deferred charges with explicit reversal
-- rows (S3/346 pattern); audited.
CREATE FUNCTION public.staff_void_sale(p_sale_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_staff public.merchant_staff%ROWTYPE;
  v_sale public.pos_sales%ROWTYPE;
  v_move record;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['branch_manager']);
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'void reason required';
  END IF;
  SELECT * INTO v_sale FROM public.pos_sales WHERE id = p_sale_id FOR UPDATE;
  IF NOT FOUND OR v_sale.merchant_id IS DISTINCT FROM v_staff.merchant_id THEN
    RAISE EXCEPTION 'sale not found';
  END IF;
  IF NOT public.staff_can_branch(v_staff.merchant_id, v_sale.branch_id) THEN
    RAISE EXCEPTION 'sale belongs to another branch';
  END IF;
  IF v_sale.voided_at IS NOT NULL THEN
    RAISE EXCEPTION 'sale already voided';
  END IF;
  -- Restore stock from the sale's OWN moves (S3): exactly what was
  -- applied, per product, only where stock is tracked.
  FOR v_move IN
    SELECT m.product_id, -sum(m.qty) AS restore_qty
      FROM public.pos_stock_moves m
     WHERE m.sale_id = p_sale_id AND m.kind = 'sale' AND m.product_id IS NOT NULL
     GROUP BY m.product_id
  LOOP
    UPDATE public.products
       SET stock_quantity = stock_quantity + v_move.restore_qty, updated_at = now()
     WHERE id = v_move.product_id AND stock_quantity IS NOT NULL;
    INSERT INTO public.pos_stock_moves
      (merchant_id, product_id, kind, qty, note, created_by, sale_id)
    VALUES
      (v_staff.merchant_id, v_move.product_id, 'void_restore',
       v_move.restore_qty, 'void ' || p_sale_id, auth.uid(), p_sale_id);
  END LOOP;
  -- Reverse deferred charges with explicit reversal rows (idempotent).
  INSERT INTO public.pos_debt_ledger
    (merchant_id, customer_id, sale_id, client_op_id, kind, amount, note, created_by)
  SELECT d.merchant_id, d.customer_id, d.sale_id,
         md5('void-reversal:' || d.id::text)::uuid,
         'reversal', d.amount, 'عكس مديونية لإلغاء العملية', auth.uid()
    FROM public.pos_debt_ledger d
   WHERE d.sale_id = p_sale_id AND d.kind = 'charge'
     AND NOT EXISTS (SELECT 1 FROM public.pos_debt_ledger r
                      WHERE r.sale_id = d.sale_id AND r.kind = 'reversal')
  ON CONFLICT (merchant_id, client_op_id) DO NOTHING;
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

-- أجل debt payment (cash received against a tab): cashier + manager;
-- tied to the caller's open shift (S7), capped (S11), idempotent with
-- payload reconciliation (#256), audited.
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
  v_amount numeric;
  v_cap numeric;
  v_shift uuid;
  v_existing public.pos_debt_ledger%ROWTYPE;
BEGIN
  v_staff := public._authorize_staff('cashier_mode_mobile', ARRAY['cashier','branch_manager']);
  v_amount := round(coalesce(p_amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  -- S11: conservative default cap; platform-owner tunable. Anything above
  -- the cap needs the owner to raise it (manager-approval flow is later).
  v_cap := coalesce(
    (SELECT public._num_or_null(feature_flags ->> 'debt_payment_cap')
       FROM public.platform_settings WHERE id = 'default'), 5000);
  IF v_amount > v_cap THEN
    RAISE EXCEPTION 'debt payment exceeds the % cap', v_cap;
  END IF;
  IF p_client_op_id IS NULL THEN
    RAISE EXCEPTION 'client op id required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pos_customers c
                  WHERE c.id = p_customer_id AND c.merchant_id = v_staff.merchant_id) THEN
    RAISE EXCEPTION 'customer does not belong to this shop';
  END IF;
  -- Same-staff serialization for this op id (#256).
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.merchant_id::text || ':' || p_client_op_id::text, 442003));
  -- Replay reconciles the payload: same customer + amount or conflict.
  SELECT * INTO v_existing FROM public.pos_debt_ledger l
   WHERE l.merchant_id = v_staff.merchant_id AND l.client_op_id = p_client_op_id;
  IF FOUND THEN
    IF v_existing.customer_id IS DISTINCT FROM p_customer_id
       OR v_existing.amount IS DISTINCT FROM v_amount
       OR v_existing.kind IS DISTINCT FROM 'payment' THEN
      RAISE EXCEPTION 'idempotency key reused with a different request';
    END IF;
    RETURN jsonb_build_object('id', v_existing.id, 'idempotent_replay', true);
  END IF;
  -- S7: a debt receipt is cash in hand — it belongs to an open shift.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_staff.id::text, 442002));
  SELECT s.id INTO v_shift FROM public.pos_shifts s
   WHERE s.merchant_id = v_staff.merchant_id
     AND s.opened_by_staff = v_staff.id AND s.closed_at IS NULL
   ORDER BY s.opened_at DESC LIMIT 1;
  IF v_shift IS NULL THEN
    RAISE EXCEPTION 'open a shift before taking cash';
  END IF;
  INSERT INTO public.pos_debt_ledger
    (merchant_id, customer_id, client_op_id, kind, amount, note, created_by, shift_id)
  VALUES
    (v_staff.merchant_id, p_customer_id, p_client_op_id, 'payment',
     v_amount, p_note, auth.uid(), v_shift)
  RETURNING id INTO v_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'debt_payment',
          jsonb_build_object('customer_id', p_customer_id, 'amount', v_amount),
          auth.uid());
  RETURN jsonb_build_object('id', v_id, 'idempotent_replay', false);
END;
$function$;

-- End-of-day report: owner (any branch or combined) or branch manager
-- (own branch only). The merchant parameter is VALIDATED against the
-- caller, never trusted. Day bounds are Africa/Cairo calendar days (S8).
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
  v_from timestamptz;
  v_to timestamptz;
BEGIN
  -- The report is dark like every other surface: master + surface flag
  -- required no matter who asks (#250).
  IF NOT public.feature_enabled('staff_accounts')
     OR NOT public.feature_enabled('eod_report') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  v_is_owner := public.is_merchant_owner(p_merchant_id);
  IF NOT v_is_owner THEN
    v_staff := public._authorize_staff('eod_report', ARRAY['branch_manager']);
    IF v_staff.merchant_id IS DISTINCT FROM p_merchant_id THEN
      RAISE EXCEPTION 'not your shop';
    END IF;
    -- A branch manager sees only their own branch; an all-branches
    -- manager (NULL) may pick one or read the combined report.
    IF v_staff.branch_id IS NOT NULL THEN
      IF p_branch_id IS NOT NULL AND p_branch_id <> v_staff.branch_id THEN
        RAISE EXCEPTION 'branch outside your scope';
      END IF;
      v_scope := v_staff.branch_id;
    ELSE
      v_scope := p_branch_id;
    END IF;
  ELSE
    v_scope := p_branch_id;
  END IF;

  v_from := p_day::timestamp AT TIME ZONE 'Africa/Cairo';
  v_to := (p_day + 1)::timestamp AT TIME ZONE 'Africa/Cairo';

  SELECT jsonb_build_object(
      'count', count(*), 'total', coalesce(sum(s.total_amount), 0),
      'by_method', coalesce((SELECT jsonb_object_agg(p.method, p.total) FROM (
        SELECT p2.method, sum(p2.amount) AS total
          FROM public.pos_sale_payments p2
          JOIN public.pos_sales s2 ON s2.id = p2.sale_id
         WHERE s2.merchant_id = p_merchant_id AND s2.status = 'completed'
           AND s2.created_at >= v_from AND s2.created_at < v_to
           AND (v_scope IS NULL OR s2.branch_id = v_scope)
         GROUP BY p2.method) p), '{}'::jsonb))
    INTO v_sales
    FROM public.pos_sales s
   WHERE s.merchant_id = p_merchant_id AND s.status = 'completed'
     AND s.created_at >= v_from AND s.created_at < v_to
     AND (v_scope IS NULL OR s.branch_id = v_scope);

  SELECT jsonb_build_object('count', count(*), 'total', coalesce(sum(o.total_amount), 0))
    INTO v_app_orders
    FROM public.orders o
   WHERE o.merchant_id = p_merchant_id AND o.status = 'delivered'
     AND o.source = 'app'
     AND o.created_at >= v_from AND o.created_at < v_to
     AND (v_scope IS NULL OR o.branch_id = v_scope);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'opened_at', s.opened_at, 'closed_at', s.closed_at,
      'expected', s.expected_cash, 'counted', s.closing_cash,
      'variance', s.closing_cash - s.expected_cash)), '[]'::jsonb)
    INTO v_shifts
    FROM public.pos_shifts s
   WHERE s.merchant_id = p_merchant_id
     AND s.opened_at >= v_from AND s.opened_at < v_to
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
REVOKE EXECUTE ON FUNCTION public._assert_branch_not_reparented() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._block_staff_event_mutation() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._assert_table_branch_match() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._assert_sale_links_match() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._num_or_null(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._authorize_staff(text, text[]) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.feature_enabled(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_active_staff(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_role(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_branch_id(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_can_branch(uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.staff_pos_read_ok(uuid, uuid) FROM PUBLIC, anon;
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
GRANT EXECUTE ON FUNCTION public.staff_pos_read_ok(uuid, uuid) TO authenticated;
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
