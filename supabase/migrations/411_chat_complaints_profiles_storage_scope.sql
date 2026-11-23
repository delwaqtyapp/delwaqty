-- 411: regional + permission scoping for chat_attachments, complaints and
-- profiles storage policies (security finding #112 HIGH), plus the 405
-- follow-up tightening of the audio read policy role.
--
-- Findings:
-- - chat_attachments SELECT/INSERT and complaints SELECT/INSERT carried a
--   global is_admin() bypass (baseline 20023-20051): any active admin could
--   read or add objects in any room/complaint regardless of region.
-- - profiles INSERT/UPDATE/DELETE carried the same bypass on a PUBLIC bucket
--   (avatar vandalism: any admin could overwrite or delete any member's
--   avatar).
-- - 405 follow-up: "audio logs read" was TO public while its helpers are
--   granted to authenticated only; an anonymous caller can never satisfy the
--   policy, so it is retargeted to authenticated (same for the policies
--   touched here — auth.uid()-based branches are unreachable for anon, and
--   this also removes the sources of "permission denied for table
--   complaints/chat_rooms / function" errors that broke anonymous
--   Storage-API list calls).
--
-- Model (same as 405 / 356 / 361 / 362): admin access requires BOTH region
-- scope (_admin_write_scope over _ops_scope_region(...): owner/country
-- global, NULL region owner/country-only, unassigned/suspended denied) AND
-- the matching permission via has_permission:
--   chat_attachments SELECT -> MEMBER_VIEW_CHAT_HISTORY (room region)
--   chat_attachments INSERT -> MEMBER_MODERATE           (room region)
--   complaints      SELECT -> MEMBER_VIEW_COMPLAINTS     (complainant region)
--   complaints      INSERT -> MEMBER_MODERATE            (complainant region)
--   profiles INSERT/UPDATE/DELETE -> MEMBER_MODERATE     (member region)
-- Participant / owner / public-avatar-read paths are unchanged.

BEGIN;

-- ---------- chat_attachments (path: <chat_rooms.id>/<file>) ----------
DROP POLICY IF EXISTS chat_attachments_select_participant ON storage.objects;
CREATE POLICY chat_attachments_select_participant ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'chat_attachments'::text
    AND (
      (public._storage_uuid_segment(name, 1) IN (
        SELECT cr.id FROM public.chat_rooms cr
         WHERE auth.uid() = ANY (cr.participant_ids)))
      OR (
        public._admin_write_scope(public._ops_scope_region((
          SELECT r.region_id FROM public.chat_rooms r
           WHERE r.id = public._storage_uuid_segment(name, 1))))
        AND public.has_permission('MEMBER_VIEW_CHAT_HISTORY',
          public._ops_scope_region((
            SELECT r2.region_id FROM public.chat_rooms r2
             WHERE r2.id = public._storage_uuid_segment(name, 1))))
      )
    )
  );

DROP POLICY IF EXISTS chat_attachments_insert_participant ON storage.objects;
CREATE POLICY chat_attachments_insert_participant ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat_attachments'::text
    AND (
      (public._storage_uuid_segment(name, 1) IN (
        SELECT cr.id FROM public.chat_rooms cr
         WHERE auth.uid() = ANY (cr.participant_ids)))
      OR (
        public._admin_write_scope(public._ops_scope_region((
          SELECT r.region_id FROM public.chat_rooms r
           WHERE r.id = public._storage_uuid_segment(name, 1))))
        AND public.has_permission('MEMBER_MODERATE',
          public._ops_scope_region((
            SELECT r2.region_id FROM public.chat_rooms r2
             WHERE r2.id = public._storage_uuid_segment(name, 1))))
      )
    )
  );

-- ---------- complaints (path: <complaints.id>/<file>) ----------
DROP POLICY IF EXISTS complaints_select_owner ON storage.objects;
CREATE POLICY complaints_select_owner ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    bucket_id = 'complaints'::text
    AND (
      (public._storage_uuid_segment(name, 1) IN (
        SELECT c.id FROM public.complaints c
         WHERE c.complainant_id = auth.uid() OR c.reporter_id = auth.uid()))
      OR public._storage_doc_admin_scope((
        SELECT c2.complainant_id FROM public.complaints c2
         WHERE c2.id = public._storage_uuid_segment(name, 1)),
        'MEMBER_VIEW_COMPLAINTS')
    )
  );

DROP POLICY IF EXISTS complaints_insert_owner ON storage.objects;
CREATE POLICY complaints_insert_owner ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'complaints'::text
    AND (
      (public._storage_uuid_segment(name, 1) IN (
        SELECT c.id FROM public.complaints c
         WHERE c.complainant_id = auth.uid() OR c.reporter_id = auth.uid()))
      OR public._storage_doc_admin_scope((
        SELECT c2.complainant_id FROM public.complaints c2
         WHERE c2.id = public._storage_uuid_segment(name, 1)),
        'MEMBER_MODERATE')
    )
  );

-- ---------- profiles (public bucket; avatars/<uid>/<file>, uid = segment 2) --
-- Read policies (avatars_select_public, "Users ... own avatar") stay public
-- and untouched; only the mutation policies are scoped.
DROP POLICY IF EXISTS profiles_insert_owner ON storage.objects;
CREATE POLICY profiles_insert_owner ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'profiles'::text
    AND (
      (split_part(name, '/'::text, 2))::uuid = auth.uid()
      OR public._storage_doc_admin_scope(
           public._storage_uuid_segment(name, 2), 'MEMBER_MODERATE')
    )
  );

DROP POLICY IF EXISTS profiles_update_owner ON storage.objects;
CREATE POLICY profiles_update_owner ON storage.objects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    bucket_id = 'profiles'::text
    AND (
      (split_part(name, '/'::text, 2))::uuid = auth.uid()
      OR public._storage_doc_admin_scope(
           public._storage_uuid_segment(name, 2), 'MEMBER_MODERATE')
    )
  )
  WITH CHECK (
    bucket_id = 'profiles'::text
    AND (
      (split_part(name, '/'::text, 2))::uuid = auth.uid()
      OR public._storage_doc_admin_scope(
           public._storage_uuid_segment(name, 2), 'MEMBER_MODERATE')
    )
  );

DROP POLICY IF EXISTS profiles_delete_owner ON storage.objects;
CREATE POLICY profiles_delete_owner ON storage.objects
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    bucket_id = 'profiles'::text
    AND (
      (split_part(name, '/'::text, 2))::uuid = auth.uid()
      OR public._storage_doc_admin_scope(
           public._storage_uuid_segment(name, 2), 'MEMBER_MODERATE')
    )
  );

-- ---------- 405 follow-up: audio read policy role ----------
DROP POLICY IF EXISTS "audio logs read" ON storage.objects;
CREATE POLICY "audio logs read" ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
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

-- ---------- 405 follow-up (cont.): topup_proofs role retarget ----------
-- These policies are TO public but their branches all require auth.uid();
-- retargeting to authenticated removes the last "permission denied for
-- function _is_owner_uid" failure that broke anonymous Storage-API list
-- calls on unrelated public buckets. No anonymous caller could ever satisfy
-- them, so behavior for signed-in users is unchanged.
BEGIN;
DROP POLICY IF EXISTS topup_proofs_delete_self_owner ON storage.objects;
CREATE POLICY topup_proofs_delete_self_owner ON storage.objects
  AS PERMISSIVE FOR DELETE TO authenticated
  USING ((bucket_id = 'topup-proofs'::text) AND (((split_part(name, '/'::text, 1))::uuid = auth.uid()) OR public._is_owner_uid(auth.uid())));
DROP POLICY IF EXISTS topup_proofs_insert_self_owner ON storage.objects;
CREATE POLICY topup_proofs_insert_self_owner ON storage.objects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'topup-proofs'::text) AND (((split_part(name, '/'::text, 1))::uuid = auth.uid()) OR public._is_owner_uid(auth.uid())));
DROP POLICY IF EXISTS topup_proofs_select_self_owner ON storage.objects;
CREATE POLICY topup_proofs_select_self_owner ON storage.objects
  AS PERMISSIVE FOR SELECT TO authenticated
  USING ((bucket_id = 'topup-proofs'::text) AND (((split_part(name, '/'::text, 1))::uuid = auth.uid()) OR public._is_owner_uid(auth.uid())));
DROP POLICY IF EXISTS topup_proofs_update_self_owner ON storage.objects;
CREATE POLICY topup_proofs_update_self_owner ON storage.objects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING ((bucket_id = 'topup-proofs'::text) AND (((split_part(name, '/'::text, 1))::uuid = auth.uid()) OR public._is_owner_uid(auth.uid())));
COMMIT;

-- ---------- 405 follow-up (cont.): campaign media anon read ----------
-- "campaign media published read" is TO public BY DESIGN (anonymous viewers
-- of the public campaign-media bucket); grant its helper to anon so the
-- policy can actually evaluate instead of erroring every anonymous
-- Storage-API list. Read-only STABLE function, no new capability beyond the
-- policy's intent.
BEGIN;
GRANT EXECUTE ON FUNCTION public.campaign_published_for_storage(text) TO anon;
COMMIT;
