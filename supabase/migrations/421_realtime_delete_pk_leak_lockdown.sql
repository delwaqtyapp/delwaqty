-- 421: Realtime DELETE events carry the deleted row's PK to every subscriber
-- of the supabase_realtime publication (default replica identity; DELETE is
-- not RLS-filtered). INSERT/UPDATE are RLS-filtered, so the leak surface is
-- DELETE on sensitive tables. Client code subscribes only to chat_messages,
-- notifications and orders (verified across lib/ on integration/release10),
-- so every sensitive financial/PII table with no client dependency leaves
-- the publication here (drops are guarded: a rerun is a no-op). orders
-- stays: the merchant orders page and dashboard depend on it for live
-- refresh; its residual exposure is order UUIDs on actual deletes, which
-- product flows never perform (cancellation is a status UPDATE). Removing
-- orders too is a product decision for the owner (deferred).
--
-- Client DELETE grants, audited live on staging+prod 2026-11-23:
--   orders:         no DELETE policy exists, no client delete path -> revoke
--                   anon + authenticated DELETE (hygiene; RLS already denied).
--   notifications:  "Users delete own notifications" (used by the app's
--                   delete-notification feature) + scoped admins -> keep
--                   authenticated, revoke anon (no matching rows anyway).
--   chat_messages:  scoped-admin delete only -> keep authenticated, revoke
--                   anon.
-- Privileged purge/retention (deletion-request edge function, service_role
-- RPCs) still emit DELETE events for the 3 kept tables. That exposure and
-- the metadata exposure of the kept tables overall is a known, unverified
-- residual: realtime RLS filtering of DELETE payloads has not been proven
-- with a websocket wire capture (not available), so it is not claimed as
-- verified. See 422 for the REPLICA IDENTITY half of this fix.
BEGIN;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['wallet_transactions','wallets','withdrawal_requests','driver_earnings','sanctions','users'] LOOP
    IF EXISTS (SELECT 1 FROM pg_publication_tables
                WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
REVOKE DELETE ON public.orders FROM anon, authenticated;
REVOKE DELETE ON public.notifications FROM anon;
REVOKE DELETE ON public.chat_messages FROM anon;
COMMIT;
