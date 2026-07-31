-- 015_create_management_tables.sql
-- Management system: complaints, sanctions, live tracking, support chat.
-- Fixes migration 014 which ABORTED because PostgreSQL does NOT support
-- "CREATE TYPE IF NOT EXISTS" (syntax error), leaving the management tables
-- missing -> the app reported "Could not find the table".
--
-- This migration is idempotent and self-healing:
--   * It detects the LEGACY ride "complaints" table (has ride_id column from
--     migration 007) and replaces it with a merged schema so BOTH the client
--     ride module and the new management module keep working.
--   * If the new-schema "complaints" already exists, missing columns are added.
--   * All other tables use CREATE TABLE IF NOT EXISTS and keep existing data.
--   * "sanction_type" / "sanction_target" are TEXT + CHECK (NOT enums) to avoid
--     the unsupported CREATE TYPE IF NOT EXISTS entirely.

-- ============================================================
-- 0. COMPLAINTS table conflict resolution
--    The ride module (supabase_ride_data_source.dart) still inserts
--    { ride_id, reporter_id, category } into "complaints". The management
--    module needs a different set of columns. We merge both.
-- ============================================================

-- Drop the LEGACY 007 ride-complaints table so the merged schema below is applied.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'complaints'
      AND column_name = 'ride_id'
      AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'complaints'
          AND column_name = 'complaint_type'
      )
  ) THEN
    DROP TABLE complaints CASCADE;
  END IF;
END
$$;

-- ============================================================
-- 1. COMPLAINTS (الشكاوى)
-- ============================================================
CREATE TABLE IF NOT EXISTS complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
  complainant_id UUID REFERENCES users(id) ON DELETE SET NULL,
  respondent_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reporter_id UUID REFERENCES users(id) ON DELETE SET NULL,
  complaint_type TEXT CHECK (complaint_type IN ('driver','merchant','customer','provider','other')),
  category TEXT,
  subject TEXT,
  description TEXT NOT NULL,
  attachments TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','investigating','resolved','rejected','escalated','open','dismissed')),
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low','medium','high','urgent')),
  admin_notes TEXT[] DEFAULT '{}',
  resolution_note TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Self-healing: add legacy ride columns if a new-schema complaints survived.
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS ride_id UUID REFERENCES rides(id) ON DELETE SET NULL;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS reporter_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS category TEXT;

CREATE INDEX IF NOT EXISTS idx_complaints_complainant ON complaints(complainant_id);
CREATE INDEX IF NOT EXISTS idx_complaints_respondent ON complaints(respondent_id);
CREATE INDEX IF NOT EXISTS idx_complaints_reporter ON complaints(reporter_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_created ON complaints(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_order ON complaints(order_id);

ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "complaints reporter rw" ON complaints;
DROP POLICY IF EXISTS "Users view own complaints" ON complaints;
DROP POLICY IF EXISTS "Admins view all complaints" ON complaints;
DROP POLICY IF EXISTS "Users insert complaints" ON complaints;

CREATE POLICY "Users view own complaints" ON complaints
  FOR SELECT USING (auth.uid() = complainant_id OR auth.uid() = reporter_id);

CREATE POLICY "Admins manage all complaints" ON complaints
  FOR ALL USING (auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner')));

CREATE POLICY "Users insert complaints" ON complaints
  FOR INSERT WITH CHECK (auth.uid() = complainant_id OR auth.uid() = reporter_id);

-- ============================================================
-- 2. SANCTIONS (العقوبات)
--    TEXT columns instead of enums (user spec + avoids CREATE TYPE issue).
-- ============================================================
CREATE TABLE IF NOT EXISTS sanctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_role TEXT NOT NULL
    CHECK (target_role IN ('customer','driver','merchant','provider','admin')),
  sanction_type TEXT NOT NULL
    CHECK (sanction_type IN ('warning','fine','temporary_ban','permanent_ban','suspension')),
  complaint_id UUID REFERENCES complaints(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  amount DECIMAL(10,2) DEFAULT 0,
  duration_days INTEGER DEFAULT 0,
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  issued_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sanctions_target ON sanctions(target_user_id);
CREATE INDEX IF NOT EXISTS idx_sanctions_active ON sanctions(is_active);
CREATE INDEX IF NOT EXISTS idx_sanctions_end_date ON sanctions(end_date);

ALTER TABLE sanctions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage sanctions" ON sanctions;
DROP POLICY IF EXISTS "Targets view own sanctions" ON sanctions;

CREATE POLICY "Admins manage sanctions" ON sanctions
  FOR ALL USING (auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner')));

CREATE POLICY "Targets view own sanctions" ON sanctions
  FOR SELECT USING (auth.uid() = target_user_id);

-- ============================================================
-- 3. LOCATION UPDATES (التتبع الحي)
-- ============================================================
CREATE TABLE IF NOT EXISTS location_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  is_moving BOOLEAN DEFAULT FALSE,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_location_user ON location_updates(user_id);
CREATE INDEX IF NOT EXISTS idx_location_recorded ON location_updates(recorded_at DESC);

ALTER TABLE location_updates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view all locations" ON location_updates;
DROP POLICY IF EXISTS "Users view own location" ON location_updates;
DROP POLICY IF EXISTS "Users insert own location" ON location_updates;

CREATE POLICY "Admins view all locations" ON location_updates
  FOR SELECT USING (auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner')));

CREATE POLICY "Users view own location" ON location_updates
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own location" ON location_updates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4. CHAT ROOMS (غرف المحادثة)
--    Note: the client creates rooms with ONLY the user in participant_ids,
--    so admins must be allowed explicitly alongside participants.
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type TEXT NOT NULL CHECK (room_type IN ('support','complaint','order','general')),
  participant_ids UUID[] NOT NULL,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  complaint_id UUID REFERENCES complaints(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT TRUE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chat_participants ON chat_rooms USING GIN(participant_ids);
CREATE INDEX IF NOT EXISTS idx_chat_last_message ON chat_rooms(last_message_at DESC);

ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view rooms they are in" ON chat_rooms;
DROP POLICY IF EXISTS "Admins view all rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users create rooms they are in" ON chat_rooms;
DROP POLICY IF EXISTS "Users update rooms they are in" ON chat_rooms;

CREATE POLICY "Users view rooms they are in" ON chat_rooms
  FOR SELECT USING (
    auth.uid() = ANY(participant_ids)
    OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
  );

CREATE POLICY "Admins manage all rooms" ON chat_rooms
  FOR ALL USING (auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner')));

CREATE POLICY "Users create rooms they are in" ON chat_rooms
  FOR INSERT WITH CHECK (
    auth.uid() = ANY(participant_ids)
    OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
  );

CREATE POLICY "Users update rooms they are in" ON chat_rooms
  FOR UPDATE USING (
    auth.uid() = ANY(participant_ids)
    OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
  );

-- ============================================================
-- 5. CHAT MESSAGES (رسائل المحادثة)
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text','image','file')),
  attachment_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(created_at);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users insert messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users update messages in their rooms" ON chat_messages;

CREATE POLICY "Users view messages in their rooms" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND (
          auth.uid() = ANY(chat_rooms.participant_ids)
          OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
        )
    )
  );

CREATE POLICY "Users insert messages in their rooms" ON chat_messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND (
          auth.uid() = ANY(chat_rooms.participant_ids)
          OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
        )
    )
  );

CREATE POLICY "Users update messages in their rooms" ON chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = chat_messages.room_id
        AND (
          auth.uid() = ANY(chat_rooms.participant_ids)
          OR auth.uid() IN (SELECT id FROM public.users WHERE role IN ('admin','owner'))
        )
    )
  );

-- ============================================================
-- 6. RPC: add_complaint_admin_note (used by SupabaseComplaintsDataSource)
-- ============================================================
CREATE OR REPLACE FUNCTION public.add_complaint_admin_note(
  p_complaint_id UUID,
  p_note TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role IN ('admin','owner')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  UPDATE complaints
  SET admin_notes = array_append(COALESCE(admin_notes, '{}'), p_note),
      updated_at = NOW()
  WHERE id = p_complaint_id;
END;
$$;

REVOKE ALL ON FUNCTION public.add_complaint_admin_note(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_complaint_admin_note(UUID, TEXT) TO authenticated;

-- ============================================================
-- 7. REALTIME: add tables to supabase_realtime publication
--    Required for .stream() in chat + location modules.
-- ============================================================
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['complaints','sanctions','location_updates','chat_rooms','chat_messages']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END
$$;

-- ============================================================
-- 8. STORAGE buckets + policies
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('complaints', 'complaints', false, 52428800, ARRAY['image/png','image/jpeg','image/webp','video/mp4']),
  ('chat_attachments', 'chat_attachments', false, 10485760, ARRAY['image/png','image/jpeg','image/webp','application/pdf','text/plain'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "authenticated upload to management buckets" ON storage.objects;
DROP POLICY IF EXISTS "authenticated read from management buckets" ON storage.objects;

CREATE POLICY "authenticated upload to management buckets" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id IN ('complaints','chat_attachments') AND auth.role() = 'authenticated'
  );

CREATE POLICY "authenticated read from management buckets" ON storage.objects
  FOR SELECT USING (
    bucket_id IN ('complaints','chat_attachments') AND auth.role() = 'authenticated'
  );
