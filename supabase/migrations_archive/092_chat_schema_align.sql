-- 092: Align chat schema with the extended ChatRoom/ChatMessage entities
-- The chat Dart entities (sender admin/provider/customer/driver identity,
-- attachments, admin flags, metadata, room welcome/archive timestamps) send
-- columns that the original 014/015/016 schema never created, so inserts
-- failed silently ("message doesn't send"). This migration adds them.

ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS sender_type text,
  ADD COLUMN IF NOT EXISTS is_from_admin boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS file_url text,
  ADD COLUMN IF NOT EXISTS audio_url text,
  ADD COLUMN IF NOT EXISTS meta_data jsonb;

ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS last_activity timestamptz,
  ADD COLUMN IF NOT EXISTS auto_delete_at timestamptz,
  ADD COLUMN IF NOT EXISTS welcome_message text;

CREATE INDEX IF NOT EXISTS idx_chat_messages_room_created
  ON public.chat_messages (room_id, created_at DESC);