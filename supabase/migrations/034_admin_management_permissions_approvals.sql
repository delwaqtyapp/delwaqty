-- ============================================================
-- 034_admin_management_permissions_approvals.sql
-- Phase 2.3 — Admin delegation + permissions + approvals (2.3B / D1/D2/D7,
-- docs/HANDOFF/PHASE_2_3_DECISION_LOCK_REPORT.md §034, §5/§6 of the master
-- member-management/support audit).
--
-- Scope (locked design):
--   1. admin_management      — supervision tree (owner = implicit root, no row).
--   2. admin_permission_grants — explicit permission deviations (no RBAC engine).
--   3. has_permission()      — the ONE central decision engine (7-input tuple),
--                              used by every sensitive RPC/RLS policy.
--   4. is_supervisor_of()    — recursive supervision-chain walk.
--   5. is_admin() hardening  — role='admin' now requires an ACTIVE
--                              admin_management row (owner exempt). A deactivated
--                              admin loses all authority immediately. Defense-in-
--                              depth on top of the legacy literal role checks.
--   6. Admin lifecycle RPCs  — create_admin_account / assign_admin_role /
--                              assign_admin_region / change_admin_supervisor /
--                              deactivate_admin. Invariants enforced inside the
--                              internal executors (M1): no cycles, region
--                              containment, owner-only root creation, supervisor
--                              placement within branch.
--   7. grant/revoke_admin_permission — D2 invariants: grantor must possess the
--                              permission (or be owner); no self-grant;
--                              EMERGENCY_AUDIO / MEMBER_DELETE are grant-only.
--   8. Approval Center       — submit_approval_request (new) + decide_approval_request
--                              (EXTENDED; approval_requests table itself is owned by
--                              040 — NOT recreated here). campaign_approve dispatch
--                              preserved verbatim; admin_* types execute via the same
--                              executors the lifecycle RPCs use (single code path).
--   9. explain_admin_access  — internal "why can I see this?" debug helper (§7.2).
--
-- Security (030/031/033 lessons): REVOKE-before-GRANT on the new tables; all new
-- RPCs SECURITY DEFINER + SET search_path = public, pg_temp; anon gets nothing;
-- internal helpers grant EXECUTE to service_role only (write_audit precedent).
-- New tables are NOT added to supabase_realtime. No admin seeds.
--
-- Idempotent: IF NOT EXISTS / CREATE OR REPLACE everywhere; safe to re-run.
-- ============================================================

BEGIN;

-- ─── 1. INTERNAL IDENTITY HELPERS (param-based; no auth.uid() dependency) ──
-- Executors and decide_approval_request act on an explicit actor, so authority
-- must be derived from the actor argument, never from auth.uid().

CREATE OR REPLACE FUNCTION public._is_owner_uid(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_uid AND role = 'owner'
  );
$$;

CREATE OR REPLACE FUNCTION public._is_active_admin_uid(p_uid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_uid
      AND (
        u.role = 'owner'
        OR (
          u.role = 'admin'
          AND EXISTS (
            SELECT 1 FROM public.admin_management m
            WHERE m.admin_id = u.id AND m.is_active
          )
        )
      )
  );
END;
$$;

-- Whether p_region_id lies inside p_uid's reachable scope (owner = all;
-- admin with NO region assignments = global = all; otherwise admin_region_assignments
-- must cover the region, self/descendants).
CREATE OR REPLACE FUNCTION public._region_in_scope(p_uid uuid, p_region_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_uid AND u.role = 'owner') THEN
    RETURN true;
  END IF;
  IF p_uid IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_uid AND u.role = 'admin')
     AND NOT EXISTS (
       SELECT 1 FROM public.admin_region_assignments
       WHERE admin_id = p_uid
     ) THEN
    RETURN true;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.admin_region_assignments a
    WHERE a.admin_id = p_uid
      AND (
        (a.scope = 'self' AND a.region_id = p_region_id)
        OR (a.scope = 'descendants' AND p_region_id IN (
          WITH RECURSIVE covered AS (
            SELECT id FROM public.regions WHERE id = a.region_id
            UNION ALL
            SELECT r.id FROM public.regions r
            JOIN covered c ON r.parent_region_id = c.id
          )
          SELECT id FROM covered
        ))
      )
  );
END;
$$;

-- ─── 2. is_admin() HARDENING ────────────────────────────────────────────
-- role='admin' alone is no longer sufficient: an active admin_management row
-- is required (owner is implicit root and exempt). Deactivate_admin flips
-- is_active=false AND demotes the role for defense-in-depth, so the legacy
-- literal `role = 'admin'` checks (026/027/002) stay aligned as well.
-- is_admin_for_region is re-expressed on the same primitives (DRY).

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._is_active_admin_uid(auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.is_admin_for_region(p_region_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._is_active_admin_uid(auth.uid())
     AND public._region_in_scope(auth.uid(), p_region_id);
$$;

-- ─── 3. admin_management (supervision tree) ────────────────────────────

CREATE TABLE IF NOT EXISTS public.admin_management (
  admin_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  supervisor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  is_active     boolean NOT NULL DEFAULT true,
  created_by    uuid REFERENCES public.users(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (admin_id),
  CONSTRAINT admin_management_no_self CHECK (admin_id <> supervisor_id)
);

COMMENT ON TABLE public.admin_management IS
  'Supervision tree (Phase 2.3 D1). owner = implicit root, no row. '
  'Depth is derived via recursive CTE, never stored. Invariants (no cycles, '
  'region containment, owner-only root creation, supervisor-possession) are '
  'enforced inside the lifecycle executors, not by triggers.';

ALTER TABLE public.admin_management ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_management admin all" ON public.admin_management;
CREATE POLICY "admin_management admin all" ON public.admin_management
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_admin_management_supervisor
  ON public.admin_management (supervisor_id);

REVOKE ALL ON public.admin_management FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_management TO authenticated;

-- ─── 4. admin_permission_grants (explicit deviations) ──────────────────

CREATE TABLE IF NOT EXISTS public.admin_permission_grants (
  admin_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  permission text NOT NULL,
  granted_by uuid REFERENCES public.users(id),
  granted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (admin_id, permission)
);

COMMENT ON TABLE public.admin_permission_grants IS
  'Explicit permission grants (Phase 2.3 D2). Defaults are computed from '
  '(role, admin, region scope) inside has_permission(); this table stores only '
  'deviations (including grant-only permissions). Grantor must possess the '
  'permission (or be owner); no self-grant.';

ALTER TABLE public.admin_permission_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_permission_grants admin all"
  ON public.admin_permission_grants;
CREATE POLICY "admin_permission_grants admin all"
  ON public.admin_permission_grants
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_admin_permission_grants_admin
  ON public.admin_permission_grants (admin_id);

REVOKE ALL ON public.admin_permission_grants FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_permission_grants TO authenticated;

-- ─── 5. PERMISSION CONSTANTS + SUPERVISION WALK ────────────────────────

-- Permission vocabulary (single source of truth). Default in-scope set vs
-- grant-only set is applied in has_permission() below.
CREATE OR REPLACE FUNCTION public._valid_permission(p_permission text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_permission IN (
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE','MEMBER_VIEW_DOCUMENTS',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'MEMBER_BAN','MEMBER_DELETE',
    'EMERGENCY_VIEW','EMERGENCY_AUDIO',
    'OFFER_CREATE','OFFER_REVIEW','OFFER_APPROVE','OFFER_PUBLISH'
  );
$$;

-- Approval request_type vocabulary (kept additive so 035/037 can submit their
-- types without another migration).
CREATE OR REPLACE FUNCTION public._valid_approval_type(p_type text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_type IN (
    'admin_create','admin_role_change','admin_region_change',
    'admin_supervisor_change','admin_deactivate',
    'campaign_approve','member_ban','member_delete',
    'offer_approve','offer_publish'
  );
$$;

-- True when p_supervisor supervises p_subordinate through the tree (or is the
-- owner, the implicit root). Excludes the trivial self case.
CREATE OR REPLACE FUNCTION public.is_supervisor_of(p_supervisor uuid, p_subordinate uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._is_owner_uid(p_supervisor)
    OR EXISTS (
      WITH RECURSIVE chain AS (
        SELECT m.admin_id, m.supervisor_id
        FROM public.admin_management m
        WHERE m.admin_id = p_subordinate AND m.is_active
        UNION ALL
        SELECT m.admin_id, m.supervisor_id
        FROM public.admin_management m
        JOIN chain c ON m.admin_id = c.supervisor_id AND m.is_active
      )
      SELECT 1 FROM chain WHERE chain.supervisor_id = p_supervisor LIMIT 1
    );
$$;

-- ─── 6. has_permission — CENTRAL DECISION ENGINE ───────────────────────
-- Evaluates the 7-input tuple: actor identity + actor role + supervisor
-- relationship + delegated permission + actor geographic scope + target +
-- target region + requested action. Single evaluator across RPCs AND policies
-- (no drift, R2). Defaults per §6 of the master audit.

CREATE OR REPLACE FUNCTION public.has_permission(
  p_permission text,
  p_region_id uuid DEFAULT NULL,
  p_target_admin_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_granted boolean;
  v_default_in_scope boolean;
BEGIN
  IF v_actor IS NULL OR p_permission IS NULL OR btrim(p_permission) = '' THEN
    RETURN false;
  END IF;
  IF NOT public._valid_permission(p_permission) THEN
    RETURN false;
  END IF;
  -- owner: global authority on every permission
  IF public._is_owner_uid(v_actor) THEN
    RETURN true;
  END IF;
  IF NOT public._is_active_admin_uid(v_actor) THEN
    RETURN false;
  END IF;
  -- geographic scope gate (when the action is region-bound)
  IF p_region_id IS NOT NULL AND NOT public._region_in_scope(v_actor, p_region_id) THEN
    RETURN false;
  END IF;
  -- target-admin gate (ADMIN_* actions are always supervisor-scoped)
  IF p_target_admin_id IS NOT NULL
     AND NOT public.is_supervisor_of(v_actor, p_target_admin_id) THEN
    RETURN false;
  END IF;
  -- explicit grant overrides the default only within the vocabulary
  SELECT EXISTS (
    SELECT 1 FROM public.admin_permission_grants g
    WHERE g.admin_id = v_actor AND g.permission = p_permission
  ) INTO v_granted;
  IF v_granted THEN
    RETURN true;
  END IF;
  -- default in-scope matrix (§6); OFFER_PUBLISH is owner-only (handled above),
  -- everything not in this set (MEMBER_VIEW_DOCUMENTS / MEMBER_BAN /
  -- MEMBER_DELETE / EMERGENCY_AUDIO / OFFER_APPROVE) is grant-only.
  SELECT p_permission IN (
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'EMERGENCY_VIEW','OFFER_CREATE','OFFER_REVIEW'
  ) INTO v_default_in_scope;
  RETURN v_default_in_scope;
END;
$$;

-- ─── 7. INTERNAL LIFECYCLE EXECUTORS (single code path) ────────────────
-- Used by BOTH the public lifecycle RPCs (actor = caller) and the Approval
-- Center decisions (actor = decider). Every invariant from M1 lives here.

-- Create an admin link for an existing user.
CREATE OR REPLACE FUNCTION public._admin_exec_create(
  p_actor uuid,
  p_user_id uuid,
  p_supervisor_id uuid DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_supervisor uuid;
  v_role text;
BEGIN
  IF NOT (public._is_owner_uid(p_actor) OR public._is_active_admin_uid(p_actor)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT role INTO v_role FROM public.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  IF v_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot manage the owner';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_user_id) THEN
    RAISE EXCEPTION 'User is already an admin';
  END IF;
  -- (c) only owner creates admin at root level
  IF p_supervisor_id IS NULL AND NOT public._is_owner_uid(p_actor) THEN
    RAISE EXCEPTION 'Only the owner creates admins at root level';
  END IF;
  v_supervisor := COALESCE(p_supervisor_id, p_actor);
  IF v_supervisor = p_user_id THEN
    RAISE EXCEPTION 'Cannot supervise yourself';
  END IF;
  IF NOT (public._is_owner_uid(v_supervisor) OR public._is_active_admin_uid(v_supervisor)) THEN
    RAISE EXCEPTION 'Invalid supervisor';
  END IF;
  -- placement must stay inside the actor's branch
  IF NOT public._is_owner_uid(p_actor)
     AND v_supervisor <> p_actor
     AND NOT public.is_supervisor_of(p_actor, v_supervisor) THEN
    RAISE EXCEPTION 'Supervisor outside your branch';
  END IF;
  -- (b) region containment
  IF p_region_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.regions WHERE id = p_region_id) THEN
      RAISE EXCEPTION 'Region not found';
    END IF;
    IF NOT public._is_owner_uid(p_actor)
       AND NOT public._region_in_scope(p_actor, p_region_id) THEN
      RAISE EXCEPTION 'Region outside your scope';
    END IF;
  END IF;

  INSERT INTO public.admin_management (admin_id, supervisor_id, is_active, created_by)
  VALUES (p_user_id, v_supervisor, true, p_actor);

  UPDATE public.users SET role = 'admin' WHERE id = p_user_id;

  IF p_region_id IS NOT NULL THEN
    INSERT INTO public.admin_region_assignments (admin_id, region_id, scope, created_by)
    VALUES (p_user_id, p_region_id, p_scope, p_actor)
    ON CONFLICT (admin_id, region_id)
    DO UPDATE SET scope = EXCLUDED.scope, created_by = EXCLUDED.created_by;
  END IF;

  PERFORM public.write_audit(
    'ADMIN_CREATED', 'admin_management', p_user_id::text,
    jsonb_build_object('actor', p_actor::text, 'supervisor', v_supervisor::text,
                       'region_id', p_region_id, 'scope', p_scope));

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_user_id,
    'Admin account created',
    'You now have admin access. Your supervisor is ' || v_supervisor::text || '.',
    'admin_management',
    jsonb_build_object('admin_id', p_user_id::text, 'supervisor_id', v_supervisor::text),
    '/admin/branches',
    'admin-create-' || p_user_id::text || '-' || gen_random_uuid()::text
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
END;
$$;

-- Change an admin's role ('admin' | 'owner' | demote to any non-admin role).
CREATE OR REPLACE FUNCTION public._admin_exec_role(
  p_actor uuid,
  p_admin_id uuid,
  p_new_role text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_in_tree boolean;
  v_target_role text;
BEGIN
  IF p_admin_id = p_actor THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;
  IF NOT (public._is_owner_uid(p_actor) OR public.is_supervisor_of(p_actor, p_admin_id)) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;
  IF p_new_role NOT IN ('customer','merchant','driver','admin','owner','provider','delivery') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  IF p_new_role = 'owner' AND NOT public._is_owner_uid(p_actor) THEN
    RAISE EXCEPTION 'Only the owner can grant the owner role';
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_admin_id)
    INTO v_in_tree;
  IF p_new_role = 'admin' AND NOT v_in_tree THEN
    RAISE EXCEPTION 'Use create_admin_account to create admins';
  END IF;
  -- role='admin' must stay aligned with an ACTIVE tree row (a deactivated admin
  -- cannot be silently re-armed without a proper reactivation flow)
  IF p_new_role = 'admin'
     AND NOT EXISTS (
       SELECT 1 FROM public.admin_management
       WHERE admin_id = p_admin_id AND is_active
     ) THEN
    RAISE EXCEPTION 'Admin is deactivated';
  END IF;
  SELECT role INTO v_target_role FROM public.users WHERE id = p_admin_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  IF v_target_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot change the owner role';
  END IF;

  UPDATE public.users SET role = p_new_role WHERE id = p_admin_id;

  -- role and tree stay in sync: promoting to owner or demoting to a non-admin
  -- role removes the tree row (owner is implicit root; demoted admins lose all
  -- admin authority).
  IF p_new_role <> 'admin' THEN
    DELETE FROM public.admin_management WHERE admin_id = p_admin_id;
  END IF;

  PERFORM public.write_audit(
    'ADMIN_ROLE_CHANGED', 'admin_management', p_admin_id::text,
    jsonb_build_object('actor', p_actor::text, 'new_role', p_new_role,
                       'reason', p_reason));
END;
$$;

-- Assign/upsert a region scope on an admin.
CREATE OR REPLACE FUNCTION public._admin_exec_region(
  p_actor uuid,
  p_admin_id uuid,
  p_region_id uuid,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_admin_id = p_actor THEN
    RAISE EXCEPTION 'Cannot change your own scope';
  END IF;
  IF NOT (public._is_owner_uid(p_actor) OR public.is_supervisor_of(p_actor, p_admin_id)) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;
  IF p_scope NOT IN ('self','descendants') THEN
    RAISE EXCEPTION 'Invalid scope';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.regions WHERE id = p_region_id) THEN
    RAISE EXCEPTION 'Region not found';
  END IF;
  -- (b) region containment: the assigning actor must hold the region in scope
  IF NOT public._is_owner_uid(p_actor)
     AND NOT public._region_in_scope(p_actor, p_region_id) THEN
    RAISE EXCEPTION 'Region outside your scope';
  END IF;

  INSERT INTO public.admin_region_assignments (admin_id, region_id, scope, created_by)
  VALUES (p_admin_id, p_region_id, p_scope, p_actor)
  ON CONFLICT (admin_id, region_id)
  DO UPDATE SET scope = EXCLUDED.scope, created_by = EXCLUDED.created_by;

  PERFORM public.write_audit(
    'ADMIN_REGION_CHANGED', 'admin_region_assignments', p_admin_id::text,
    jsonb_build_object('actor', p_actor::text, 'region_id', p_region_id,
                       'scope', p_scope));
END;
$$;

-- Move an admin under a new supervisor (no cycles, containment).
CREATE OR REPLACE FUNCTION public._admin_exec_supervisor(
  p_actor uuid,
  p_admin_id uuid,
  p_new_supervisor_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_region_id uuid;
BEGIN
  IF p_admin_id = p_actor THEN
    RAISE EXCEPTION 'Cannot change your own supervisor';
  END IF;
  IF NOT (public._is_owner_uid(p_actor) OR public.is_supervisor_of(p_actor, p_admin_id)) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_admin_id AND is_active) THEN
    RAISE EXCEPTION 'Not an active admin';
  END IF;
  IF p_new_supervisor_id = p_admin_id THEN
    RAISE EXCEPTION 'Cannot be your own supervisor';
  END IF;
  IF NOT (public._is_owner_uid(p_new_supervisor_id) OR public._is_active_admin_uid(p_new_supervisor_id)) THEN
    RAISE EXCEPTION 'Invalid supervisor';
  END IF;
  -- new supervisor must be inside the actor's branch (unless actor is owner)
  IF NOT public._is_owner_uid(p_actor)
     AND p_new_supervisor_id <> p_actor
     AND NOT public.is_supervisor_of(p_actor, p_new_supervisor_id) THEN
    RAISE EXCEPTION 'New supervisor outside your branch';
  END IF;
  -- (a) no cycles: the new supervisor may not already be a subordinate of the
  -- moved admin (would make the subtree loop back onto itself)
  IF public.is_supervisor_of(p_admin_id, p_new_supervisor_id) THEN
    RAISE EXCEPTION 'Cannot create a supervision cycle';
  END IF;
  -- (b) the new supervisor's reachable scope must cover the admin's regions
  FOR v_region_id IN
    SELECT region_id FROM public.admin_region_assignments WHERE admin_id = p_admin_id
  LOOP
    IF NOT public._is_owner_uid(p_new_supervisor_id)
       AND NOT public._region_in_scope(p_new_supervisor_id, v_region_id) THEN
      RAISE EXCEPTION 'New supervisor scope does not cover target regions';
    END IF;
  END LOOP;

  UPDATE public.admin_management
    SET supervisor_id = p_new_supervisor_id, updated_at = now()
    WHERE admin_id = p_admin_id;

  PERFORM public.write_audit(
    'ADMIN_SUPERVISOR_CHANGED', 'admin_management', p_admin_id::text,
    jsonb_build_object('actor', p_actor::text, 'new_supervisor_id',
                       p_new_supervisor_id::text, 'reason', p_reason));
END;
$$;

-- Deactivate an admin (revokes authority immediately + role demotion).
CREATE OR REPLACE FUNCTION public._admin_exec_deactivate(
  p_actor uuid,
  p_admin_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_target_role text;
BEGIN
  IF p_admin_id = p_actor THEN
    RAISE EXCEPTION 'Cannot deactivate yourself';
  END IF;
  IF NOT (public._is_owner_uid(p_actor) OR public.is_supervisor_of(p_actor, p_admin_id)) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_admin_id AND is_active) THEN
    RAISE EXCEPTION 'Not an active admin';
  END IF;
  SELECT role INTO v_target_role FROM public.users WHERE id = p_admin_id;
  IF v_target_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot deactivate the owner';
  END IF;

  UPDATE public.admin_management
    SET is_active = false, updated_at = now()
    WHERE admin_id = p_admin_id;

  -- defense-in-depth: demote so literal `role = 'admin'` checks also fail
  UPDATE public.users SET role = 'customer' WHERE id = p_admin_id;

  PERFORM public.write_audit(
    'ADMIN_DEACTIVATED', 'admin_management', p_admin_id::text,
    jsonb_build_object('actor', p_actor::text, 'reason', p_reason));

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    p_admin_id,
    'Admin access removed',
    COALESCE(p_reason, 'Your admin access has been removed.'),
    'admin_management',
    jsonb_build_object('admin_id', p_admin_id::text),
    '/admin/branches',
    'admin-deactivate-' || p_admin_id::text || '-' || gen_random_uuid()::text
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
END;
$$;

-- ─── 8. PUBLIC LIFECYCLE RPCS ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_admin_account(
  p_user_id uuid,
  p_supervisor_id uuid DEFAULT NULL,
  p_region_id uuid DEFAULT NULL,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_create(
    auth.uid(), p_user_id, p_supervisor_id, p_region_id, p_scope
  );
$$;

CREATE OR REPLACE FUNCTION public.assign_admin_role(
  p_admin_id uuid,
  p_new_role text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_role(auth.uid(), p_admin_id, p_new_role, p_reason);
$$;

CREATE OR REPLACE FUNCTION public.assign_admin_region(
  p_admin_id uuid,
  p_region_id uuid,
  p_scope text DEFAULT 'descendants'
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_region(auth.uid(), p_admin_id, p_region_id, p_scope);
$$;

CREATE OR REPLACE FUNCTION public.change_admin_supervisor(
  p_admin_id uuid,
  p_new_supervisor_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_supervisor(auth.uid(), p_admin_id, p_new_supervisor_id, p_reason);
$$;

CREATE OR REPLACE FUNCTION public.deactivate_admin(
  p_admin_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_deactivate(auth.uid(), p_admin_id, p_reason);
$$;

-- ─── 9. PERMISSION GRANTS (D2 invariants) ──────────────────────────────

CREATE OR REPLACE FUNCTION public.grant_admin_permission(
  p_admin_id uuid,
  p_permission text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_active_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT public._valid_permission(p_permission) THEN
    RAISE EXCEPTION 'Unknown permission';
  END IF;
  IF p_admin_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot grant a permission to yourself';
  END IF;
  -- grantor must possess the permission (or be owner); target must be an admin
  -- under the grantor's branch
  IF NOT public._is_owner_uid(auth.uid()) THEN
    IF NOT public.has_permission(p_permission) THEN
      RAISE EXCEPTION 'You do not hold this permission';
    END IF;
    IF NOT public.is_supervisor_of(auth.uid(), p_admin_id) THEN
      RAISE EXCEPTION 'Not authorized for this admin';
    END IF;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_management m
    JOIN public.users u ON u.id = m.admin_id
    WHERE m.admin_id = p_admin_id AND m.is_active AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not an active admin';
  END IF;

  INSERT INTO public.admin_permission_grants (admin_id, permission, granted_by)
  VALUES (p_admin_id, p_permission, auth.uid())
  ON CONFLICT (admin_id, permission) DO NOTHING;

  PERFORM public.write_audit(
    'ADMIN_PERMISSION_GRANTED', 'admin_permission_grants', p_admin_id::text,
    jsonb_build_object('permission', p_permission));
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_admin_permission(
  p_admin_id uuid,
  p_permission text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public._is_active_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_admin_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot revoke a permission from yourself';
  END IF;
  IF NOT public._is_owner_uid(auth.uid())
     AND NOT public.is_supervisor_of(auth.uid(), p_admin_id) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;

  DELETE FROM public.admin_permission_grants
  WHERE admin_id = p_admin_id AND permission = p_permission;

  PERFORM public.write_audit(
    'ADMIN_PERMISSION_REVOKED', 'admin_permission_grants', p_admin_id::text,
    jsonb_build_object('permission', p_permission));
END;
$$;

-- ─── 10. HARDEN admin_set_user_role (031) ──────────────────────────────
-- Close the 031 gap: any is_admin() could previously promote/demote any user.
-- Now admin/owner assignment requires supervision (or owner), and role='admin'
-- requires an existing active tree row (creation path is create_admin_account).

CREATE OR REPLACE FUNCTION public.admin_set_user_role(p_user_id uuid, p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;
  IF p_role NOT IN ('customer','merchant','driver','admin','owner','provider','delivery') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  IF p_role = 'owner' AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Only the owner can grant the owner role';
  END IF;
  IF p_role = 'admin'
     AND NOT EXISTS (
       SELECT 1 FROM public.admin_management
       WHERE admin_id = p_user_id AND is_active
     ) THEN
    RAISE EXCEPTION 'Use create_admin_account to create admins';
  END IF;
  -- managing an admin (or demoting one) requires supervision unless owner
  IF NOT public._is_owner_uid(auth.uid())
     AND (EXISTS (SELECT 1 FROM public.admin_management WHERE admin_id = p_user_id)
          OR p_role IN ('admin','owner'))
     AND NOT public.is_supervisor_of(auth.uid(), p_user_id) THEN
    RAISE EXCEPTION 'Not authorized for this user';
  END IF;

  PERFORM public._admin_exec_role(auth.uid(), p_user_id, p_role, NULL);
END;
$$;

-- ─── 11. APPROVAL CENTER ───────────────────────────────────────────────

-- Submit a pending approval request (admin-only). required_approver NULL = owner.
CREATE OR REPLACE FUNCTION public.submit_approval_request(
  p_request_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_payload jsonb DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_required_approver uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT public._valid_approval_type(p_request_type) THEN
    RAISE EXCEPTION 'Unknown request type';
  END IF;
  IF p_required_approver IS NOT NULL
     AND NOT (public._is_owner_uid(p_required_approver)
              OR (public._is_active_admin_uid(p_required_approver)
                  AND public.is_supervisor_of(p_required_approver, auth.uid()))) THEN
    RAISE EXCEPTION 'Invalid required approver';
  END IF;

  BEGIN
    INSERT INTO public.approval_requests
      (request_type, entity_type, entity_id, payload, requested_by,
       required_approver, state, reason)
    VALUES (
      p_request_type, p_entity_type, p_entity_id,
      COALESCE(p_payload, '{}'::jsonb),
      auth.uid(), p_required_approver, 'pending', p_reason
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'A pending request for this entity already exists';
  END;

  PERFORM public.write_audit(
    'APPROVAL_REQUESTED', 'approval_requests', v_id::text,
    jsonb_build_object('request_type', p_request_type,
                       'entity_type', p_entity_type,
                       'entity_id', p_entity_id,
                       'required_approver', p_required_approver));

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    COALESCE(p_required_approver, (SELECT id FROM public.users WHERE role = 'owner' LIMIT 1)),
    'New approval request',
    p_request_type || ' for ' || COALESCE(p_entity_type, '?'),
    'approval',
    jsonb_build_object('request_id', v_id::text, 'request_type', p_request_type),
    '/admin/approvals',
    'approval-request-' || v_id::text
  );

  RETURN v_id;
END;
$$;

-- Internal dispatcher: applies an approved request. Single path shared with the
-- lifecycle RPCs; the DECIDER is the acting authority here.
CREATE OR REPLACE FUNCTION public._approval_apply(
  p_request public.approval_requests,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payload jsonb;
  v_campaign public.campaigns%ROWTYPE;
BEGIN
  v_payload := COALESCE(p_request.payload, '{}'::jsonb);

  CASE p_request.request_type
    WHEN 'campaign_approve' THEN
      SELECT * INTO v_campaign FROM public.campaigns c WHERE c.id = p_request.entity_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Campaign not found';
      END IF;
      IF v_campaign.status <> 'pending_review' THEN
        RAISE EXCEPTION 'Campaign is not pending review';
      END IF;
      IF NOT public.campaign_targets_authorized(v_campaign.id) THEN
        RAISE EXCEPTION 'Not authorized for this campaign region scope';
      END IF;
      UPDATE public.campaigns SET status = 'approved' WHERE id = v_campaign.id;
      INSERT INTO public.campaign_reviews
        (campaign_id, reviewer_id, action, previous_state, new_state, reason)
      VALUES (v_campaign.id, auth.uid(), 'approve', 'pending_review', 'approved', p_reason);

    WHEN 'admin_create' THEN
      PERFORM public._admin_exec_create(
        auth.uid(),
        (v_payload->>'user_id')::uuid,
        NULLIF(v_payload->>'supervisor_id', '')::uuid,
        NULLIF(v_payload->>'region_id', '')::uuid,
        COALESCE(v_payload->>'scope', 'descendants'));

    WHEN 'admin_role_change' THEN
      PERFORM public._admin_exec_role(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        v_payload->>'new_role',
        COALESCE(p_reason, v_payload->>'reason'));

    WHEN 'admin_region_change' THEN
      PERFORM public._admin_exec_region(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        (v_payload->>'region_id')::uuid,
        COALESCE(v_payload->>'scope', 'descendants'));

    WHEN 'admin_supervisor_change' THEN
      PERFORM public._admin_exec_supervisor(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        (v_payload->>'new_supervisor_id')::uuid,
        COALESCE(p_reason, v_payload->>'reason'));

    WHEN 'admin_deactivate' THEN
      PERFORM public._admin_exec_deactivate(
        auth.uid(),
        (v_payload->>'admin_id')::uuid,
        COALESCE(p_reason, v_payload->>'reason'));

    ELSE
      RAISE EXCEPTION 'Unsupported request type';
  END CASE;
END;
$$;

-- EXTENDED decide_approval_request (040 owned approval_requests; this dispatch
-- preserves the campaign_approve flow verbatim and adds the admin_* types).
CREATE OR REPLACE FUNCTION public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.approval_requests%ROWTYPE;
  v_is_owner boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_decision NOT IN ('approve','reject') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;
  SELECT * INTO v_request FROM public.approval_requests a WHERE a.id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approval request not found';
  END IF;
  IF v_request.state <> 'pending' THEN
    RAISE EXCEPTION 'Approval request already decided';
  END IF;
  IF v_request.request_type <> 'campaign_approve'
     AND NOT public._valid_approval_type(v_request.request_type) THEN
    RAISE EXCEPTION 'Unsupported request type';
  END IF;

  SELECT public._is_owner_uid(auth.uid()) INTO v_is_owner;

  -- a non-owner can never decide their own request (clear error before the
  -- decider-authority guard below)
  IF v_request.requested_by = auth.uid() AND NOT v_is_owner THEN
    RAISE EXCEPTION 'Cannot decide your own request';
  END IF;

  -- decider must be the required_approver or a superior of the requester.
  -- required_approver NULL = owner decides ONLY (write it with explicit
  -- IS NULL branches: the naive `required_approver = auth.uid()` is NULL under
  -- SQL 3-valued logic and silently skips the guard).
  IF NOT v_is_owner THEN
    IF v_request.required_approver IS NULL THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
    IF v_request.required_approver <> auth.uid()
       AND NOT public.is_supervisor_of(auth.uid(), v_request.requested_by) THEN
      RAISE EXCEPTION 'Not authorized to decide this request';
    END IF;
  END IF;

  IF p_decision = 'reject'
     AND (p_reason IS NULL OR btrim(p_reason) = '') THEN
    RAISE EXCEPTION 'Rejection requires a reason';
  END IF;

  IF p_decision = 'approve' THEN
    PERFORM public._approval_apply(v_request, p_reason);
    UPDATE public.approval_requests
      SET state = 'approved', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  ELSE
    UPDATE public.approval_requests
      SET state = 'rejected', reason = p_reason,
          decided_by = auth.uid(), decided_at = now()
      WHERE id = p_request_id;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data, deep_link, idempotency_key)
  VALUES (
    v_request.requested_by,
    CASE WHEN p_decision = 'approve' THEN 'Approval granted' ELSE 'Approval rejected' END,
    v_request.request_type || ' — ' || COALESCE(p_reason, ''),
    'approval',
    jsonb_build_object('request_id', p_request_id::text,
                       'decision', p_decision,
                       'request_type', v_request.request_type),
    '/admin/approvals',
    'approval-decide-' || p_request_id::text
  );

  PERFORM public.write_audit(
    'APPROVAL_DECIDED', 'approval_requests', p_request_id::text,
    jsonb_build_object('decision', p_decision,
                       'request_type', v_request.request_type,
                       'reason', p_reason));
END;
$$;

-- ─── 12. explain_admin_access (internal debug helper, §7.2) ────────────

CREATE OR REPLACE FUNCTION public.explain_admin_access(
  p_member_id uuid,
  p_region_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_reasons jsonb := '[]'::jsonb;
  v_access boolean := false;
  v_actor_role text;
  v_member_exists boolean;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('access', false, 'reasons', '[]'::jsonb);
  END IF;

  SELECT role INTO v_actor_role FROM public.users WHERE id = v_actor;
  SELECT EXISTS (SELECT 1 FROM public.users WHERE id = p_member_id) INTO v_member_exists;
  IF NOT v_member_exists THEN
    RETURN jsonb_build_object('access', false, 'reasons',
      jsonb_build_array(jsonb_build_object('dimension', 'member', 'detail', 'not-found')));
  END IF;

  IF v_actor_role = 'owner' THEN
    v_access := true;
    v_reasons := v_reasons || jsonb_build_object('dimension', 'role', 'detail', 'owner');
  ELSIF public._is_active_admin_uid(v_actor) THEN
    v_reasons := v_reasons || jsonb_build_object('dimension', 'role', 'detail', 'admin');
    -- region scope
    IF p_region_id IS NULL THEN
      v_reasons := v_reasons || jsonb_build_object('dimension', 'region_scope', 'detail', 'no region supplied');
      v_access := true;
    ELSIF public._region_in_scope(v_actor, p_region_id) THEN
      v_reasons := v_reasons || jsonb_build_object('dimension', 'region_scope', 'detail', 'region covered');
      v_access := true;
    ELSE
      v_reasons := v_reasons || jsonb_build_object('dimension', 'region_scope', 'detail', 'region not covered');
    END IF;
    -- permission dimension (MEMBER_VIEW = default in-scope)
    IF public.has_permission('MEMBER_VIEW', p_region_id) THEN
      v_reasons := v_reasons || jsonb_build_object('dimension', 'permission', 'detail', 'MEMBER_VIEW (default)');
    END IF;
    -- supervisor dimension: is the member an admin under this actor's branch?
    IF EXISTS (
      SELECT 1 FROM public.admin_management m
      WHERE m.admin_id = p_member_id AND public.is_supervisor_of(v_actor, p_member_id)
    ) THEN
      v_reasons := v_reasons || jsonb_build_object('dimension', 'supervisor', 'detail', 'within branch');
    END IF;
  ELSE
    v_reasons := v_reasons || jsonb_build_object('dimension', 'role', 'detail', 'not-admin');
  END IF;

  RETURN jsonb_build_object('access', v_access, 'reasons', v_reasons);
END;
$$;

-- ─── 13. ACL CLOSES ────────────────────────────────────────────────────
-- Public RPCs: authenticated only. Internal helpers: service_role only
-- (write_audit precedent, 033). anon revoked everywhere.

REVOKE ALL ON FUNCTION public._is_owner_uid(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._is_owner_uid(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._is_owner_uid(uuid) TO service_role;

REVOKE ALL ON FUNCTION public._is_active_admin_uid(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._is_active_admin_uid(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._is_active_admin_uid(uuid) TO service_role;

REVOKE ALL ON FUNCTION public._region_in_scope(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._region_in_scope(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public._region_in_scope(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public._valid_permission(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._valid_permission(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._valid_permission(text) TO service_role;

REVOKE ALL ON FUNCTION public._valid_approval_type(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._valid_approval_type(text) FROM anon;
GRANT EXECUTE ON FUNCTION public._valid_approval_type(text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_create(uuid, uuid, uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_create(uuid, uuid, uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_create(uuid, uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_role(uuid, uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_role(uuid, uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_role(uuid, uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_region(uuid, uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_region(uuid, uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_region(uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_supervisor(uuid, uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_supervisor(uuid, uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_supervisor(uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_deactivate(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_deactivate(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_deactivate(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._approval_apply(public.approval_requests, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._approval_apply(public.approval_requests, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._approval_apply(public.approval_requests, text) TO service_role;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;

REVOKE ALL ON FUNCTION public.is_admin_for_region(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_for_region(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_for_region(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.is_supervisor_of(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_supervisor_of(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_supervisor_of(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_supervisor_of(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.has_permission(text, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_permission(text, uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.has_permission(text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(text, uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.explain_admin_access(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.explain_admin_access(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.explain_admin_access(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.explain_admin_access(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.create_admin_account(uuid, uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_admin_account(uuid, uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_admin_account(uuid, uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_admin_account(uuid, uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.assign_admin_role(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_admin_role(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_admin_role(uuid, text, text) TO service_role;

REVOKE ALL ON FUNCTION public.assign_admin_region(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_admin_region(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_admin_region(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_admin_region(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.change_admin_supervisor(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.change_admin_supervisor(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.change_admin_supervisor(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_admin_supervisor(uuid, uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.deactivate_admin(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.deactivate_admin(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.deactivate_admin(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deactivate_admin(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.grant_admin_permission(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.grant_admin_permission(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.grant_admin_permission(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_admin_permission(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.revoke_admin_permission(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_admin_permission(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.revoke_admin_permission(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_admin_permission(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public.submit_approval_request(text, text, uuid, jsonb, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_approval_request(text, text, uuid, jsonb, text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_approval_request(text, text, uuid, jsonb, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_approval_request(text, text, uuid, jsonb, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.decide_approval_request(uuid, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_approval_request(uuid, text, text) TO service_role;

COMMIT;
