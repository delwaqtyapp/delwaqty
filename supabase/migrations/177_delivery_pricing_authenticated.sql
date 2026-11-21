-- 177_delivery_pricing_authenticated.sql
-- Bughunt F20 (second pass): delivery_pricing (base fees, per-km/per-kg
-- rates, multipliers for every service type) was world-readable anonymously
-- - competitor intel. The customer app reads the table post-login, and the
-- estimate_delivery_fee RPC is already authenticated-only, so anon access
-- serves no shipped flow. Restrict SELECT to authenticated.

DROP POLICY IF EXISTS "delivery pricing public read" ON public.delivery_pricing;
CREATE POLICY "delivery pricing authenticated read"
  ON public.delivery_pricing FOR SELECT
  TO authenticated
  USING (true);
