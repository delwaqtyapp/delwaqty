-- 444: merchant-staff-admin support (design v3 PR-A, dark), round 2:
-- code findings #259-#265 + security S1-S7 folded in.
--
-- Architecture (state machine at the DB boundary, #261):
--   provision_begin  - caller-JWT RPC: flag + ownership + eligibility +
--                      rate + payload checks; derives the canonical login
--                      username server-side; writes a one-use, 10-minute
--                      staff_provisioning row bound to owner+merchant.
--   (edge only)      - GoTrue createUser with admin-only app_metadata
--                      {staff_provisioning: <id>}; password is generated
--                      by the edge, never by the DB.
--   provision_complete - caller-JWT RPC: consumes the provisioning row
--                      ATOMICALLY (state pending->consumed, one winner),
--                      requires the auth user to carry the SAME id in
--                      raw_app_meta_data (only the service key can write
--                      app_metadata - S3), claims the login username and
--                      creates the staff row. No email-shape heuristics.
--   provision_abort  - owner marks a pending row aborted (GoTrue failure,
--                      orphaned-auth-user flag for cleanup retry).
--   set_active / record_password_reset - DB first (ownership + flag +
--                      rate + audit), GoTrue effects AFTER; GoTrue
--                      failure is a refusal, never a false ok.
--   audit_refusal    - bounded refusal log: owner-confirmed refusals go
--                      to the merchant log as kind 'refused' (S1: the
--                      kind CHECK is extended); anyone else's refusals go
--                      to a separate caller-keyed, per-caller-capped
--                      table - never into a merchant's audit trail.
--   staff_password_changed - active staff clears their OWN
--                      must_change_password barrier after changing it (S7,
--                      included in this PR).
--
-- S3 hardening: handle_new_user (pinned pre-image) now forces
-- user_type='customer' when client signup metadata claims
-- 'merchant_staff'; self-signup can never become staff. The edge no
-- longer sends user_type at all.
--
-- #260: merchant_staff gains a GLOBAL UNIQUE(user_id).

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
  SELECT pg_get_constraintdef(oid) INTO v_chk FROM pg_constraint
   WHERE conname = 'merchant_staff_events_kind_check' AND conrelid = 'public.merchant_staff_events'::regclass;
  IF v_chk IS DISTINCT FROM 'CHECK ((kind = ANY (ARRAY[''created''::text, ''role_changed''::text, ''branch_changed''::text, ''disabled''::text, ''enabled''::text, ''password_reset''::text, ''walk_in_sale''::text, ''void_sale''::text, ''debt_payment''::text, ''shift_opened''::text, ''shift_closed''::text, ''order_status''::text])))' THEN
    RAISE EXCEPTION '444 precondition failed: merchant_staff_events_kind_check drifted: %', v_chk;
  END IF;
  IF md5(pg_get_functiondef('public.handle_new_user()'::regprocedure))
     <> '3bb10a3336503d4f558c27d66493e39e' THEN
    RAISE EXCEPTION '444 precondition failed: handle_new_user drifted from the pinned pre-image';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public'
                AND p.proname IN ('is_cashier_type', 'staff_admin_provision_begin',
                                  'staff_admin_provision_complete', 'staff_admin_provision_abort',
                                  'staff_admin_set_active', 'staff_admin_record_password_reset',
                                  'staff_admin_audit_refusal', 'staff_password_changed')) THEN
    RAISE EXCEPTION '444 precondition failed: a 444 function name already exists';
  END IF;
END;
$a0$;

-- 1. user_type + handle_new_user hardening (S3) -------------------------------
ALTER TABLE public.users DROP CONSTRAINT users_user_type_check;
ALTER TABLE public.users ADD CONSTRAINT users_user_type_check
  CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text,
    'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text,
    'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text,
    'village_admin'::text, 'merchant_staff'::text])));

-- Client signup metadata can never self-register as merchant_staff; the ONLY
-- path to that user_type is staff_admin_provision_complete below.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_type TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'user_type', ''),
    'customer'
  );
  v_require_docs BOOLEAN := false;
  v_verification TEXT;
  v_full_name TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    'User'
  );
  v_phone TEXT := COALESCE(
    NULLIF(NEW.phone, ''),
    NULLIF(NEW.raw_user_meta_data->>'phone', '')
  );
  v_language TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'language', ''),
    'ar'
  );
BEGIN
  -- 444/S3: 'merchant_staff' is never accepted from client metadata.
  IF v_user_type = 'merchant_staff' THEN
    v_user_type := 'customer';
  END IF;

  SELECT COALESCE(require_provider_documents, false)
    INTO v_require_docs
    FROM public.platform_settings
   WHERE id = 'default';

  -- SECURITY: never trust verification_status from client-supplied signup
  -- metadata (anyone with the public anon key can set it). Derive it here.
  v_verification := CASE
    WHEN v_user_type = 'customer' THEN 'approved'
    WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false) THEN 'approved'
    ELSE 'pending'
  END;

  INSERT INTO public.users (
    id, email, full_name, phone, language, is_onboarded,
    role, user_type, verification_status, created_at, updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_full_name,
    v_phone,
    v_language,
    true,
    v_user_type,
    v_user_type,
    v_verification,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET phone = COALESCE(EXCLUDED.phone, public.users.phone),
        full_name = CASE
          WHEN public.users.full_name IS NULL OR public.users.full_name = '' OR public.users.full_name = 'User'
          THEN EXCLUDED.full_name
          ELSE public.users.full_name
        END,
        verification_status = CASE
          WHEN v_user_type IN ('merchant', 'provider') AND NOT COALESCE(v_require_docs, false)
          THEN 'approved'
          ELSE public.users.verification_status
        END,
        updated_at = NOW();

  -- Merchant signup creates its storefront. Provider targets are created only
  -- by the category-aware business approval/provisioning flow.
  IF v_user_type = 'merchant' THEN
    IF NOT EXISTS (SELECT 1 FROM public.merchants WHERE owner_user_id = NEW.id) THEN
      INSERT INTO public.merchants (
        owner_user_id, name, email, phone, type, status, is_open,
        delivery_fee, min_order, delivery_time_min, rating
      )
      VALUES (
        NEW.id,
        v_full_name,
        COALESCE(NEW.email, ''),
        v_phone,
        'restaurant',
        'active',
        true,
        15,
        0,
        30,
        5.0
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 2. the canonical cashier-type gate (B1) ------------------------------------
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

-- 3. tables -------------------------------------------------------------------
-- One-use provisioning records (the DB boundary of the state machine).
CREATE TABLE public.staff_provisioning (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  payload jsonb NOT NULL,
  login_username text NOT NULL,
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','consumed','aborted')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
  consumed_at timestamptz
);
REVOKE ALL ON public.staff_provisioning FROM PUBLIC, anon, authenticated;

-- Non-owner refusal log (S1): caller-keyed, capped, never in merchant logs.
CREATE TABLE public.staff_admin_refusals (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  caller_id uuid NOT NULL,
  merchant_id uuid,
  action text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON public.staff_admin_refusals FROM PUBLIC, anon, authenticated;

-- #260: one auth user = at most one staff row, platform-wide.
ALTER TABLE public.merchant_staff ADD CONSTRAINT merchant_staff_user_id_key UNIQUE (user_id);

-- S1: 'refused' (owner-side refusal log) + 'password_changed' (S7 barrier).
ALTER TABLE public.merchant_staff_events DROP CONSTRAINT merchant_staff_events_kind_check;
ALTER TABLE public.merchant_staff_events ADD CONSTRAINT merchant_staff_events_kind_check
  CHECK ((kind = ANY (ARRAY['created'::text, 'role_changed'::text, 'branch_changed'::text,
    'disabled'::text, 'enabled'::text, 'password_reset'::text, 'walk_in_sale'::text,
    'void_sale'::text, 'debt_payment'::text, 'shift_opened'::text, 'shift_closed'::text,
    'order_status'::text, 'refused'::text, 'password_changed'::text])));

-- 4. executors ----------------------------------------------------------------
-- Refusal error text is GENERIC to the caller (#263); the specific reason is
-- only in the server-side log the edge writes afterwards.

-- #261/#262: GoTrue completion protocol state on the staff row. Enable is
-- FAIL CLOSED: is_active flips true only in staff_admin_sync_complete after
-- the edge verifies the GoTrue side. sync_state 'failed' is the actionable
-- blocked state the owner retries from. password_digest is the server-side
-- proof anchor for staff_password_changed (security blocking 1 / #266).
ALTER TABLE public.merchant_staff
  ADD COLUMN password_digest text,
  ADD COLUMN sync_state text NOT NULL DEFAULT 'ok',
  ADD COLUMN sync_op text;
ALTER TABLE public.merchant_staff
  ADD CONSTRAINT merchant_staff_sync_state_check
    CHECK (sync_state IN ('ok', 'pending', 'failed')),
  ADD CONSTRAINT merchant_staff_sync_op_check
    CHECK (sync_op IN ('enable', 'disable', 'reset'));

CREATE FUNCTION public.staff_admin_provision_begin(
  p_merchant_id uuid,
  p_username text,
  p_full_name text,
  p_role text,
  p_branch_id uuid,
  p_phone text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_username text := lower(btrim(coalesce(p_username, '')));
  v_login text;
  v_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  -- DB-boundary rate limit (#261): 60 begins/hour per owner.
  IF NOT public._lookup_rate_allow('staffadm:begin:' || v_caller, 60) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(p_merchant_id) THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF NOT public.is_cashier_type(v_merchant.type) THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF p_role NOT IN ('branch_manager', 'cashier', 'kitchen') THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF p_role IN ('cashier', 'kitchen') AND p_branch_id IS NULL THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF p_branch_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.branches b
         WHERE b.id = p_branch_id AND b.merchant_id = p_merchant_id) THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  -- S5: canonical derived form <username>__<6 hex of merchant id>; the
  -- username part is lowercase, slug-shaped, and never a reserved claim.
  IF v_username !~ '^[a-z0-9_]{3,22}$'
     OR v_username ~ '^[0-9]+$'
     OR v_username IN ('admin', 'support', 'owner', 'root', 'system') THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF nullif(btrim(coalesce(p_full_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF p_phone IS NOT NULL AND p_phone !~ '^\+[0-9]{8,15}$' THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  v_login := v_username || '__' || substr(replace(p_merchant_id::text, '-', ''), 1, 6);
  IF EXISTS (SELECT 1 FROM public.users u
              WHERE u.username IS NOT NULL AND lower(u.username) = v_login) THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;

  INSERT INTO public.staff_provisioning (merchant_id, owner_id, payload, login_username)
  VALUES (p_merchant_id, v_caller,
          jsonb_build_object('username', v_username, 'full_name', btrim(p_full_name),
                             'role', p_role, 'branch_id', p_branch_id,
                             'phone', nullif(btrim(coalesce(p_phone, '')), '')),
          v_login)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('provision_id', v_id, 'login_username', v_login);
END;
$function$;

CREATE FUNCTION public.staff_admin_provision_complete(p_provision_id uuid, p_auth_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_prov public.staff_provisioning%ROWTYPE;
  v_auth record;
  v_staff_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  -- Atomic one-use consume: exactly one caller wins, even concurrently.
  UPDATE public.staff_provisioning
     SET state = 'consumed', consumed_at = now()
   WHERE id = p_provision_id
     AND state = 'pending'
     AND expires_at > now()
     AND owner_id = v_caller
  RETURNING * INTO v_prov;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;

  -- Re-validate CURRENT state at consume time (#260): ownership, merchant
  -- status/type and branch validity may have changed since begin.
  IF NOT public.is_merchant_owner(v_prov.merchant_id) THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  PERFORM 1 FROM public.merchants m
   WHERE m.id = v_prov.merchant_id AND m.status = 'active'
     AND public.is_cashier_type(m.type);
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  IF nullif(v_prov.payload->>'branch_id', '') IS NOT NULL THEN
    PERFORM 1 FROM public.branches b
     WHERE b.id = (v_prov.payload->>'branch_id')::uuid
       AND b.merchant_id = v_prov.merchant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'staff creation refused';
    END IF;
  END IF;

  -- The auth user must be the one the edge just created FOR THIS provision:
  -- raw_app_meta_data is writable only by the service key (S3).
  SELECT id, created_at, raw_app_meta_data INTO v_auth
    FROM auth.users WHERE id = p_auth_user_id;
  IF NOT FOUND
     OR v_auth.raw_app_meta_data->>'staff_provisioning' IS DISTINCT FROM p_provision_id::text
     OR v_auth.created_at < now() - interval '15 minutes' THEN
    -- No state write here: it would roll back with this RAISE. The consume
    -- UPDATE rolls back too, so the row stays 'pending' and the edge's
    -- follow-up staff_admin_provision_abort call records the abort.
    RAISE EXCEPTION 'staff creation refused';
  END IF;

  -- Claim the login identifier and the staff user_type in one shot; a
  -- concurrent claim loses on the users_username_unique_idx / CHECK.
  UPDATE public.users
     SET username = v_prov.login_username, user_type = 'merchant_staff', updated_at = now()
   WHERE id = p_auth_user_id AND username IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;

  INSERT INTO public.merchant_staff
    (merchant_id, user_id, username, full_name, phone, role, branch_id, created_by)
  VALUES (
    v_prov.merchant_id, p_auth_user_id,
    v_prov.payload->>'username', v_prov.payload->>'full_name',
    nullif(v_prov.payload->>'phone', ''), v_prov.payload->>'role',
    nullif(v_prov.payload->>'branch_id', '')::uuid, v_caller)
  RETURNING id INTO v_staff_id;

  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (v_staff_id, v_prov.merchant_id, 'created',
          jsonb_build_object('role', v_prov.payload->>'role',
                             'username', v_prov.payload->>'username',
                             'branch_id', v_prov.payload->>'branch_id'),
          v_caller);
  RETURN v_staff_id;
END;
$function$;

CREATE FUNCTION public.staff_admin_provision_abort(p_provision_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_prov public.staff_provisioning%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  UPDATE public.staff_provisioning
     SET state = 'aborted',
         payload = payload || jsonb_build_object('abort_reason',
                    left(coalesce(p_reason, ''), 80))
   WHERE id = p_provision_id AND state = 'pending' AND owner_id = v_caller
  RETURNING * INTO v_prov;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff creation refused';
  END IF;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
  VALUES (NULL, v_prov.merchant_id, 'refused',
          jsonb_build_object('aborted', left(coalesce(p_reason, ''), 80)), v_caller);
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
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF NOT public._lookup_rate_allow('staffadm:state:' || v_caller, 120) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';  -- generic: no tenant enumeration
  END IF;
  -- FOR UPDATE serializes a concurrent enable/disable pair (#262): the
  -- second caller observes the first's pending op and overwrites it.
  IF p_active THEN
    -- FAIL CLOSED (#261): the row stays inactive until the edge verifies
    -- the GoTrue side (revoke + unban) and calls staff_admin_sync_complete.
    -- A direct-RPC enable can never activate the account.
    UPDATE public.merchant_staff
       SET sync_state = 'pending', sync_op = 'enable', updated_at = now()
     WHERE id = p_staff_id;
  ELSE
    -- Disable is safe to apply immediately (fail closed): access is cut in
    -- the same transaction; the GoTrue side catches up via the sync op.
    UPDATE public.merchant_staff
       SET is_active = false, disabled_at = now(), disabled_by = v_caller,
           sync_state = 'pending', sync_op = 'disable', updated_at = now()
     WHERE id = p_staff_id;
    INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
    VALUES (p_staff_id, v_staff.merchant_id, 'disabled', v_caller);
  END IF;
END;
$function$;

-- #261/#262: the edge reports the GoTrue outcome for the pending op; only a
-- verified completion activates an enable. 'failed' is the actionable
-- blocked state: re-calling the executor re-arms the op and the edge
-- re-drives the GoTrue side (bounded, owner-initiated retries).
CREATE FUNCTION public.staff_admin_sync_complete(p_staff_id uuid, p_op text, p_ok boolean)
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
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF NOT public._lookup_rate_allow('staffadm:sync:' || v_caller, 120) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id FOR UPDATE;
  IF NOT FOUND OR NOT public.is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  IF p_op NOT IN ('enable', 'disable', 'reset')
     OR v_staff.sync_state <> 'pending'
     OR v_staff.sync_op IS DISTINCT FROM p_op THEN
    RAISE EXCEPTION 'no pending sync operation';
  END IF;
  IF p_ok THEN
    IF p_op = 'enable' THEN
      UPDATE public.merchant_staff
         SET is_active = true, disabled_at = NULL, disabled_by = NULL,
             sync_state = 'ok', sync_op = NULL, updated_at = now()
       WHERE id = p_staff_id;
      INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
      VALUES (p_staff_id, v_staff.merchant_id, 'enabled', v_caller);
    ELSE
      UPDATE public.merchant_staff
         SET sync_state = 'ok', sync_op = NULL, updated_at = now()
       WHERE id = p_staff_id;
    END IF;
  ELSE
    UPDATE public.merchant_staff
       SET sync_state = 'failed', updated_at = now()
     WHERE id = p_staff_id;
    INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
    VALUES (p_staff_id, v_staff.merchant_id, 'refused',
            jsonb_build_object('action', 'sync', 'op', p_op), v_caller);
  END IF;
END;
$function$;

-- Security blocking 1 / #266: owner-checked digest snapshot taken AFTER a
-- verified GoTrue rotation (user creation or password reset). Stored digest
-- = md5(auth.users.encrypted_password); staff_password_changed requires the
-- live digest to differ.
CREATE FUNCTION public.staff_admin_mark_password_rotated(p_staff_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_staff public.merchant_staff%ROWTYPE;
  v_digest text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF NOT public._lookup_rate_allow('staffadm:markrot:' || v_caller, 120) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id;
  IF NOT FOUND OR NOT public.is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  SELECT md5(u.encrypted_password) INTO v_digest
    FROM auth.users u WHERE u.id = v_staff.user_id;
  IF v_digest IS NULL THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  UPDATE public.merchant_staff
     SET password_digest = v_digest, updated_at = now()
   WHERE id = p_staff_id;
END;
$function$;

-- password_reset: DB FIRST (S2) - ownership verified, barrier armed, audit
-- written - THEN the edge rotates in GoTrue. Takes NO secret material.
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
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF NOT public._lookup_rate_allow('staffadm:reset:' || v_caller, 60) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff WHERE id = p_staff_id;
  IF NOT FOUND OR NOT is_merchant_owner(v_staff.merchant_id) THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  UPDATE public.merchant_staff
     SET must_change_password = true,
         sync_state = 'pending', sync_op = 'reset', updated_at = now()
   WHERE id = p_staff_id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
  VALUES (p_staff_id, v_staff.merchant_id, 'password_reset', v_caller);
END;
$function$;

-- S1/#263: bounded refusal log with a fixed action vocabulary. Owner-confirmed
-- refusals go to the merchant log (kind 'refused'); everyone else's go to the
-- caller-keyed table, capped at 100 rows per caller per day, never into a
-- merchant's audit trail.
CREATE FUNCTION public.staff_admin_audit_refusal(p_merchant_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_reason text := left(coalesce(p_reason, ''), 40);
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF v_reason NOT IN ('create_staff', 'set_active', 'reset_password', 'list_staff',
                      'rate_limited', 'invalid_role', 'gotrue_failure', 'provision') THEN
    v_reason := 'provision';
  END IF;
  -- The advisory lock serializes the check-then-insert per caller so
  -- concurrent refusals cannot overrun the 100/day cap (#263).
  PERFORM pg_advisory_xact_lock(hashtext('staffref:' || v_caller::text));
  IF public.is_merchant_owner(p_merchant_id) THEN
    -- Owner branch capped too (#263): a compromised owner session must not
    -- flood the merchant audit trail either.
    IF (SELECT count(*) FROM public.merchant_staff_events e
         WHERE e.actor_id = v_caller AND e.kind = 'refused'
           AND e.created_at > now() - interval '1 day') < 100 THEN
      INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, detail, actor_id)
      VALUES (NULL, p_merchant_id, 'refused', jsonb_build_object('action', v_reason), v_caller);
    END IF;
  ELSE
    IF (SELECT count(*) FROM public.staff_admin_refusals r
         WHERE r.caller_id = v_caller AND r.created_at > now() - interval '1 day') < 100 THEN
      INSERT INTO public.staff_admin_refusals (caller_id, merchant_id, action)
      VALUES (v_caller, p_merchant_id, v_reason);
    END IF;
  END IF;
END;
$function$;

-- S7: an ACTIVE staff member clears their OWN password-change barrier after
-- changing the password through GoTrue (client-side session flow).
CREATE FUNCTION public.staff_password_changed()
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
  IF NOT public.feature_enabled('staff_accounts') THEN
    RAISE EXCEPTION 'feature disabled';
  END IF;
  IF NOT public._lookup_rate_allow('staffadm:pwdchg:' || v_caller, 30) THEN
    RAISE EXCEPTION 'rate limited';
  END IF;
  SELECT * INTO v_staff FROM public.merchant_staff
   WHERE user_id = v_caller AND is_active
   ORDER BY created_at LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff not found';
  END IF;
  -- Proof of change (security blocking 1 / #266): the live GoTrue password
  -- digest must differ from the digest staff_admin_mark_password_rotated
  -- stored after the last creation/reset. Fail closed when none is stored:
  -- without a baseline, no clear is possible until the next reset.
  IF v_staff.password_digest IS NULL
     OR (SELECT md5(u.encrypted_password) FROM auth.users u WHERE u.id = v_caller)
        IS NOT DISTINCT FROM v_staff.password_digest THEN
    RAISE EXCEPTION 'password change not verified';
  END IF;
  UPDATE public.merchant_staff
     SET must_change_password = false, updated_at = now()
   WHERE id = v_staff.id;
  INSERT INTO public.merchant_staff_events (staff_id, merchant_id, kind, actor_id)
  VALUES (v_staff.id, v_staff.merchant_id, 'password_changed', v_caller);
END;
$function$;

REVOKE ALL ON FUNCTION public.staff_admin_provision_begin(uuid, text, text, text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_provision_begin(uuid, text, text, text, uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_provision_complete(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_provision_complete(uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_provision_abort(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_provision_abort(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_set_active(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_set_active(uuid, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_record_password_reset(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_record_password_reset(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_audit_refusal(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_audit_refusal(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_sync_complete(uuid, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_sync_complete(uuid, text, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.staff_admin_mark_password_rotated(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_admin_mark_password_rotated(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.staff_password_changed() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_password_changed() FROM anon;
GRANT EXECUTE ON FUNCTION public.staff_admin_provision_begin(uuid, text, text, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_provision_complete(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_provision_abort(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_set_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_record_password_reset(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_audit_refusal(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_sync_complete(uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_admin_mark_password_rotated(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_password_changed() TO authenticated;

COMMIT;
