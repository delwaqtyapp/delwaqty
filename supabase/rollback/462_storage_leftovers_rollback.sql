-- Rollback 462 (policies restored from the prod definitions captured 2026-11-27).
DO $$
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN RETURN; END IF;
  UPDATE storage.buckets SET file_size_limit = NULL, allowed_mime_types = NULL WHERE id = 'provider-documents';
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND policyname='Users update own identity documents') THEN
    ALTER POLICY "Users update own identity documents" ON storage.objects RENAME TO "Users delete own identity documents";
  END IF;
  DROP POLICY IF EXISTS "audio logs upload" ON storage.objects;
  CREATE POLICY "audio logs upload" ON storage.objects FOR INSERT TO public
    WITH CHECK (bucket_id = 'service-audio-logs' AND auth.role() = 'authenticated' AND (split_part(name,'/',1))::uuid = auth.uid());
  DROP POLICY IF EXISTS "audio logs read" ON storage.objects;
  CREATE POLICY "audio logs read" ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'service-audio-logs' AND (public._storage_doc_admin_scope(public._storage_uuid_segment(name,1),'EMERGENCY_AUDIO') OR public._storage_uuid_segment(name,1) = auth.uid()));
END $$;
