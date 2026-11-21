-- 174_inventory_anon_read_lockdown.sql
-- Bughunt F10: product_inventory was world-readable anonymously (stock,
-- reserved, thresholds for every merchant). Both shipped apps read it only
-- AFTER login (customer menu and merchant stock screens run authenticated),
-- and an identical authenticated SELECT policy exists, so the least
-- disruptive fix is dropping the public (anon) policy. Authenticated reads
-- are unchanged.

DROP POLICY IF EXISTS inventory_select_public ON public.product_inventory;
