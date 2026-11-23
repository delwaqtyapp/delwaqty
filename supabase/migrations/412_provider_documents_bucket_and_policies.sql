-- 412: provider-documents bucket + policies (functional finding #113) and
-- get_driver_documents dead admin branch cleanup.
--
-- #113: the provider app uploads/replaces verification documents at
-- provider_documents/<uid>/<name> (uid = path segment 2) with
-- uploadBinary(upsert: true) and reads them through 3600s signed URLs, but
-- the bucket had NO storage.objects policies (fail-closed) and did not even
-- exist on prod. This migration:
--   - creates the bucket privately (public = false), idempotently;
--   - adds owner INSERT + UPDATE + SELECT scoped to segment 2 = auth.uid()
--     (covers upload, upsert-replace and createSignedUrl);
--   - adds a scoped document-reviewer SELECT: region scope over the member
--     + explicit MEMBER_VIEW_DOCUMENTS grant (same model as 405/411).
--   No DELETE policy on purpose: the app removes document metadata via the
--   provider_delete_document RPC only; Storage object orphan cleanup is a
--   separate design and is not silently widened here.
--
-- get_driver_documents: its admin branch called
-- admin_has_permission('DRIVER_DOCUMENT_VIEW', NULL) — the key is absent
-- from _valid_permission (always false) and a NULL region skips the
-- geographic gate. Re-keyed to DRIVER_VERIFY and region-scoped over the
-- driver's member region (owner and the driver's own user unchanged).

BEGIN;

-- ---------- bucket (idempotent, private) ----------
INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-documents', 'provider-documents', false)
ON CONFLICT (id) DO NOTHING;
-- Never let this bucket become public even if it pre-existed otherwise.
UPDATE storage.buckets SET public = false WHERE id = 'provider-documents' AND public IS DISTINCT FROM false;

-- ---------- policies (path: provider_documents/<uid>/<name>, uid segment 2) ----------
DROP POLICY IF EXISTS provider_documents_insert_owner ON storage.objects;
CREATE POLICY provider_documents_insert_owner ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'provider-documents'::text
    AND public._storage_uuid_segment(name, 2) = auth.uid()
  );

DROP POLICY IF EXISTS provider_documents_update_owner ON storage.objects;
CREATE POLICY provider_documents_update_owner ON storage.objects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    bucket_id = 'provider-documents'::text
    AND public._storage_uuid_segment(name, 2) = auth.uid()
  )
  WITH CHECK (
    bucket_id = 'provider-documents'::text
    AND public._storage_uuid_segment(name, 2) = auth.uid()
  );

DROP POLICY IF EXISTS provider_documents_select_owner ON storage.objects;
CREATE POLICY provider_documents_select_owner ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'provider-documents'::text
    AND public._storage_uuid_segment(name, 2) = auth.uid()
  );

DROP POLICY IF EXISTS provider_documents_select_reviewer ON storage.objects;
CREATE POLICY provider_documents_select_reviewer ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'provider-documents'::text
    AND public._storage_doc_admin_scope(
          public._storage_uuid_segment(name, 2),
          'MEMBER_VIEW_DOCUMENTS')
  );

-- ---------- get_driver_documents cleanup ----------
CREATE OR REPLACE FUNCTION public.get_driver_documents(p_driver_id uuid)
 RETURNS SETOF driver_documents
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT * FROM driver_documents
  WHERE driver_id = p_driver_id
    AND (EXISTS (
      SELECT 1 FROM public.drivers d
       WHERE d.id = p_driver_id AND d.user_id = auth.uid()
    ) OR public._is_owner_uid(auth.uid())
    OR (
      public._admin_write_scope(public._ops_scope_region(
        public._member_region_id((SELECT d2.user_id FROM public.drivers d2 WHERE d2.id = p_driver_id))))
      AND public.has_permission('DRIVER_VERIFY', public._ops_scope_region(
        public._member_region_id((SELECT d3.user_id FROM public.drivers d3 WHERE d3.id = p_driver_id))))
    ))
  ORDER BY created_at DESC;
$function$;

COMMIT;
