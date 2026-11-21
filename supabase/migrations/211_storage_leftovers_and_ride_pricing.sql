-- 211: Security L2 + L3.
-- L2: verification-doc policies on the PUBLIC profiles bucket are dead
-- leftovers (uploads go to the private identity-documents bucket; zero
-- objects under profiles/verification/). Drop them.
DROP POLICY IF EXISTS "verification_docs_select_owner" ON storage.objects;
DROP POLICY IF EXISTS "verification_docs_select_admin" ON storage.objects;

-- L3: ride_pricing was publicly readable; no anonymous client reads it.
DROP POLICY IF EXISTS "pricing public read" ON public.ride_pricing;
-- Table has no client grants at all (server-only via definer RPCs); the old
-- "public read" policy was decorative. Leave it grantless.

NOTIFY pgrst, 'reload schema';
