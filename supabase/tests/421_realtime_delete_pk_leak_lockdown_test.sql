-- 421 regression: sensitive tables out of the realtime publication; client
-- dependencies (chat_messages, notifications, orders) stay in; DELETE grants
-- tightened per the audit in the migration header. Two-identity RLS proof:
-- user B cannot delete user A's notification (policy-scoped delete).
BEGIN;
DO $$
DECLARE
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
    AND tablename IN ('wallet_transactions','wallets','withdrawal_requests','driver_earnings','sanctions','users')),
    '421: sensitive table still published';
  ASSERT (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime'
    AND tablename IN ('chat_messages','notifications','orders')) = 3,
    '421: client realtime dependency dropped';
  ASSERT NOT has_table_privilege('authenticated','public.orders','DELETE')
     AND NOT has_table_privilege('anon','public.orders','DELETE'), '421: orders DELETE grant remains';
  ASSERT NOT has_table_privilege('anon','public.notifications','DELETE')
     AND NOT has_table_privilege('anon','public.chat_messages','DELETE'), '421: anon DELETE grant remains';
  ASSERT has_table_privilege('authenticated','public.notifications','DELETE')
     AND has_table_privilege('authenticated','public.chat_messages','DELETE'), '421: policy-scoped client delete broke';
  -- two identities: B's delete on A's notification affects 0 rows (RLS), and
  -- A's own delete passes the policy
  INSERT INTO auth.users(id,email) VALUES (a,a::text||'@x.i'),(b,b::text||'@x.i');
  INSERT INTO public.users(id,email,role) VALUES (a,a::text||'@x.i','customer'),(b,b::text||'@x.i','customer') ON CONFLICT(id) DO NOTHING;
  INSERT INTO public.notifications(user_id,title,body,type) VALUES (a,'421','probe','system');
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', b::text, true);
  DELETE FROM public.notifications WHERE user_id = a AND title = '421';
  PERFORM set_config('role','none',true);
  ASSERT EXISTS (SELECT 1 FROM public.notifications WHERE user_id=a AND title='421'), '421: B deleted A notification';
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', a::text, true);
  DELETE FROM public.notifications WHERE user_id = a AND title = '421';
  PERFORM set_config('role','none',true);
  ASSERT NOT EXISTS (SELECT 1 FROM public.notifications WHERE user_id=a AND title='421'), '421: A could not delete own notification';
END $$;
SELECT '421 assertions passed' AS result;
ROLLBACK;
