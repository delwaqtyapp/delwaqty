-- 422 regression: chat tables run REPLICA IDENTITY DEFAULT so DELETE events
-- carry only the PK, and chat_messages stays in the publication.
BEGIN;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname='public' AND c.relname IN ('chat_messages','chat_rooms','chat_typing')
             AND c.relreplident = 'd') = 3,
    '422: a chat table is not REPLICA IDENTITY DEFAULT';
  ASSERT EXISTS (SELECT 1 FROM pg_publication_tables
                  WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='chat_messages'),
    '422: chat_messages fell out of the publication';
END $$;
SELECT '422 assertions passed' AS result;
ROLLBACK;
