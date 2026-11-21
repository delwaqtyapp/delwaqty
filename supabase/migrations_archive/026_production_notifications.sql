-- Sprint 69: Production Notification System
-- Enhances notifications table + device tokens + idempotency

-- 1. Add missing columns to notifications
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deep_link TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Unique index for idempotency (only non-null keys enforced)
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key
  ON notifications(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 2. Enhance notification_tokens for multi-device
ALTER TABLE notification_tokens
  ADD COLUMN IF NOT EXISTS device_id TEXT,
  ADD COLUMN IF NOT EXISTS app_version TEXT,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

-- Index for active token lookups (push sending)
CREATE INDEX IF NOT EXISTS idx_notification_tokens_active
  ON notification_tokens(user_id, is_active)
  WHERE is_active = true;

-- Index for stale token cleanup
CREATE INDEX IF NOT EXISTS idx_notification_tokens_last_seen
  ON notification_tokens(last_seen_at);

-- 3. Performance indexes
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read
  ON notifications(user_id, is_read, created_at DESC);

-- 4. RLS policies (extend existing)
-- Users can only update their own read state
DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
CREATE POLICY "Users update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users delete own notifications" ON notifications;
CREATE POLICY "Users delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);

-- Users can read own notifications
DROP POLICY IF EXISTS "Users read own notifications" ON notifications;
CREATE POLICY "Users read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert (backend push)
DROP POLICY IF EXISTS "Service role insert notifications" ON notifications;
CREATE POLICY "Service role insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- Admins can read all notifications
DROP POLICY IF EXISTS "Admins read all notifications" ON notifications;
CREATE POLICY "Admins read all notifications"
  ON notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- 5. Device tokens RLS
DROP POLICY IF EXISTS "Users manage own tokens" ON notification_tokens;
CREATE POLICY "Users manage own tokens"
  ON notification_tokens FOR ALL
  USING (auth.uid() = user_id);

-- Admins can read all tokens
DROP POLICY IF EXISTS "Admins read all tokens" ON notification_tokens;
CREATE POLICY "Admins read all tokens"
  ON notification_tokens FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- Service role full access to tokens
DROP POLICY IF EXISTS "Service role manage tokens" ON notification_tokens;
CREATE POLICY "Service role manage tokens"
  ON notification_tokens FOR ALL
  USING (true);

-- 6. Function to mark stale tokens inactive (called by edge function cron)
CREATE OR REPLACE FUNCTION deactivate_stale_tokens(stale_interval INTERVAL DEFAULT INTERVAL '30 days')
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE notification_tokens
  SET is_active = false
  WHERE is_active = true
    AND last_seen_at < NOW() - stale_interval;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Function to increment unread count efficiently
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  cnt INTEGER;
BEGIN
  SELECT COUNT(*) INTO cnt
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;
  RETURN COALESCE(cnt, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
