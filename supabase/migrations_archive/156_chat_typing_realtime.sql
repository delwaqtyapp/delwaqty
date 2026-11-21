-- Migration 156: put chat_typing on the realtime publication.
-- Audit finding: the support-chat typing indicator subscribes to a
-- .stream(primaryKey: ['room_id','user_id']) on chat_typing, but the table
-- was never added to supabase_realtime, so typing updates never arrive.
-- PK (room_id, user_id) gives realtime a replica identity; no other change.

ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_typing;
