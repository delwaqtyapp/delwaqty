-- ============================================================
-- 031_admin_hierarchy_region_assignments.sql
-- Phase 2.2 — Admin hierarchy unification + region authorization
-- (D1 resolution, ADR-055 / ADR-056).
--
-- Scope (approved design, docs/HANDOFF/28 §4.5):
--   1. Connect, not fork: admin_users gains a user_id FK to the canonical
--      public.users identity (legacy metadata stays dormant; never an authz
--      source).
--   2. admin_region_assignments: the single new table expressing region scope
--      for admins. owner = implicit global (no rows). An admin with no rows =
--      global; with rows = scoped to those regions and their descendants.
--   3. public.is_admin_for_region(p_region_id): SECURITY DEFINER helper
--      (016 pattern) = is_admin() AND (owner OR assignment covers region).
--   4. F1/F2 RLS drift fixes: rewrite the 6 policies that used literal
--      users.role = 'admin' / raw_user_meta_data to the canonical
--      public.is_admin() (owner included).
--   5. F3 dedup: drop duplicate/overlapping policies on notifications and
--      notification_tokens (keep is_admin() + own-row variants).
--   6. No self-elevation: users_guard_role_change trigger + admin_set_user_role
--      RPC (authorized admin-management flow only).
--
-- Security (030 lesson, R7): Supabase default privileges grant ALL to
-- anon/authenticated on new tables — REVOKE-before-GRANT here. admin_region_assignments
-- is NOT added to supabase_realtime.
--
-- Idempotent: safe to re-run. No data destruction. No admin seeds.
-- ============================================================

BEGIN;

-- ─── 1. CONNECT admin_users TO CANONICAL IDENTITY (ADR-055) ───

ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.admin_users'::regclass
      AND conname = 'admin_users_user_id_key'
  ) THEN
    ALTER TABLE public.admin_users
      ADD CONSTRAINT admin_users_user_id_key UNIQUE (user_id);
  END IF;
END $body$;

-- ─── 2. ADMIN REGION ASSIGNMENTS ──────────────────────────────

CREATE TABLE IF NOT EXISTS public.admin_region_assignments (
  admin_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  region_id  uuid NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  scope      text NOT NULL DEFAULT 'descendants'
             CHECK (scope IN ('self','descendants')),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.users(id),
  PRIMARY KEY (admin_id, region_id)
);

ALTER TABLE public.admin_region_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_region_assignments admin all"
  ON public.admin_region_assignments;
CREATE POLICY "admin_region_assignments admin all"
  ON public.admin_region_assignments
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_admin_region_assignments_region
  ON public.admin_region_assignments (region_id);

-- REVOKE-before-GRANT (030 lesson): never leave the platform default
-- ALL-on-new-table grants. anon gets nothing; authenticated DML is RLS-gated.
REVOKE ALL ON public.admin_region_assignments FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.admin_region_assignments TO authenticated;

-- ─── 3. is_admin_for_region (016 pattern) ─────────────────────

CREATE OR REPLACE FUNCTION public.is_admin_for_region(p_region_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.is_admin()
    AND (
      EXISTS (SELECT 1 FROM public.users
               WHERE id = auth.uid() AND role = 'owner')
      OR EXISTS (
        SELECT 1
        FROM public.admin_region_assignments a
        WHERE a.admin_id = auth.uid()
          AND (
            a.scope = 'self'
              AND a.region_id = p_region_id
            OR a.scope = 'descendants'
              AND p_region_id IN (
                WITH RECURSIVE covered AS (
                  SELECT id FROM public.regions WHERE id = a.region_id
                  UNION ALL
                  SELECT r.id
                  FROM public.regions r
                  JOIN covered c ON r.parent_region_id = c.id
                )
                SELECT id FROM covered
              )
          )
      )
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin_for_region(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_for_region(uuid) TO authenticated;

-- ─── 4. F1/F2 RLS DRIFT FIXES (ADR-056) ───────────────────────
-- Rewrite the 6 policies that gated on literal role / raw_user_meta_data to
-- the canonical public.is_admin() so owner is included.

-- 4.1 activity_logs (F1)
DROP POLICY IF EXISTS "Activity logs viewable by admins only" ON public.activity_logs;
DROP POLICY IF EXISTS "activity_logs admin select" ON public.activity_logs;
CREATE POLICY "activity_logs admin select" ON public.activity_logs
  FOR SELECT USING (public.is_admin());

-- 4.2 platform_settings (F1)
DROP POLICY IF EXISTS "Settings updatable by admins" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings admin update" ON public.platform_settings;
CREATE POLICY "platform_settings admin update" ON public.platform_settings
  FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 4.3 categories (F1)
DROP POLICY IF EXISTS "Admins can manage categories" ON public.categories;
DROP POLICY IF EXISTS "categories admin manage" ON public.categories;
CREATE POLICY "categories admin manage" ON public.categories
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 4.4 admin_users (F1, dormant metadata — still readable by admins)
DROP POLICY IF EXISTS "Admin users viewable by admins only" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users admin select" ON public.admin_users;
CREATE POLICY "admin_users admin select" ON public.admin_users
  FOR SELECT USING (public.is_admin());

-- 4.5 notification_tokens (F1): drop the literal SELECT, keep is_admin() variant
DROP POLICY IF EXISTS "Admins read all tokens" ON public.notification_tokens;

-- 4.6 service_audio_logs (F2: raw_user_meta_data identity source)
DROP POLICY IF EXISTS "admin all logs r" ON public.service_audio_logs;
DROP POLICY IF EXISTS "service_audio_logs admin select" ON public.service_audio_logs;
CREATE POLICY "service_audio_logs admin select" ON public.service_audio_logs
  FOR SELECT USING (public.is_admin());

-- ─── 5. F3 DEDUP notifications / notification_tokens ──────────
-- Keep: is_admin() admin variants + own-row user variants + service_role.
-- Drop: literal-role duplicates, duplicate own-row policies, and the {public}
-- (anon-reachable) "Service role insert notifications" policy.

-- notifications SELECT: keep "Admins can select notifications" (is_admin())
DROP POLICY IF EXISTS "Admins read all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;

-- notifications INSERT: keep "Admins can insert notifications" + the true
-- service_role policy; drop the {public} duplicate (anon could insert).
DROP POLICY IF EXISTS "Service role insert notifications" ON public.notifications;

-- notifications UPDATE: keep the own-row policy with WITH CHECK
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;

-- notification_tokens ALL: keep "Users can manage own tokens" (WITH CHECK)
DROP POLICY IF EXISTS "Users manage own tokens" ON public.notification_tokens;

-- notification_tokens: "Service role manage tokens" was created WITHOUT a
-- TO clause (roles = {public}, qual true) -> anon/authenticated could read or
-- manage every device token. Recreate it properly scoped to service_role
-- (no PUBLIC/anon leak). The name already says service role; now the role
-- matches the name.
DROP POLICY IF EXISTS "Service role manage tokens" ON public.notification_tokens;
CREATE POLICY "Service role manage tokens" ON public.notification_tokens
  FOR ALL
  TO service_role
  USING (true);

-- ─── 6. NO SELF-ELEVATION (mandate) ────────────────────────────
-- users.role is the canonical authority; changing it requires is_admin() and
-- may never target the caller's own row. Only an existing owner may grant
-- the owner role. The admin_set_user_role RPC is the authorized management
-- flow; the trigger enforces the same rules on any direct table write.

CREATE OR REPLACE FUNCTION public.users_guard_role_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF auth.uid() IS NULL THEN
      RETURN NEW;
    END IF;
    IF auth.uid() = OLD.id THEN
      RAISE EXCEPTION 'Cannot change your own role';
    END IF;
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
    IF NEW.role = 'owner'
      AND NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'owner'
      ) THEN
      RAISE EXCEPTION 'Only owner can grant owner role';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_guard_role_change ON public.users;
CREATE TRIGGER users_guard_role_change
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_guard_role_change();

-- Authorized admin-management flow (016 pattern).
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
  IF p_role = 'owner'
    AND NOT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'owner'
    ) THEN
    RAISE EXCEPTION 'Only owner can grant owner role';
  END IF;
  UPDATE public.users SET role = p_role WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;

COMMIT;
