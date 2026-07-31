-- 013_service_audio_logs.sql
-- Audio recording logs for home service dispute protection

CREATE TABLE IF NOT EXISTS service_audio_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  audio_url TEXT,
  duration INTEGER,
  status TEXT NOT NULL DEFAULT 'recording'
    CHECK (status IN ('recording', 'completed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE service_audio_logs ENABLE ROW LEVEL SECURITY;

-- Customer: see own logs
CREATE POLICY "customer own logs rw" ON service_audio_logs
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Provider: see logs where they are the provider
CREATE POLICY "provider own logs r" ON service_audio_logs
  FOR SELECT
  USING (auth.uid() = provider_id);

-- Admin: see all logs
CREATE POLICY "admin all logs r" ON service_audio_logs
  FOR SELECT
  USING (auth.uid() IN (
    SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' IN ('admin', 'owner')
  ));

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_service_audio_logs_order ON service_audio_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_service_audio_logs_user ON service_audio_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_service_audio_logs_provider ON service_audio_logs(provider_id);

-- Storage bucket for audio files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('service-audio-logs', 'service-audio-logs', true, 52428800, ARRAY['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/mpeg'])
ON CONFLICT (id) DO NOTHING;

-- Storage bucket policy: authenticated users can upload, public can read
CREATE POLICY "audio logs upload" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'service-audio-logs'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "audio logs read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'service-audio-logs');
