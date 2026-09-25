-- 097_chat_permissions_and_call_receiving.sql
-- Global chat feature flags on platform_settings (public-readable, admin-updated)
-- + per-user incoming-call receiving control on users.
--
-- Called the ADMIN-permissions panel: the admin can enable/disable for ALL
-- users (a) voice calls, (b) voice messages, (c) media attachments, and each
-- user (customer app AND admin app) can turn on/off receiving incoming calls.

-- 1) Global chat feature flags (single row platform_settings, id='default')
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS chat_calls_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS chat_voice_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.platform_settings
  ADD COLUMN IF NOT EXISTS chat_media_enabled BOOLEAN NOT NULL DEFAULT true;

-- Make sure the single default row exists.
INSERT INTO public.platform_settings (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

-- 2) Per-user control: "do I receive incoming calls?" (customer + admin able to
--    update their own row thanks to existing users_update_own policy).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS chat_calls_enabled BOOLEAN NOT NULL DEFAULT true;

-- Index for the realtime chat_messages call-alert listener that checks the
-- receiver's preference.
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_type
  ON public.chat_messages (room_id, message_type);