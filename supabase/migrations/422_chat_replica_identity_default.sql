-- 422: prod drifted to REPLICA IDENTITY FULL on the three chat tables
-- (staging has DEFAULT). Under FULL, a realtime DELETE event broadcasts the
-- ENTIRE old row - message content included - to every publication
-- subscriber. DEFAULT still ships the old row's PK, which is all the client
-- needs: supabase_flutter .stream(primaryKey: ...) reconciles DELETE events
-- by PK (chat_messages by id, chat_rooms by id, chat_typing by
-- room_id+user_id), and staging has run DEFAULT all along with the app's
-- chat realtime working. The remaining realtime metadata exposure on the
-- still-published tables (orders, chat_*, notifications) is a known,
-- unverified residual: realtime RLS filtering of DELETE payloads has not
-- been proven with a websocket wire capture (not available in this
-- environment), so it is not claimed as verified.
BEGIN;
ALTER TABLE public.chat_messages REPLICA IDENTITY DEFAULT;
ALTER TABLE public.chat_rooms REPLICA IDENTITY DEFAULT;
ALTER TABLE public.chat_typing REPLICA IDENTITY DEFAULT;
COMMIT;
