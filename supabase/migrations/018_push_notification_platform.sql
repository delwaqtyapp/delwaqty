-- 018_push_notification_platform.sql
-- Completes the push notification system end-to-end.
--
-- Why:
--   * notification_tokens only had created_at, but the app + admin dashboard
--     already persist/read `updated_at` -> every token query errored and the
--     admin page showed a generic error ("خطأ").
--   * RLS only allowed auth.uid() = user_id, so admins could never list the
--     connected devices.
--   * There was no working send path: the admin page could only copy an FCM
--     payload for manual pasting into the Firebase console. This migration adds
--     the real in-app broadcast path (notifications table + realtime + RPC).
--   * The notifications table was not part of the supabase_realtime
--     publication, so instant in-app delivery was impossible.
--
-- Admin definition: users.role IN ('admin','owner') via public.is_admin()
-- (defined in 016_fix_rls_policies.sql, which runs before this file).
--
-- Idempotent: safe to re-run in a SQL editor.

-- ============================================================
-- 1. notification_tokens: add updated_at + index + auto-update trigger
-- ============================================================
ALTER TABLE public.notification_tokens
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS notification_tokens_user_id_idx
  ON public.notification_tokens (user_id);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notification_tokens_set_updated_at
  ON public.notification_tokens;
CREATE TRIGGER notification_tokens_set_updated_at
  BEFORE UPDATE ON public.notification_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 2. RLS: users manage own tokens, admins see all tokens
-- ============================================================
ALTER TABLE public.notification_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own tokens" ON public.notification_tokens;
CREATE POLICY "Users can manage own tokens" ON public.notification_tokens
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins select all tokens" ON public.notification_tokens;
CREATE POLICY "Admins select all tokens" ON public.notification_tokens
  FOR SELECT USING (public.is_admin());

-- ============================================================
-- 3. notifications: admins may broadcast (insert for any user)
--    Users keep viewing/updating only their own rows.
--    The legacy "Service role can insert notifications" policy
--    (002) was FOR INSERT WITH CHECK (true) with no role
--    restriction, so ANY authenticated user could insert a
--    notification for ANY user. Restrict it to service_role.
-- ============================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role can insert notifications" ON public.notifications;
CREATE POLICY "Service role can insert notifications" ON public.notifications
  FOR INSERT TO service_role WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;
CREATE POLICY "Admins can insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can select notifications" ON public.notifications;
CREATE POLICY "Admins can select notifications" ON public.notifications
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete notifications" ON public.notifications;
CREATE POLICY "Admins can delete notifications" ON public.notifications
  FOR DELETE USING (public.is_admin());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users can view own notifications'
  ) THEN
    CREATE POLICY "Users can view own notifications" ON public.notifications
      FOR SELECT USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
      AND policyname = 'Users can update own notifications'
  ) THEN
    CREATE POLICY "Users can update own notifications" ON public.notifications
      FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;

-- ============================================================
-- 4. Realtime: publish notifications so clients get instant
--    in-app push without waiting for FCM (works today, no keys).
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- ============================================================
-- 5. Broadcast RPC (admin only, SECURITY DEFINER)
--    Inserts one notifications row per matching user and returns
--    the number of recipients. Target filters are optional:
--      * p_target_user_id -> single user
--      * p_target_role    -> all users with that role
--      * neither          -> every user
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'info',
  p_deep_link TEXT DEFAULT NULL,
  p_target_role TEXT DEFAULT NULL,
  p_target_user_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  inserted_count INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data, is_read)
  SELECT
    u.id,
    p_title,
    p_body,
    p_type,
    CASE
      WHEN p_deep_link IS NULL THEN NULL
      ELSE jsonb_build_object('deep_link', p_deep_link)
    END,
    false
  FROM public.users u
  WHERE (p_target_user_id IS NULL OR u.id = p_target_user_id)
    AND (p_target_role IS NULL OR u.role = p_target_role);

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;

-- ============================================================
-- 6. Grants (RLS decides who sees what)
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_tokens TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
