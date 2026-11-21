-- 200: Unify admin_has_permission with the canonical has_permission().
--
-- admin_has_permission() was broken two ways:
--   1. It selected a non-existent `permission` column from admin_roles
--      (that table stores default_permissions as a jsonb array), so every
--      call errored 42703.
--   2. It implemented a parallel permission model (role templates in the
--      legacy USER_VIEW/ORDER_ASSIGN vocabulary) that no enforcement path
--      uses: every guarded RPC checks has_permission(), which reads
--      admin_permission_grants + the default in-scope matrix in the
--      MEMBER_*/ORDER_*/FINANCIAL_* vocabulary.
-- Result: the check function disagreed with enforcement and never worked.
-- Fix: delegate to has_permission() so the check and the enforcement are
-- the same code path. Role templates (admin_roles) remain metadata; the
-- vocabulary mismatch is a known residual tracked for an owner decision.
CREATE OR REPLACE FUNCTION public.admin_has_permission(
  p_permission text,
  p_region_id uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.has_permission(p_permission, p_region_id);
$function$;
