-- ============================================================================
-- 075_topup_proof_storage.sql
-- Additive PRIVATE storage for top-up transfer-proof images (Sprint 120).
-- No public read. Proofs are sensitive financial documents: only the owning
-- account and platform admins (incl. Owner) may read them. Regional scoping of
-- WHICH proofs an admin fetches is enforced at the application layer via
-- list_region_topup_requests / region-scoped RPCs; storage RLS only gates raw
-- object access. Object path: "topup-proofs/<userId>/<file>".
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('topup-proofs', 'topup-proofs', false, 10485760,
        ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "topup_proofs_select_authorized" ON storage.objects;
CREATE POLICY "topup_proofs_select_authorized" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'topup-proofs' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "topup_proofs_insert_authorized" ON storage.objects;
CREATE POLICY "topup_proofs_insert_authorized" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'topup-proofs' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "topup_proofs_update_authorized" ON storage.objects;
CREATE POLICY "topup_proofs_update_authorized" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'topup-proofs' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "topup_proofs_delete_authorized" ON storage.objects;
CREATE POLICY "topup_proofs_delete_authorized" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'topup-proofs' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid = auth.uid()
    )
  );
