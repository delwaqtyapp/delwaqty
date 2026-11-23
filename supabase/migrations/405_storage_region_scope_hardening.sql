-- 405: regional storage policy hardening (code-review finding #107 HIGH).
--
-- The storage.objects policies for identity-documents, driver-documents and
-- service-audio-logs carried global admin bypasses: _is_active_admin_uid /
-- is_admin() only check that the caller is an active admin. A regional admin
-- denied a foreign member's row by the scoped table policies (356/361/362)
-- could still list, read, overwrite or delete that member's storage objects
-- directly.
--
-- Model (matches 356/361/362): admin access to an object now requires BOTH
--   1. region scope over the object owner's member region:
--      _admin_write_scope(_ops_scope_region(_member_region_id(uid))) —
--      owner and country-level admins stay global, a NULL member region is
--      covered by owner/country only, unassigned or suspended admins get
--      nothing; AND
--   2. the matching explicit permission grant via has_permission:
--        identity-documents -> MEMBER_VIEW_DOCUMENTS
--        driver-documents   -> DRIVER_VERIFY
--        service-audio-logs -> EMERGENCY_AUDIO
--      (DRIVER_DOCUMENT_VIEW would be the literal key but is absent from the
--      current _valid_permission vocabulary, so has_permission would always
--      deny it; DRIVER_VERIFY is the valid, explicit-grant-only key for the
--      driver document review flow.)
--      (all three sit outside the default in-scope matrix in 361's
--      has_permission, so they require an explicit grant from the owner or a
--      supervising admin — sensitive documents stay opt-in per admin.)
--
-- Member/owner flows are unchanged: users read, upload, replace and delete
-- only their own objects, drivers their own driver documents.
-- All three buckets verified private (storage.buckets.public = false) on
-- staging before this migration; signed URLs remain the only read path.

BEGIN;

-- ---------- helpers ----------

-- Safe uuid extraction from an object path segment: returns NULL instead of
-- raising when the segment is missing or not a uuid, so policy evaluation
-- fails closed instead of erroring the whole statement.
CREATE OR REPLACE FUNCTION public._storage_uuid_segment(p_name text, p_idx integer)
 RETURNS uuid
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN split_part(p_name, '/', p_idx) ~
         '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    THEN split_part(p_name, '/', p_idx)::uuid
  END;
$function$;

-- Region + permission gate for admin access to a member-owned storage object.
CREATE OR REPLACE FUNCTION public._storage_doc_admin_scope(p_member_id uuid, p_permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_member_id IS NOT NULL
     AND public._admin_write_scope(
           public._ops_scope_region(public._member_region_id(p_member_id)))
     AND public.has_permission(
           p_permission,
           public._ops_scope_region(public._member_region_id(p_member_id)));
$function$;

-- Policies evaluate as the querying user, so these must stay executable by
-- authenticated (same treatment as 356/362's policy helpers).
GRANT EXECUTE ON FUNCTION public._storage_uuid_segment(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public._storage_doc_admin_scope(uuid, text) TO authenticated;

-- ---------- identity-documents (path: <user uid>/<folder>/<file>) ----------
-- Owner policies ("Users read/upload/delete own identity documents") are
-- untouched: the first path segment stays the owner's auth uid. Only the
-- global admin read is replaced.

DROP POLICY IF EXISTS "Admins read all identity documents" ON storage.objects;
DROP POLICY IF EXISTS identity_documents_admin_scoped_read ON storage.objects;
CREATE POLICY identity_documents_admin_scoped_read ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'identity-documents'::text
    AND public._storage_doc_admin_scope(
          public._storage_uuid_segment(name, 1),
          'MEMBER_VIEW_DOCUMENTS')
  );

-- ---------- driver-documents (path: <folder>/<drivers.id>/<file>) ----------
-- Each policy keeps its owner branches (segment 2 = caller uid, or the
-- referenced driver row belongs to the caller) and replaces the bare
-- is_admin() bypass with the region+permission gate resolved through the
-- driver row's member (drivers.user_id).

DROP POLICY IF EXISTS driver_documents_select_owner ON storage.objects;
CREATE POLICY driver_documents_select_owner ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'driver-documents'::text
    AND (
      public._storage_doc_admin_scope(
        (SELECT d.user_id FROM public.drivers d
          WHERE d.id = public._storage_uuid_segment(name, 2)),
        'DRIVER_VERIFY')
      OR split_part(name, '/'::text, 2) = (auth.uid())::text
      OR EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = auth.uid()
           AND (d.id)::text = split_part(name, '/'::text, 2))
    )
  );

DROP POLICY IF EXISTS driver_documents_insert_owner ON storage.objects;
CREATE POLICY driver_documents_insert_owner ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'driver-documents'::text
    AND (
      public._storage_doc_admin_scope(
        (SELECT d.user_id FROM public.drivers d
          WHERE d.id = public._storage_uuid_segment(name, 2)),
        'DRIVER_VERIFY')
      OR split_part(name, '/'::text, 2) = (auth.uid())::text
      OR EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = auth.uid()
           AND (d.id)::text = split_part(name, '/'::text, 2))
    )
  );

DROP POLICY IF EXISTS driver_documents_update_owner ON storage.objects;
CREATE POLICY driver_documents_update_owner ON storage.objects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    bucket_id = 'driver-documents'::text
    AND (
      public._storage_doc_admin_scope(
        (SELECT d.user_id FROM public.drivers d
          WHERE d.id = public._storage_uuid_segment(name, 2)),
        'DRIVER_VERIFY')
      OR split_part(name, '/'::text, 2) = (auth.uid())::text
      OR EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = auth.uid()
           AND (d.id)::text = split_part(name, '/'::text, 2))
    )
  )
  WITH CHECK (
    bucket_id = 'driver-documents'::text
    AND (
      public._storage_doc_admin_scope(
        (SELECT d.user_id FROM public.drivers d
          WHERE d.id = public._storage_uuid_segment(name, 2)),
        'DRIVER_VERIFY')
      OR split_part(name, '/'::text, 2) = (auth.uid())::text
      OR EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = auth.uid()
           AND (d.id)::text = split_part(name, '/'::text, 2))
    )
  );

DROP POLICY IF EXISTS driver_documents_delete_owner ON storage.objects;
CREATE POLICY driver_documents_delete_owner ON storage.objects
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    bucket_id = 'driver-documents'::text
    AND (
      public._storage_doc_admin_scope(
        (SELECT d.user_id FROM public.drivers d
          WHERE d.id = public._storage_uuid_segment(name, 2)),
        'DRIVER_VERIFY')
      OR split_part(name, '/'::text, 2) = (auth.uid())::text
      OR EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.user_id = auth.uid()
           AND (d.id)::text = split_part(name, '/'::text, 2))
    )
  );

-- ---------- service-audio-logs (path: <member uid>/<file>) ----------
-- "audio logs upload" is already owner-only (segment 1 = caller uid) and is
-- unchanged. The read policy's is_admin() / _is_owner_uid branches collapse
-- into the scoped gate (has_permission already returns true for the owner,
-- keeping the owner global).

DROP POLICY IF EXISTS "audio logs read" ON storage.objects;
CREATE POLICY "audio logs read" ON storage.objects
  AS PERMISSIVE FOR SELECT TO public
  USING (
    bucket_id = 'service-audio-logs'::text
    AND (
      public._storage_doc_admin_scope(
        public._storage_uuid_segment(name, 1),
        'EMERGENCY_AUDIO')
      OR public._storage_uuid_segment(name, 1) = auth.uid()
    )
  );

COMMIT;
