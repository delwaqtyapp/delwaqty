-- 072_admin_rbac_roles_permissions.sql
-- Additive. Implements the CANONICAL Admin RBAC engine used by the Admin
-- control center. It reuses the single existing grants table
-- (public.admin_permission_grants, from 034) as the shared source of truth for
-- explicit permission deviations, and adds role templates (public.admin_roles)
-- for default permission sets. Permission evaluation is server-side only;
-- no client email / constant / UI-based authorization.
--
-- Single decision engine for Admin capabilities: public.admin_has_permission(p, region).
-- (The legacy public.has_permission(...) from 034 remains the engine for
--  member/customer operations; both consult public.admin_permission_grants,
--  so grants are never duplicated.)
--
-- Canonical permission vocabulary (backend-authoritative):
--   USER_VIEW, USER_EDIT, USER_SUSPEND, USER_DELETE
--   ADMIN_CREATE, ADMIN_EDIT, ADMIN_DEACTIVATE, ADMIN_ASSIGN_ROLE, ADMIN_GRANT_PERMISSION
--   ORDER_VIEW, ORDER_ASSIGN, ORDER_REASSIGN, ORDER_CANCEL, ORDER_MANAGE
--   DELIVERY_VIEW, DELIVERY_ASSIGN, DELIVERY_REASSIGN, DELIVERY_MOVE, DELIVERY_SUSPEND, DELIVERY_LOCATION_VIEW
--   DISPATCH_VIEW, DISPATCH_MANAGE, DISPATCH_AUTO, DISPATCH_MANUAL, DISPATCH_CONFIGURE
--   PROVIDER_VIEW, PROVIDER_EDIT, PROVIDER_VERIFY, PROVIDER_SUSPEND, PROVIDER_CATALOG_MANAGE, PROVIDER_DELETE
--   FINANCIAL_VIEW, TOPUP_APPROVE, COLLECTION_VIEW, SETTLEMENT_MANAGE,
--   COMMISSION_VIEW, COMMISSION_MANAGE, RECEIVING_ACCOUNT_MANAGE, GRACE_MANAGE
--   SUPPORT_VIEW, SUPPORT_REPLY, COMPLAINT_MANAGE
--   SECURITY_VIEW, AUDIT_VIEW, SANCTION_MANAGE, REGIONAL_MANAGEMENT

CREATE TABLE IF NOT EXISTS public.admin_roles (
  role_key      text PRIMARY KEY,
  display_name  text NOT NULL,
  description   text,
  is_system     boolean NOT NULL DEFAULT true,
  default_permissions jsonb NOT NULL DEFAULT '[]'::jsonb
);

INSERT INTO public.admin_roles (role_key, display_name, description, is_system, default_permissions) VALUES
 ('owner',            'Owner',            'Full platform authority (global, server-derived).', true,
   '["USER_VIEW","USER_EDIT","USER_SUSPEND","USER_DELETE","ADMIN_CREATE","ADMIN_EDIT","ADMIN_DEACTIVATE","ADMIN_ASSIGN_ROLE","ADMIN_GRANT_PERMISSION","ORDER_VIEW","ORDER_ASSIGN","ORDER_REASSIGN","ORDER_CANCEL","ORDER_MANAGE","DELIVERY_VIEW","DELIVERY_ASSIGN","DELIVERY_REASSIGN","DELIVERY_MOVE","DELIVERY_SUSPEND","DELIVERY_LOCATION_VIEW","DISPATCH_VIEW","DISPATCH_MANAGE","DISPATCH_AUTO","DISPATCH_MANUAL","DISPATCH_CONFIGURE","PROVIDER_VIEW","PROVIDER_EDIT","PROVIDER_VERIFY","PROVIDER_SUSPEND","PROVIDER_CATALOG_MANAGE","PROVIDER_DELETE","FINANCIAL_VIEW","TOPUP_APPROVE","COLLECTION_VIEW","SETTLEMENT_MANAGE","COMMISSION_VIEW","COMMISSION_MANAGE","RECEIVING_ACCOUNT_MANAGE","GRACE_MANAGE","SUPPORT_VIEW","SUPPORT_REPLY","COMPLAINT_MANAGE","SECURITY_VIEW","AUDIT_VIEW","SANCTION_MANAGE","REGIONAL_MANAGEMENT"]'::jsonb),
 ('accounts_admin',   'Admin Accounts',   'User/account + financial visibility.', true,
   '["USER_VIEW","USER_EDIT","USER_SUSPEND","USER_DELETE","FINANCIAL_VIEW","AUDIT_VIEW"]'::jsonb),
 ('operations_admin', 'Operations Admin', 'Orders, delivery, dispatch (no finance/admin).', true,
   '["ORDER_VIEW","ORDER_ASSIGN","ORDER_REASSIGN","ORDER_CANCEL","ORDER_MANAGE","DELIVERY_VIEW","DELIVERY_ASSIGN","DELIVERY_REASSIGN","DELIVERY_MOVE","DELIVERY_SUSPEND","DELIVERY_LOCATION_VIEW","DISPATCH_VIEW","DISPATCH_MANAGE","DISPATCH_AUTO","DISPATCH_MANUAL","PROVIDER_VIEW","SUPPORT_VIEW"]'::jsonb),
 ('delivery_operations','Delivery Operations','Delivery workforce + dispatch operations.', true,
   '["DELIVERY_VIEW","DELIVERY_ASSIGN","DELIVERY_REASSIGN","DELIVERY_MOVE","DELIVERY_SUSPEND","DELIVERY_LOCATION_VIEW","DISPATCH_VIEW","DISPATCH_MANAGE","DISPATCH_AUTO","DISPATCH_MANUAL","DISPATCH_CONFIGURE","ORDER_VIEW"]'::jsonb),
 ('orders_admin',     'Orders Admin',     'Order management + delivery visibility.', true,
   '["ORDER_VIEW","ORDER_ASSIGN","ORDER_REASSIGN","ORDER_CANCEL","ORDER_MANAGE","DELIVERY_VIEW","DELIVERY_LOCATION_VIEW"]'::jsonb),
 ('financial_admin',  'Financial Admin',  'Financial + commission management.', true,
   '["FINANCIAL_VIEW","TOPUP_APPROVE","COLLECTION_VIEW","SETTLEMENT_MANAGE","COMMISSION_VIEW","COMMISSION_MANAGE","RECEIVING_ACCOUNT_MANAGE","GRACE_MANAGE","AUDIT_VIEW"]'::jsonb),
 ('provider_management','Provider Management','Provider verification + catalog management.', true,
   '["PROVIDER_VIEW","PROVIDER_EDIT","PROVIDER_VERIFY","PROVIDER_SUSPEND","PROVIDER_CATALOG_MANAGE","PROVIDER_DELETE","ORDER_VIEW"]'::jsonb),
 ('support_admin',    'Support Admin',    'Support, complaints, sanctions.', true,
   '["SUPPORT_VIEW","SUPPORT_REPLY","COMPLAINT_MANAGE","USER_VIEW","ORDER_VIEW","PROVIDER_VIEW","DELIVERY_VIEW"]'::jsonb),
 ('regional_admin',   'Regional Admin',   'Region-scoped operations.', true,
   '["ORDER_VIEW","ORDER_ASSIGN","DELIVERY_VIEW","DELIVERY_ASSIGN","DELIVERY_LOCATION_VIEW","PROVIDER_VIEW","PROVIDER_EDIT","PROVIDER_SUSPEND","PROVIDER_CATALOG_MANAGE","DISPATCH_VIEW","DISPATCH_MANAGE","DISPATCH_MANUAL","REGIONAL_MANAGEMENT"]'::jsonb),
 ('security_admin',   'Security Admin',   'Security, audit, sanctions.', true,
   '["SECURITY_VIEW","AUDIT_VIEW","SANCTION_MANAGE","USER_VIEW","USER_SUSPEND","USER_DELETE"]'::jsonb),
 ('read_only_admin',  'Read Only Admin',  'Read-only platform visibility.', true,
   '["USER_VIEW","ORDER_VIEW","DELIVERY_VIEW","PROVIDER_VIEW","FINANCIAL_VIEW","SUPPORT_VIEW","SECURITY_VIEW","AUDIT_VIEW","DISPATCH_VIEW","COMPLAINT_MANAGE"]'::jsonb)
ON CONFLICT (role_key) DO UPDATE SET default_permissions = EXCLUDED.default_permissions;

-- Defensive additive columns so this migration is self-contained.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role_key text REFERENCES public.admin_roles(role_key);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE public.admin_permission_grants ADD COLUMN IF NOT EXISTS region_id uuid;
DROP INDEX IF EXISTS uni_admin_perm;
CREATE UNIQUE INDEX IF NOT EXISTS uni_admin_perm
  ON public.admin_permission_grants (admin_id, permission, COALESCE(region_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Link an admin user to a role template (additive).
CREATE OR REPLACE FUNCTION public.admin_assign_role(
  p_admin_id uuid,
  p_role_key text,
  p_reason   text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_before jsonb;
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ADMIN_ASSIGN_ROLE', NULL)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT jsonb_build_object('role', role_key) INTO v_before FROM users WHERE id = p_admin_id;
  UPDATE users SET role_key = p_role_key WHERE id = p_admin_id;
  PERFORM public.log_admin_action('ADMIN_ROLE_CHANGE', 'admin', p_admin_id::text, v_before,
    jsonb_build_object('role', p_role_key), p_reason);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_assign_role(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assign_role(uuid, text, text) TO authenticated;

-- De/activate admin.
CREATE OR REPLACE FUNCTION public.admin_set_admin_status(
  p_admin_id uuid, p_active boolean, p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_before jsonb;
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ADMIN_EDIT', NULL)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT jsonb_build_object('status', status) INTO v_before FROM users WHERE id = p_admin_id;
  UPDATE users SET status = CASE WHEN p_active THEN 'active' ELSE 'inactive' END WHERE id = p_admin_id;
  PERFORM public.log_admin_action('ADMIN_STATUS_CHANGE', 'admin', p_admin_id::text, v_before,
    jsonb_build_object('status', CASE WHEN p_active THEN 'active' ELSE 'inactive' END), p_reason);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_admin_status(uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_admin_status(uuid, boolean, text) TO authenticated;

-- Grant / revoke a single permission (additive on top of role defaults).
CREATE OR REPLACE FUNCTION public.admin_grant_permission(
  p_admin_id uuid, p_permission text, p_region_id uuid DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ADMIN_GRANT_PERMISSION', p_region_id)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.admin_permission_grants (admin_id, permission, region_id)
  VALUES (p_admin_id, p_permission, p_region_id)
  ON CONFLICT (admin_id, permission, COALESCE(region_id, '00000000-0000-0000-0000-000000000000'::uuid))
  DO NOTHING;
  PERFORM public.log_admin_action('ADMIN_PERMISSION_GRANT', 'admin', p_admin_id::text,
    NULL, jsonb_build_object('permission', p_permission, 'region', p_region_id), p_reason);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_grant_permission(uuid, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_grant_permission(uuid, text, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_revoke_permission(
  p_admin_id uuid, p_permission text, p_region_id uuid DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ADMIN_GRANT_PERMISSION', p_region_id)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  DELETE FROM public.admin_permission_grants
   WHERE admin_id = p_admin_id AND permission = p_permission
     AND COALESCE(region_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(p_region_id, '00000000-0000-0000-0000-000000000000'::uuid);
  PERFORM public.log_admin_action('ADMIN_PERMISSION_REVOKE', 'admin', p_admin_id::text,
    jsonb_build_object('permission', p_permission, 'region', p_region_id), NULL, p_reason);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_revoke_permission(uuid, text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_revoke_permission(uuid, text, uuid, text) TO authenticated;

-- Region assignment (scope).
CREATE OR REPLACE FUNCTION public.admin_assign_region(
  p_admin_id uuid, p_region_id uuid, p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('REGIONAL_MANAGEMENT', p_region_id)) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.admin_region_assignments (admin_id, region_id)
  VALUES (p_admin_id, p_region_id)
  ON CONFLICT (admin_id, region_id) DO NOTHING;
  PERFORM public.log_admin_action('ADMIN_REGION_ASSIGN', 'admin', p_admin_id::text,
    NULL, jsonb_build_object('region', p_region_id), p_reason);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_assign_region(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assign_region(uuid, uuid, text) TO authenticated;

-- Consolidated Admin permission check: owner short-circuit OR
-- (role-template defaults UNION explicit grants) AND region scope respected.
CREATE OR REPLACE FUNCTION public.admin_has_permission(
  p_permission text, p_region_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_role text;
  v_count int;
BEGIN
  IF v_uid IS NULL THEN RETURN false; END IF;
  SELECT role, role_key INTO v_role FROM users WHERE id = v_uid;
  IF v_role = 'owner' THEN RETURN true; END IF;
  IF v_role IS NULL OR v_role <> 'admin' THEN RETURN false; END IF;

  SELECT count(*) INTO v_count
  FROM (
    SELECT permission FROM public.admin_roles r
      WHERE r.role_key = (SELECT role_key FROM users WHERE id = v_uid)
    UNION
    SELECT permission FROM public.admin_permission_grants g
      WHERE g.admin_id = v_uid
        AND (g.region_id IS NULL OR p_region_id IS NULL OR g.region_id = p_region_id)
  ) t
  WHERE t.permission = p_permission;

  RETURN v_count > 0;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_has_permission(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_has_permission(text, uuid) TO authenticated;

-- View effective permissions (role defaults + explicit grants) for an admin.
CREATE OR REPLACE FUNCTION public.admin_effective_permissions(p_admin_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'role', (SELECT role_key FROM users WHERE id = p_admin_id),
    'role_permissions',
      (SELECT COALESCE(r.default_permissions, '[]'::jsonb)
         FROM public.admin_roles r WHERE r.role_key = (SELECT role_key FROM users WHERE id = p_admin_id)),
    'granted',
      (SELECT COALESCE(jsonb_agg(DISTINCT permission), '[]'::jsonb)
         FROM public.admin_permission_grants WHERE admin_id = p_admin_id),
    'regions',
      (SELECT COALESCE(jsonb_agg(DISTINCT region_id), '[]'::jsonb)
         FROM public.admin_region_assignments WHERE admin_id = p_admin_id)
  );
$$;
REVOKE ALL ON FUNCTION public.admin_effective_permissions(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_effective_permissions(uuid) TO authenticated;
