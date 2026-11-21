-- ============================================================================
-- 070_provider_documents_storage.sql
-- Additive private storage for provider documents (PHASE 5 companion to 069).
-- Mirrors the driver-documents storage hardening in 064, but provider-owned via
-- auth.uid() (providers are users; path "provider_documents/<userId>/<file>").
-- No public read. Owner + admin scoped. Adds provider_delete_document RPC.
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('provider-documents', 'provider-documents', false, 10485760,
        ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "provider_documents_select_owner" ON storage.objects;
CREATE POLICY "provider_documents_select_owner" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'provider-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "provider_documents_insert_owner" ON storage.objects;
CREATE POLICY "provider_documents_insert_owner" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'provider-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "provider_documents_update_owner" ON storage.objects;
CREATE POLICY "provider_documents_update_owner" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'provider-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "provider_documents_delete_owner" ON storage.objects;
CREATE POLICY "provider_documents_delete_owner" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'provider-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

-- ─── DELETE RPC (owner-only) ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.provider_delete_document(p_doc_type text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.provider_documents
    WHERE provider_id = v_uid AND doc_type = p_doc_type;
END;
$$;

REVOKE ALL ON FUNCTION public.provider_delete_document(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_delete_document(text) TO authenticated;
