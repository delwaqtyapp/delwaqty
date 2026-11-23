-- 421: Realtime DELETE events carry the deleted row's PK to every subscriber
-- of the supabase_realtime publication (default replica identity; DELETE is
-- not RLS-filtered). INSERT/UPDATE are RLS-filtered, so the leak surface is
-- DELETE on sensitive tables. Client code subscribes only to chat_messages,
-- notifications and orders (verified across lib/ on integration/release10),
-- so every sensitive financial/PII table with no client dependency leaves
-- the publication here. orders stays: the merchant orders page and dashboard
-- depend on it for live refresh; its exposure is limited to order UUIDs on
-- actual deletes, which product flows never perform (cancellation is a
-- status UPDATE). Removing orders is a product decision for the owner.
BEGIN;
ALTER PUBLICATION supabase_realtime DROP TABLE public.wallet_transactions;
ALTER PUBLICATION supabase_realtime DROP TABLE public.wallets;
ALTER PUBLICATION supabase_realtime DROP TABLE public.withdrawal_requests;
ALTER PUBLICATION supabase_realtime DROP TABLE public.driver_earnings;
ALTER PUBLICATION supabase_realtime DROP TABLE public.sanctions;
ALTER PUBLICATION supabase_realtime DROP TABLE public.users;
COMMIT;
