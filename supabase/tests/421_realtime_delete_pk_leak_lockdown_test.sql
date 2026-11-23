-- 421 regression: sensitive tables out of the realtime publication; client
-- dependencies (chat_messages, notifications, orders) stay in.
BEGIN;
DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
    AND tablename IN ('wallet_transactions','wallets','withdrawal_requests','driver_earnings','sanctions','users')),
    '421: sensitive table still published';
  ASSERT (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime'
    AND tablename IN ('chat_messages','notifications','orders')) = 3,
    '421: client realtime dependency dropped';
END $$;
SELECT '421 assertions passed' AS result;
ROLLBACK;
