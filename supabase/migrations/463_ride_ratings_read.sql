-- 463: ride_ratings had a SELECT policy "ratings public read" USING (true) for role public,
-- so anon could read rater_id and comment (0 rows on prod today). The app only upserts
-- ride_ratings (supabase_delivery_data_source.dart rateDelivery), never reads it;
-- "ratings rater rw" (ALL, authenticated, rater_id = auth.uid()) keeps raters able to
-- upsert and see their own row. Replace the public read with an admin read and revoke
-- anon's table SELECT. Re-runnable.
DROP POLICY IF EXISTS "ratings public read" ON public.ride_ratings;
DROP POLICY IF EXISTS "ratings admin read" ON public.ride_ratings;
CREATE POLICY "ratings admin read" ON public.ride_ratings
  FOR SELECT TO authenticated
  USING (public._is_country_admin_uid(auth.uid()));
REVOKE ALL ON public.ride_ratings FROM anon;
