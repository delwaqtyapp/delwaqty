-- 016_fix_rls_policies.sql
-- Deterministic RLS rebuild for the 5 management tables.
-- Fixes missing / incomplete / duplicate policies left by migrations 007, 014, 015.
--
-- Safe to re-run as many times as needed (idempotent):
--   * drops EVERY known policy name on these tables (from 007 / 014 / 015)
--   * enables RLS explicitly
--   * recreates clean, explicit SELECT / INSERT / UPDATE / DELETE policies
--   * adds is_admin() helper + add_admin_note() function
--   * grants table privileges to the `authenticated` role
--
-- Admin definition: a user is admin when users.role IN ('admin','owner').
-- This matches the app (chat_providers.dart, auth_provider.dart, 006 migration).
-- NOTE: admin_users.id is a SEPARATE generated UUID (not users.id), so it is
-- intentionally NOT used for the auth.uid() check.

-- ============================================================
-- 0. HELPER FUNCTIONS
-- ============================================================

-- Returns true when the calling user is an admin / owner.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('admin', 'owner')
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- Adds an admin note to a complaint (admin only).
CREATE OR REPLACE FUNCTION public.add_admin_note(
  p_complaint_id UUID,
  p_note TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE complaints
  SET admin_notes = array_append(COALESCE(admin_notes, '{}'), p_note),
      updated_at = NOW()
  WHERE id = p_complaint_id;
END;
$$;

REVOKE ALL ON FUNCTION public.add_admin_note(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_admin_note(UUID, TEXT) TO authenticated;

-- Keep the legacy name used by SupabaseComplaintsDataSource.addAdminNote.
CREATE OR REPLACE FUNCTION public.add_complaint_admin_note(
  p_complaint_id UUID,
  p_note TEXT
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.add_admin_note(p_complaint_id, p_note);
$$;

REVOKE ALL ON FUNCTION public.add_complaint_admin_note(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_complaint_admin_note(UUID, TEXT) TO authenticated;

-- ============================================================
-- 1. COMPLAINTS (الشكاوى)
--    Admin: full control.  User: own complaints only
--    (complainant_id OR reporter_id covers the legacy ride-report feature).
-- ============================================================
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "complaints reporter rw" ON complaints;
DROP POLICY IF EXISTS "Users view own complaints" ON complaints;
DROP POLICY IF EXISTS "Admins view all complaints" ON complaints;
DROP POLICY IF EXISTS "Admins manage all complaints" ON complaints;
DROP POLICY IF EXISTS "Users insert complaints" ON complaints;

CREATE POLICY "admins select complaints" ON complaints
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admins insert complaints" ON complaints
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "admins update complaints" ON complaints
  FOR UPDATE USING (public.is_admin());
CREATE POLICY "admins delete complaints" ON complaints
  FOR DELETE USING (public.is_admin());

CREATE POLICY "users select own complaints" ON complaints
  FOR SELECT USING (complainant_id = auth.uid() OR reporter_id = auth.uid());
CREATE POLICY "users insert own complaints" ON complaints
  FOR INSERT WITH CHECK (complainant_id = auth.uid() OR reporter_id = auth.uid());
CREATE POLICY "users update own complaints" ON complaints
  FOR UPDATE USING (complainant_id = auth.uid() OR reporter_id = auth.uid());

-- ============================================================
-- 2. SANCTIONS (العقوبات)
--    Admin: full control.  Target user: view own only.
-- ============================================================
ALTER TABLE sanctions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage sanctions" ON sanctions;
DROP POLICY IF EXISTS "Targets view own sanctions" ON sanctions;

CREATE POLICY "admins select sanctions" ON sanctions
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admins insert sanctions" ON sanctions
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "admins update sanctions" ON sanctions
  FOR UPDATE USING (public.is_admin());
CREATE POLICY "admins delete sanctions" ON sanctions
  FOR DELETE USING (public.is_admin());

CREATE POLICY "users select own sanctions" ON sanctions
  FOR SELECT USING (target_user_id = auth.uid());

-- ============================================================
-- 3. LOCATION UPDATES (التتبع الحي)
--    Admin: view + delete all.  User: view + insert own.
-- ============================================================
ALTER TABLE location_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view all locations" ON location_updates;
DROP POLICY IF EXISTS "Users view own location" ON location_updates;
DROP POLICY IF EXISTS "Users insert own location" ON location_updates;

CREATE POLICY "admins select locations" ON location_updates
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admins delete locations" ON location_updates
  FOR DELETE USING (public.is_admin());

CREATE POLICY "users select own locations" ON location_updates
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "users insert own locations" ON location_updates
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 4. CHAT ROOMS (غرف المحادثة)
--    Admin: full control.  Participant: view / create / update own rooms.
--    (A user must be one of the participants to create a room.)
-- ============================================================
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view rooms they are in" ON chat_rooms;
DROP POLICY IF EXISTS "Admins view all rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Admins manage all rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users create rooms they are in" ON chat_rooms;
DROP POLICY IF EXISTS "Users update rooms they are in" ON chat_rooms;

CREATE POLICY "admins select rooms" ON chat_rooms
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admins insert rooms" ON chat_rooms
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "admins update rooms" ON chat_rooms
  FOR UPDATE USING (public.is_admin());
CREATE POLICY "admins delete rooms" ON chat_rooms
  FOR DELETE USING (public.is_admin());

CREATE POLICY "users select own rooms" ON chat_rooms
  FOR SELECT USING (auth.uid() = ANY(participant_ids));
CREATE POLICY "users create own rooms" ON chat_rooms
  FOR INSERT WITH CHECK (auth.uid() = ANY(participant_ids));
CREATE POLICY "users update own rooms" ON chat_rooms
  FOR UPDATE USING (auth.uid() = ANY(participant_ids));

-- ============================================================
-- 5. CHAT MESSAGES (رسائل المحادثة)
--    Admin: full control.  Participant: view / send / read-update
--    messages inside rooms they belong to.
-- ============================================================
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users insert messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users update messages in their rooms" ON chat_messages;

CREATE POLICY "admins select messages" ON chat_messages
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admins insert messages" ON chat_messages
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "admins update messages" ON chat_messages
  FOR UPDATE USING (public.is_admin());
CREATE POLICY "admins delete messages" ON chat_messages
  FOR DELETE USING (public.is_admin());

CREATE POLICY "users select own room messages" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND auth.uid() = ANY(chat_rooms.participant_ids)
    )
  );
CREATE POLICY "users insert own room messages" ON chat_messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND auth.uid() = ANY(chat_rooms.participant_ids)
    )
  );
CREATE POLICY "users update own room messages" ON chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND auth.uid() = ANY(chat_rooms.participant_ids)
    )
  );

-- ============================================================
-- 6. GRANTS (privileges for the authenticated role)
--    RLS decides WHO sees WHAT; grants decide the role may touch the tables.
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON complaints TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sanctions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON location_updates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;

-- ============================================================
-- 7. VERIFICATION (optional — run in SQL Editor to inspect final state)
-- ============================================================
-- SELECT tablename, policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('complaints','sanctions','location_updates','chat_rooms','chat_messages')
-- ORDER BY tablename, cmd;
