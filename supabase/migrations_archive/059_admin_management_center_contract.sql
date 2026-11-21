-- ════════════════════════════════════════════════════════════════════════
-- SPRINT 98 — Modern Admin Management Center: backend contract
-- ──────────────────────────────────────────────────────────────────────────
-- Goal: make the canonical modern Admin RPCs return enough identity + support
-- data for a real management UI, WITHOUT touching the legacy admin_users
-- table (which stays DORMANT / NOT a source of truth).
--
-- Changes (all additive / backward compatible):
--   A. get_all_admins()          — add id, full_name, region_id, scope,
--                                  supervisor_id (keeps existing keys)
--   B. get_admin_profile(p_email)— add id, full_name, is_active, region_id,
--                                  supervisor_id, supervisor_email,
--                                  permissions (keeps existing keys)
--   C. get_admin_permissions(p_admin_id) — explicit grants + effective set
--   D. get_admin_audit_history(p_admin_id) — scoped activity_logs history
--   E. reactivate_admin(p_admin_id, p_reason) — inverse of deactivate_admin
--
-- Authorization for all new RPCs:
--   owner  OR  the target admin themselves  OR  an authorized supervisor
--   (is_supervisor_of), plus region-scope containment where relevant.
-- ════════════════════════════════════════════════════════════════════════

-- ─── A. get_all_admins() — extended identity ──────────────────────────────

CREATE OR REPLACE FUNCTION public.get_all_admins()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', u.id,
           'email', u.email,
           'full_name', u.full_name,
           'role', u.role,
           'is_active', COALESCE(m.is_active, true),
           'region_id', r.region_id,
           'region_name', r.region_name,
           'scope', r.scope,
           'supervisor_id', m.supervisor_id,
           'supervisor_email', su.email,
           'created_at', u.created_at)
         ORDER BY u.created_at), '[]'::jsonb)
    INTO v_rows
    FROM public.users u
    LEFT JOIN public.admin_management m ON m.admin_id = u.id
    LEFT JOIN public.users su ON su.id = m.supervisor_id
    LEFT JOIN LATERAL (
      SELECT aa.region_id,
             rr.name_en AS region_name,
             aa.scope
        FROM public.admin_region_assignments aa
        LEFT JOIN public.regions rr ON rr.id = aa.region_id
       WHERE aa.admin_id = u.id
       ORDER BY aa.created_at DESC
       LIMIT 1
    ) r ON true
   WHERE u.role IN ('owner','admin')
      OR m.admin_id IS NOT NULL;

  RETURN v_rows;
END;
$$;

-- ─── B. get_admin_profile(p_email) — extended identity ────────────────────

CREATE OR REPLACE FUNCTION public.get_admin_profile(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_role text;
  v_region_name text;
  v_region_id uuid;
  v_scope text;
  v_supervisor_id uuid;
  v_supervisor_email text;
  v_earnings numeric := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  SELECT id, role INTO v_uid, v_role
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  IF v_uid <> auth.uid() AND NOT public._is_owner_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COALESCE(NULLIF(rr.name_en, ''), rr.name_ar), aa.region_id, aa.scope
    INTO v_region_name, v_region_id, v_scope
    FROM public.admin_region_assignments aa
    LEFT JOIN public.regions rr ON rr.id = aa.region_id
   WHERE aa.admin_id = v_uid
   ORDER BY aa.created_at DESC
   LIMIT 1;

  SELECT m.supervisor_id, su.email
    INTO v_supervisor_id, v_supervisor_email
    FROM public.admin_management m
    LEFT JOIN public.users su ON su.id = m.supervisor_id
   WHERE m.admin_id = v_uid
   LIMIT 1;

  IF to_regclass('public.platform_commissions') IS NOT NULL THEN
    SELECT COALESCE(SUM(commission_amount), 0)
      INTO v_earnings
      FROM public.platform_commissions
     WHERE member_id = v_uid AND status = 'fulfilled';
  END IF;

  RETURN jsonb_build_object(
    'id', v_uid,
    'email', p_email,
    'full_name', (SELECT full_name FROM public.users WHERE id = v_uid),
    'role', v_role,
    'is_owner', public._is_owner_uid(v_uid),
    'is_active', COALESCE((SELECT m.is_active FROM public.admin_management m WHERE m.admin_id = v_uid), true),
    'region_id', v_region_id,
    'region_name', v_region_name,
    'scope', v_scope,
    'supervisor_id', v_supervisor_id,
    'supervisor_email', v_supervisor_email,
    'total_earnings', v_earnings
  );
END;
$$;

-- ─── C. get_admin_permissions(p_admin_id) ────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_admin_permissions(p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_grants text[];
  v_default text[];
  v_effective text[];
  v_all text[] := ARRAY[
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE','MEMBER_VIEW_DOCUMENTS',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'MEMBER_BAN','MEMBER_DELETE',
    'EMERGENCY_VIEW','EMERGENCY_AUDIO',
    'OFFER_CREATE','OFFER_REVIEW','OFFER_APPROVE','OFFER_PUBLISH'
  ];
  v_default_set text[] := ARRAY[
    'ADMIN_CREATE','ADMIN_ASSIGN','ADMIN_ROLE_ASSIGN','ADMIN_REGION_ASSIGN',
    'ADMIN_SUPERVISOR_ASSIGN','ADMIN_SUSPEND',
    'MEMBER_VIEW','MEMBER_VIEW_LOCATION','MEMBER_VIEW_CHAT_HISTORY',
    'MEMBER_VIEW_COMPLAINTS','MEMBER_VIEW_TIMELINE',
    'MEMBER_MODERATE','MEMBER_WARN','MEMBER_RESTRICT','MEMBER_SUSPEND',
    'EMERGENCY_VIEW','OFFER_CREATE','OFFER_REVIEW'
  ];
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('authorized', false, 'grants', '[]'::jsonb, 'effective', '[]'::jsonb);
  END IF;
  IF NOT (public._is_owner_uid(v_actor)
          OR v_actor = p_admin_id
          OR public.is_supervisor_of(v_actor, p_admin_id)) THEN
    RETURN jsonb_build_object('authorized', false, 'grants', '[]'::jsonb, 'effective', '[]'::jsonb);
  END IF;

  SELECT COALESCE(array_agg(permission ORDER BY permission), ARRAY[]::text[])
    INTO v_grants
    FROM public.admin_permission_grants
   WHERE admin_id = p_admin_id;

  IF public._is_owner_uid(p_admin_id) THEN
    v_effective := v_all;
  ELSIF public._is_active_admin_uid(p_admin_id) THEN
    v_effective := v_default_set || v_grants;
  ELSE
    v_effective := v_grants;
  END IF;

  SELECT array_agg(DISTINCT x) INTO v_effective FROM unnest(v_effective) x;

  RETURN jsonb_build_object(
    'authorized', true,
    'grants', to_jsonb(v_grants),
    'effective', to_jsonb(v_effective)
  );
END;
$$;

-- ─── D. get_admin_audit_history(p_admin_id) ──────────────────────────────

CREATE OR REPLACE FUNCTION public.get_admin_audit_history(p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_rows jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;
  IF NOT (public._is_owner_uid(v_actor)
          OR v_actor = p_admin_id
          OR public.is_supervisor_of(v_actor, p_admin_id)) THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', id,
           'action', action,
           'resource', resource,
           'resource_id', resource_id,
           'details', details,
           'timestamp', timestamp)
         ORDER BY timestamp DESC), '[]'::jsonb)
    INTO v_rows
    FROM public.activity_logs
   WHERE user_id = p_admin_id::text
      OR (resource = 'admin_management' AND resource_id = p_admin_id::text)
      OR (resource = 'admin_permission_grants' AND resource_id = p_admin_id::text)
      OR (resource = 'admin_region_assignments' AND resource_id = p_admin_id::text);

  RETURN v_rows;
END;
$$;

-- ─── E. reactivate_admin(p_admin_id, p_reason) ───────────────────────────

CREATE OR REPLACE FUNCTION public._admin_exec_reactivate(
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
  v_row public.admin_management%ROWTYPE;
  v_role text;
  v_region_id uuid;
BEGIN
  IF p_admin_id = p_actor THEN
    RAISE EXCEPTION 'Cannot reactivate yourself';
  END IF;
  SELECT * INTO v_row FROM public.admin_management WHERE admin_id = p_admin_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not an admin';
  END IF;
  -- authorization: owner, the direct supervisor, or a supervisor of the supervisor
  IF NOT (public._is_owner_uid(p_actor)
          OR v_row.supervisor_id = p_actor
          OR public.is_supervisor_of(p_actor, v_row.supervisor_id)) THEN
    RAISE EXCEPTION 'Not authorized for this admin';
  END IF;
  SELECT role INTO v_role FROM public.users WHERE id = p_admin_id;
  IF v_role = 'owner' THEN
    RAISE EXCEPTION 'Cannot reactivate the owner';
  END IF;
  -- region containment
  FOR v_region_id IN
    SELECT region_id FROM public.admin_region_assignments WHERE admin_id = p_admin_id
  LOOP
    IF NOT public._is_owner_uid(p_actor)
       AND NOT public._region_in_scope(p_actor, v_region_id) THEN
      RAISE EXCEPTION 'Region outside your scope';
    END IF;
  END LOOP;
  -- idempotent
  IF v_row.is_active THEN
    RETURN;
  END IF;

  UPDATE public.admin_management
    SET is_active = true, updated_at = now()
    WHERE admin_id = p_admin_id;

  UPDATE public.users SET role = 'admin' WHERE id = p_admin_id AND role <> 'admin';

  PERFORM public.write_audit(
    'ADMIN_REACTIVATED', 'admin_management', p_admin_id::text,
    jsonb_build_object('actor', p_actor::text, 'reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION public.reactivate_admin(
  p_admin_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public._admin_exec_reactivate(auth.uid(), p_admin_id, p_reason);
$$;

-- ─── Grants ───────────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.get_all_admins() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_all_admins() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_all_admins() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_admins() TO service_role;

REVOKE ALL ON FUNCTION public.get_admin_profile(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_profile(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_admin_profile(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_profile(text) TO service_role;

REVOKE ALL ON FUNCTION public.get_admin_permissions(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_permissions(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_admin_permissions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_permissions(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_admin_audit_history(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_admin_audit_history(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_admin_audit_history(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_audit_history(uuid) TO service_role;

REVOKE ALL ON FUNCTION public.reactivate_admin(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reactivate_admin(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.reactivate_admin(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_admin(uuid, text) TO service_role;

REVOKE ALL ON FUNCTION public._admin_exec_reactivate(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._admin_exec_reactivate(uuid, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public._admin_exec_reactivate(uuid, uuid, text) TO service_role;
