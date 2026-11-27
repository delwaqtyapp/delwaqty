DROP POLICY IF EXISTS "ratings admin read" ON public.ride_ratings;
DROP POLICY IF EXISTS "ratings public read" ON public.ride_ratings;
CREATE POLICY "ratings public read" ON public.ride_ratings FOR SELECT TO public USING (true);
GRANT SELECT ON public.ride_ratings TO anon;
