-- 444: merchant-staff-admin support (design v3 PR-A, dark).
--
-- Owner steering 2026-11-25 (relayed by the main agent): the cashier works
-- for ALL goods-selling merchant types; cafes and juice shops are cashier
-- types; simple services (teachers etc.) get a simple provider profile.
-- Security reviewer CONDITIONAL GO 2026-11-25, conditions folded in:
--   B1 is_cashier_type is pure/IMMUTABLE/SECURITY INVOKER, fail closed.
--   B2 the type partition is exhaustive; the suite pins the expected
--      mapping for every merchants_type_check value.
--   A8 table writes happen ONLY through caller-JWT executor RPCs; the
--      service-role key never writes business tables.
--   A10 create_staff checks is_cashier_type; refused attempts are audited.
--
-- This migration adds:
--   1. users_user_type_check += 'merchant_staff' (staff auth users are
--      neither customers nor merchants; the edge function creates them
--      with user_metadata.user_type='merchant_staff').
--   2. is_cashier_type(text) - the ONE canonical eligibility list.
--   3. staff_admin_create_staff / staff_admin_set_active /
--      staff_admin_record_password_reset - SECURITY DEFINER executors
--      callable by authenticated; every one re-checks ownership and
--      eligibility server-side and audits.
--
-- NOT here (PR-B): juice_shop in merchants_type_check, presets, the
-- custom-line rule change, eligibility gating inside 442's staff RPCs.

BEGIN;

-- A0 preconditions -----------------------------------------------------------
DO $a0$
DECLARE
  v_chk text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                  WHERE table_schema = 'public' AND table_name = 'merchant_staff') THEN
    RAISE EXCEPTION '444 precondition failed: merchant_staff missing (442 not applied)';
  END IF;
  SELECT pg_get_constraintdef(oid) INTO v_chk FROM pg_constraint
   WHERE conname = 'users_user_type_check' AND conrelid = 'public.users'::regclass;
  IF v_chk IS DISTINCT FROM 'CHECK ((user_type = ANY (ARRAY[''customer''::text, ''merchant''::text, ''driver''::text, ''provider''::text, ''delivery''::text, ''admin''::text, ''owner''::text, ''super_admin''::text, ''country_admin''::text, ''governorate_admin''::text, ''center_admin''::text, ''village_admin''::text])))' THEN
    RAISE EXCEPTION '444 precondition failed: users_user_type_check drifted: %', v_chk;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public'
                AND p.proname IN ('is_cashier_type', 'staff_admin_create_staff',
                                  'staff_admin_set_active', 'staff_admin_record_password_reset',
                                  'staff_admin_audit_refusal')) THEN
    RAISE EXCEPTION '444 precondition failed: a 444 function name already exists';
  END IF;
END;
$a0$;

-- 1. user_type ---------------------------------------------------------------
ALTER TABLE public.users DROP CONSTRAINT users_user_type_check;
ALTER TABLE public.users ADD CONSTRAINT users_user_type_check
  CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text,
    'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text,
    'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text,
    'village_admin'::text, 'merchant_staff'::text])));

-- 2. the canonical cashier-type gate (B1) ------------------------------------
-- Cashier-types sell catalog goods and get staff/branch/cashier surfaces.
-- Everything else (including NULL and unknown future types) fails CLOSED.
-- 'food' is deliberately NOT eligible yet (owner confirmation pending,
-- 2026-11-25); 'home' IS eligible (owner 22:41: home goods/supplies are a
-- shop; the customer app renders type 'home' as a commerce/goods store).
CREATE FUNCTION public.is_cashier_type(p_type text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(p_type = ANY (ARRAY[
    'restaurant','cafe','juice_shop','bakery','sweets','grocery','supermarket',
    'fruits','vegetables','butcher','meat','seafood','dairy','spices','general',
    'electronics','mobile','fashion','clothing','shoes','accessories','perfumes',
    'flowers','petShop','furniture','home'
  ]), false);
$function$;

REVOKE ALL ON FUNCTION public.is_cashier_type(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_cashier_type(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_cashier_type(text) TO authenticated;

-- 3. executors ----------------------------------------------------------------

-- create_staff: called by the merchant-staff-admin edge function under the
-- CALLER's JWT, AFTER the edge function created a fresh auth user. Refuses
-- to touch any pre-existing account: the target users row must carry the
-- synthetic staff email the edge function just minted.
CREATE FUNCTION public.staff_admin_create_staff(
  p_merchant_id uuid,
  p_auth_user_id uuid,
  p_username text,
  p_full_name text,
  p_role text,
  p_branch_id uuid,
  p_phone text,
  p_login_username text
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_staff_id uuid;
  v_refused text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(p_merchant_id) THEN
    v_refused := 'not the merchant owner';
  ELSIF NOT public.is_cashier_type(v_merchant.type) THEN
    v_refused := 'merchant type is not cashier-eligible';
  ELSIF p_role NOT IN ('branch_manager', 'cashier', 'kitchen') THEN
    v_refused := 'invalid staff role';
  ELSIF p_role IN ('cashier', 'kitchen') AND p_branch_id IS NULL THEN
    v_refused := 'cashier/kitchen need a branch';
  ELSIF p_branch_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.branches b
         WHERE b.id = p_branch_id AND b.merchant_id = p_merchant_id) THEN
    v_refused := 'branch does not belong to the merchant';
  ELSIF nullif(btrim(coalesce(p_username, '')), '') IS NULL
        OR p_username !~ '^[a-zA-Z0-9_]{3,22}$' THEN
    v_refused := 'invalid username';
  ELSIF nullif(btrim(coalesce(p_full_name, '')), '') IS NULL THEN
    v_refused := 'full name required';
  ELSIF p_phone IS NOT NULL AND p_phone !~ '^\+[0-9]{8,15}$' THEN
    v_refused := 'invalid phone';
  ELSIF p_login_username IS NULL OR p_login_username !~ '^[a-z0-9_]{3,30}$'
        OR p_login_username ~ '^[0-9]+$' THEN
    v_refused := 'invalid login username';
  ELSE
    SELECT * INTO v_user FROM public.users WHERE id = p_auth_user_id;
    IF NOT FOUND OR v_user.email NOT LIKE 'staff\_%@delwaqty.app' ESCAPE '\' THEN
      v_refused := 'target is not a fresh staff auth user';
    ELSIF EXISTS (SELECT 1 FROM public.merchant_staff s WHERE s.user_id = p_auth_user_id) THEN
      v_refused := 'auth user already has a staff row';
    ELSIF EXISTS (SELECT 1 FROM public.users u
                   WHERE u.username IS NOT NULL
                     AND lower(u.username) = lower(p_login_username)) THEN
      v_refused := 'login username taken';
    END IF;
  END IF;

  IF v_refused IS NOT NULL THEN
    -- A10: refused attempts are logged by the edge function through
    -- staff_admin_audit_refusal AFTER this error propagates (an insert
    -- here would roll back with the error's transaction).
    RAISE EXCEPTION 'staff creation refused: %', v_refused;
  END IF;

  -- Claim the global login identifier, then create the staff row.
  UPDATE public.users
     SET username = p_login_username, user_type = 'merchant_staff', updated_at = now()
   WHERE id = p_auth_user_id;

  INSERT INTO public.merchant_staff
    (merchant_id, user_id, username, full_name, phone, role, branch_id, created_by)
  VALUES
    (p_merchant_id, p_auth_user_id, btrim(p_username), btrim(p_full_name),
     nullif(btrim(coalesce(p_phone, '')), ''), p_role, p_branch_id, v_caller)
  RETURNING id INTO v_staff_id;

  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff_id, p_merchant_id, 'created',
          jsonb_build_object('role', p_role, 'username', btrim(p_username),
                             'branch_id', p_branch_id),
          v_caller);
  RETURN v_staff_id;
END;
$function$;

CREATE FUNCTION public.staff_admin_set_active(p_staff_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';  -- generic: no tenant enumeration
  END IF;
  IF p_active THEN
    UPDATE public.merchant_staff
       SET is_active = true, disabled_at = NULL, disabled_by = NULL, updated_at = now()
     WHERE id = p_staff_id;
    INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
    VALUES (p_staff_id, v_staff.merchant_id, 'enabled', v_caller);
  ELSE
    UPDATE public.merchant_staff
       SET is_active = false, disabled_at = now(), disabled_by = v_caller, updated_at = now()
     WHERE id = p_staff_id;
    INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
    VALUES (p_staff_id, v_staff.merchant_id, 'disabled', v_caller);
  END IF;
END;
$function$;

-- password_reset audit: the edge function rotates the password through
-- GoTrue and calls this to leave the trail. It takes NO secret material.
CREATE FUNCTION public.staff_admin_record_password_reset(p_staff_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_staff public.merchant_staff%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  UPDATE public.merchant_staff
     SET must_change_password = true, updated_at = now()
   WHERE id = p_staff_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
  VALUES (p_staff_id, v_staff.merchant_id, 'password_reset', v_caller);
END;
$function$;

-- Refusal log (A10): insert-only, callable by ANY authenticated caller
-- (a refused would-be attacker included) - it can only append audit rows
-- naming the caller; it reads nothing and reveals nothing.
CREATE FUNCTION public.staff_admin_audit_refusal(p_merchant_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (NULL, p_merchant_id, 'created',
          jsonb_build_object('refused', left(coalesce(p_reason, ''), 80), 'via', 'edge'),
          auth.uid());
END;
$function$;

REVOKE ALL ON FUNCTION public.staff_admin_create_staff(uuid, uuid, text, text, text, uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_create_staff(uuid, uuid, text, text, text, uuid, text, text) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_set_active(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_set_active(uuid, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_record_password_reset(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_record_password_reset(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_audit_refusal(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_audit_refusal(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.staff_admin_create_staff(uuid, uuid, text, text, text, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_set_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_record_password_reset(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_audit_refusal(uuid, text) TO authenticated;

COMMIT;
