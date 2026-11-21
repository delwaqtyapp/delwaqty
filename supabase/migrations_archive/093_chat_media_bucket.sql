-- 093: Chat media support
-- Extend chat_messages.message_type CHECK to allow video/audio/call/media types
-- and broaden chat_attachments bucket allowed MIME types for media playback.

ALTER TABLE public.chat_messages
  DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;

ALTER TABLE public.chat_messages
  ADD CONSTRAINT chat_messages_message_type_check
  CHECK (message_type = ANY (ARRAY[
    'text',
    'image',
    'file',
    'video',
    'audio',
    'call'
  ]));

UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
  'video/mp4',
  'video/webm',
  'audio/mpeg',
  'audio/mp4',
  'audio/x-m4a',
  'audio/ogg',
  'application/pdf',
  'text/plain'
]
WHERE id = 'chat_attachments';