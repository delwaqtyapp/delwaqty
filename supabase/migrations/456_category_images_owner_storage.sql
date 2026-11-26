-- 456: let the platform Owner upload and replace category images.
-- Finding (UI/security review 2026-11-26): the category-images bucket only had
-- INSERT/DELETE policies for auth.role() = 'service_role' and no UPDATE policy,
-- so the Owner's upload from the admin app (user session, upsert) always failed.
-- Fix: replace the two service_role-only policies with Owner-scoped ones, limited
-- to the bucket and the 'categories/' key prefix the client writes. service_role
-- bypasses RLS, so server-side jobs are unaffected. Public read is unchanged.
-- Re-runnable.

DROP POLICY IF EXISTS "Category images admin upload" ON storage.objects;
DROP POLICY IF EXISTS "Category images admin delete" ON storage.objects;
DROP POLICY IF EXISTS "Category images owner insert" ON storage.objects;
DROP POLICY IF EXISTS "Category images owner update" ON storage.objects;
DROP POLICY IF EXISTS "Category images owner delete" ON storage.objects;

CREATE POLICY "Category images owner insert" ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'category-images' AND name LIKE 'categories/%'
              AND public._is_owner_uid(auth.uid()));

CREATE POLICY "Category images owner update" ON storage.objects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (bucket_id = 'category-images' AND name LIKE 'categories/%'
         AND public._is_owner_uid(auth.uid()))
  WITH CHECK (bucket_id = 'category-images' AND name LIKE 'categories/%'
              AND public._is_owner_uid(auth.uid()));

CREATE POLICY "Category images owner delete" ON storage.objects
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (bucket_id = 'category-images' AND name LIKE 'categories/%'
         AND public._is_owner_uid(auth.uid()));
