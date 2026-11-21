-- 211: Security L2 + L3.
-- L2: verification-doc policies on the PUBLIC profiles bucket are dead
-- leftovers (uploads go to the private identity-documents bucket; zero
-- objects under profiles/verification/). Drop them.
DROP POLICY IF EXISTS "verification_docs_select_owner" ON storage.objects;
DROP POLICY IF EXISTS "verification_docs_select_admin" ON storage.objects;

-- L3: ride_pricing was publicly readable; no anonymous client reads it.
DROP POLICY IF EXISTS "pricing public read" ON public.ride_pricing;
CREATE POLICY "pricing read signed-in"
  ON public.ride_pricing FOR SELECT TO authenticated USING (true);

NOTIFY pgrst, 'reload schema';
