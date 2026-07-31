-- 014_management_platform.sql
-- Management system: complaints, sanctions, live tracking, support chat

-- ============================================================
-- 1. COMPLAINTS (الشكاوى)
-- ============================================================
CREATE TABLE IF NOT EXISTS complaints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  complainant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  respondent_id UUID REFERENCES users(id) ON DELETE SET NULL,
  complaint_type TEXT NOT NULL CHECK (complaint_type IN ('driver','merchant','customer','provider','other')),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  attachments TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','investigating','resolved','rejected','escalated')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  admin_notes TEXT[] DEFAULT '{}',
  resolution_note TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_complaints_complainant ON complaints(complainant_id);
CREATE INDEX IF NOT EXISTS idx_complaints_respondent ON complaints(respondent_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_created ON complaints(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_order ON complaints(order_id);

ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own complaints" ON complaints
  FOR SELECT USING (auth.uid() = complainant_id);

CREATE POLICY "Admins view all complaints" ON complaints
  FOR ALL USING (auth.uid() IN (SELECT id FROM users WHERE role IN ('admin','owner')));

CREATE POLICY "Users insert complaints" ON complaints
  FOR INSERT WITH CHECK (auth.uid() = complainant_id);

-- ============================================================
-- 2. SANCTIONS (العقوبات)
-- ============================================================
CREATE TYPE IF NOT EXISTS sanction_type AS ENUM (
  'warning','fine','temporary_ban','permanent_ban','suspension'
);
CREATE TYPE IF NOT EXISTS sanction_target AS ENUM (
  'customer','driver','merchant','provider','admin'
);

CREATE TABLE IF NOT EXISTS sanctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_role sanction_target NOT NULL,
  sanction_type sanction_type NOT NULL,
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

CREATE POLICY "Admins manage sanctions" ON sanctions
  FOR ALL USING (auth.uid() IN (SELECT id FROM users WHERE role IN ('admin','owner')));

-- ============================================================
-- 3. LOCATION UPDATES (تحديثات المواقع)
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

CREATE POLICY "Admins view all locations" ON location_updates
  FOR SELECT USING (auth.uid() IN (SELECT id FROM users WHERE role IN ('admin','owner')));

CREATE POLICY "Users view own location" ON location_updates
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own location" ON location_updates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 4. CHAT ROOMS (غرف المحادثة)
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

CREATE POLICY "Users view rooms they are in" ON chat_rooms
  FOR SELECT USING (auth.uid() = ANY(participant_ids));

CREATE POLICY "Admins view all rooms" ON chat_rooms
  FOR ALL USING (auth.uid() IN (SELECT id FROM users WHERE role IN ('admin','owner')));

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

CREATE POLICY "Users view messages in their rooms" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms WHERE chat_rooms.id = chat_messages.room_id
      AND auth.uid() = ANY(chat_rooms.participant_ids)
    )
  );

CREATE POLICY "Users insert messages in their rooms" ON chat_messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_rooms WHERE chat_rooms.id = chat_messages.room_id
      AND auth.uid() = ANY(chat_rooms.participant_ids)
    )
  );

-- ============================================================
-- Storage buckets
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('complaints', 'complaints', false, 52428800, ARRAY['image/png','image/jpeg','image/webp','video/mp4']),
  ('chat_attachments', 'chat_attachments', false, 10485760, ARRAY['image/png','image/jpeg','image/webp','application/pdf','text/plain'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "authenticated upload to complaints" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id IN ('complaints','chat_attachments') AND auth.role() = 'authenticated');

CREATE POLICY "authenticated read from buckets" ON storage.objects
  FOR SELECT USING (bucket_id IN ('complaints','chat_attachments'));
