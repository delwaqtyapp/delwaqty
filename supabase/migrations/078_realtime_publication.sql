-- 078: publish realtime tables for the app's Supabase Realtime channels.
-- The app subscribes to postgres changes on these tables (profileUpdates -> users,
-- providerOrders/merchant orders -> orders, driverOffers -> offers, trustedContacts,
-- merchantReviews -> reviews, inventoryUpdates -> product_inventory,
-- driverDispatch -> order_dispatch, adminFinancial -> wallet_transactions,
-- activeDelivery -> order_tracking). Without them in the publication, subscriptions
-- fail with channelError (RealtimeSubscribeException).
-- Idempotent: only adds tables currently missing from the publication.
do $$
declare t text;
begin
  foreach t in array array[
    'users', 'orders', 'offers', 'trusted_contacts', 'reviews',
    'product_inventory', 'order_dispatch', 'wallet_transactions', 'order_tracking'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
