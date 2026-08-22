-- 072_admin_rbac_roles_permissions.sql
-- Additive. Upgrades admin authorization from simple role checks toward
-- ROLE + PERMISSIONS + SCOPE. Reuses existing admin_permission_grants (034)
-- and admin_region_assignments (031). Permissions are evaluated server-side;
-- no client email / constant / UI-based authorization.
--
-- Permission vocabulary (canonical, backend-authoritative):
-- PLATFORM_OWNER, USER_MANAGEMENT, ACCOUNT_MANAGEMENT,
-- ORDER_VIEW, ORDER_MANAGEMENT, ORDER_ASSIGNMENT, ORDER_REASSIGNMENT, ORDER_CANCELLATION,
-- DRIVER_VIEW, DRIVER_MANAGEMENT, DRIVER_ASSIGNMENT, DRIVER_LOCATION_VIEW,
-- PROVIDER_VIEW, PROVIDER_MANAGEMENT, STORE_VIEW, STORE_MANAGEMENT, STORE_SUSPEND, STORE_DELETE,
-- PRODUCT_VIEW, PRODUCT_MANAGEMENT, PRODUCT_DELETE,
-- VERIFICATION_MANAGEMENT, DOCUMENT_MANAGEMENT,
-- SUPPORT_MANAGEMENT, COMPLAINT_MANAGEMENT, SANCTION_MANAGEMENT,
-- FINANCIAL_VIEW, FINANCIAL_MANAGEMENT, TOPUP_MANAGEMENT, COLLECTION_MANAGEMENT, SETTLEMENT_MANAGEMENT,
-- COMMISSION_VIEW, COMMISSION_MANAGEMENT, ACCOUNT_COMMISSION_OVERRIDE,
-- ADMIN_MANAGEMENT, ROLE_MANAGEMENT, PERMISSION_MANAGEMENT, AUDIT_LOG_VIEW,
-- REGIONAL_MANAGEMENT, DISPATCH_VIEW, DISPATCH_MANAGEMENT, DISPATCH_MANUAL_ASSIGN, DISPATCH_AUTO_CONTROL.

CREATE TABLE IF NOT EXISTS public.admin_roles (
  role_key      text PRIMARY KEY,
  display_name  text NOT NULL,
  description   text,
  is_system     boolean NOT NULL DEFAULT true,
  default_permissions jsonb NOT NULL DEFAULT '[]'::jsonb
);

INSERT INTO public.admin_roles (role_key, display_name, description, is_system, default_permissions) VALUES
 ('owner',            'Owner',            'Full platform authority (global).', true,
   '["PLATFORM_OWNER","USER_MANAGEMENT","ACCOUNT_MANAGEMENT","ORDER_VIEW","ORDER_MANAGEMENT","ORDER_ASSIGNMENT","ORDER_REASSIGNMENT","ORDER_CANCELLATION","DRIVER_VIEW","DRIVER_MANAGEMENT","DRIVER_ASSIGNMENT","DRIVER_LOCATION_VIEW","PROVIDER_VIEW","PROVIDER_MANAGEMENT","STORE_VIEW","STORE_MANAGEMENT","STORE_SUSPEND","STORE_DELETE","PRODUCT_VIEW","PRODUCT_MANAGEMENT","PRODUCT_DELETE","VERIFICATION_MANAGEMENT","DOCUMENT_MANAGEMENT","SUPPORT_MANAGEMENT","COMPLAINT_MANAGEMENT","SANCTION_MANAGEMENT","FINANCIAL_VIEW","FINANCIAL_MANAGEMENT","TOPUP_MANAGEMENT","COLLECTION_MANAGEMENT","SETTLEMENT_MANAGEMENT","COMMISSION_VIEW","COMMISSION_MANAGEMENT","ACCOUNT_COMMISSION_OVERRIDE","ADMIN_MANAGEMENT","ROLE_MANAGEMENT","PERMISSION_MANAGEMENT","AUDIT_LOG_VIEW","REGIONAL_MANAGEMENT","DISPATCH_VIEW","DISPATCH_MANAGEMENT","DISPATCH_MANUAL_ASSIGN","DISPATCH_AUTO_CONTROL"]'::jsonb),
 ('accounts_admin',   'Accounts Admin',   'User/account + financial visibility.', true,
   '["USER_MANAGEMENT","ACCOUNT_MANAGEMENT","FINANCIAL_VIEW","AUDIT_LOG_VIEW"]'::jsonb),
 ('operations_admin', 'Operations Admin', 'Orders, drivers, dispatch (no finance/admin).', true,
   '["ORDER_VIEW","ORDER_MANAGEMENT","ORDER_ASSIGNMENT","ORDER_REASSIGNMENT","ORDER_CANCELLATION","DRIVER_VIEW","DRIVER_MANAGEMENT","DRIVER_ASSIGNMENT","DRIVER_LOCATION_VIEW","DISPATCH_VIEW","DISPATCH_MANAGEMENT","DISPATCH_MANUAL_ASSIGN","PROVIDER_VIEW","STORE_VIEW","PRODUCT_VIEW"]'::jsonb),
 ('financial_admin',  'Financial Admin',  'Financial + commission management.', true,
   '["FINANCIAL_VIEW","FINANCIAL_MANAGEMENT","TOPUP_MANAGEMENT","COLLECTION_MANAGEMENT","SETTLEMENT_MANAGEMENT","COMMISSION_VIEW","COMMISSION_MANAGEMENT","ACCOUNT_COMMISSION_OVERRIDE","AUDIT_LOG_VIEW"]'::jsonb),
 ('support_admin',    'Support Admin',    'Support, complaints, sanctions.', true,
   '["SUPPORT_MANAGEMENT","COMPLAINT_MANAGEMENT","SANCTION_MANAGEMENT","USER_MANAGEMENT","ORDER_VIEW","PROVIDER_VIEW","STORE_VIEW","PRODUCT_VIEW","DRIVER_VIEW"]'::jsonb),
 ('verification_admin','Verification Admin','Provider verification + documents.', true,
   '["VERIFICATION_MANAGEMENT","DOCUMENT_MANAGEMENT","PROVIDER_VIEW","STORE_VIEW","AUDIT_LOG_VIEW"]'::jsonb),
 ('regional_admin',   'Regional Admin',   'Region-scoped operations.', true,
   '["ORDER_VIEW","ORDER_ASSIGNMENT","DRIVER_VIEW","DRIVER_ASSIGNMENT","DRIVER_LOCATION_VIEW","PROVIDER_VIEW","STORE_VIEW","STORE_MANAGEMENT","STORE_SUSPEND","PRODUCT_VIEW","PRODUCT_MANAGEMENT","DISPATCH_VIEW","DISPATCH_MANAGEMENT","DISPATCH_MANUAL_ASSIGN","REGIONAL_MANAGEMENT"]'::jsonb)
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
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ROLE_MANAGEMENT', NULL)) THEN
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
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('ADMIN_MANAGEMENT', NULL)) THEN
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
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('PERMISSION_MANAGEMENT', p_region_id)) THEN
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
  IF NOT (public._is_owner_uid(auth.uid()) OR public.admin_has_permission('PERMISSION_MANAGEMENT', p_region_id)) THEN
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

-- Consolidated permission check: owner short-circuit OR (role defaults UNION explicit grants)
-- AND region scope respected.
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
