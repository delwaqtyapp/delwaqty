-- 071_owner_multi_role_capabilities.sql
-- Additive. Backend-authoritative identity capability resolver + unified audit.
-- Owner authority derives from users.role='owner' (seeded for said.3pkarino@gmail.com
-- in 006/021). Multi-role is already supported at the data layer: a single auth
-- user may have rows in drivers / service_providers / merchants / users.role
-- simultaneously. This RPC exposes that fact server-side so Flutter never infers
-- role from email, constants or UI.

CREATE OR REPLACE FUNCTION public.get_my_capabilities()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'customer', EXISTS(SELECT 1 FROM users WHERE id = auth.uid()),
    'driver',   EXISTS(SELECT 1 FROM drivers WHERE user_id = auth.uid()),
    'provider', EXISTS(SELECT 1 FROM service_providers WHERE user_id = auth.uid()),
    'merchant', EXISTS(SELECT 1 FROM merchants WHERE owner_user_id = auth.uid()),
    'admin',    EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin','owner')),
    'owner',    EXISTS(SELECT 1 FROM users WHERE id = auth.uid() AND role = 'owner')
  );
$$;

REVOKE ALL ON FUNCTION public.get_my_capabilities() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_capabilities() TO authenticated;

-- Unified, structured audit log for all high-risk operations.
-- actor_role / scope added beyond the legacy activity_logs for RBAC attribution.
CREATE TABLE IF NOT EXISTS public.audit_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor         uuid REFERENCES auth.users(id),
  actor_role    text,
  scope         text,                       -- GLOBAL / REGION:<id> / SELF
  action        text NOT NULL,             -- e.g. ADMIN_PERMISSION_GRANT
  resource      text,                      -- e.g. admin / store / order / product
  resource_id   text,
  before        jsonb,
  after         jsonb,
  reason        text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON public.audit_log(actor);
CREATE INDEX IF NOT EXISTS idx_audit_log_resource ON public.audit_log(resource, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON public.audit_log(created_at DESC);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Only the actor (owner/admins) may read; writes only via SECURITY DEFINER RPCs.
DROP POLICY IF EXISTS audit_log_select ON public.audit_log;
CREATE POLICY audit_log_select ON public.audit_log
  FOR SELECT USING (
    auth.uid() = actor
    OR public._is_owner_uid(auth.uid())
    OR public.is_admin()
  );

-- Central audit writer. Never callable by anon/public.
CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action      text,
  p_resource    text,
  p_resource_id text,
  p_before      jsonb DEFAULT NULL,
  p_after       jsonb DEFAULT NULL,
  p_reason      text DEFAULT NULL,
  p_scope       text DEFAULT 'GLOBAL'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor   uuid := auth.uid();
  v_role    text;
  v_id      uuid;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  SELECT role INTO v_role FROM users WHERE id = v_actor;
  INSERT INTO public.audit_log (actor, actor_role, scope, action, resource, resource_id, before, after, reason)
  VALUES (v_actor, v_role, p_scope, p_action, p_resource, p_resource_id, p_before, p_after, p_reason)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_admin_action(text, text, text, jsonb, jsonb, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_admin_action(text, text, text, jsonb, jsonb, text, text) TO authenticated;
