-- 462: storage leftovers after the SOS removal and the 2026-11-27 exposure sweep.
-- 1. service-audio-logs: the bucket is empty on prod (0 objects) and nothing in lib/ uses it.
--    Drop its two storage policies ("audio logs upload" is granted to role public, though its
--    WITH CHECK requires an authenticated owner). The empty bucket row is left for a
--    Storage API delete (direct deletes on storage tables are blocked by Supabase).
--    delete-user keeps listing the bucket, which is harmless for an empty bucket.
-- 2. provider-documents: add a 10 MB limit and image/pdf mime types (the app uploads image/jpeg).
-- Not done: the identity-documents policy named "Users delete own identity documents" is really an
-- UPDATE policy (naming only). ALTER POLICY RENAME on storage.objects needs ownership that postgres
-- lacks (42501), so it is left as is.
-- Re-runnable.
DO $$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE '462: storage schema absent, skipping';
    RETURN;
  END IF;
  DROP POLICY IF EXISTS "audio logs upload" ON storage.objects;
  DROP POLICY IF EXISTS "audio logs read" ON storage.objects;
  UPDATE storage.buckets
     SET file_size_limit = 10485760,
         allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','application/pdf']
   WHERE id = 'provider-documents';
END $$;
