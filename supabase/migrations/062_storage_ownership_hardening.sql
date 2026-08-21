-- ============================================================================
-- 062_storage_ownership_hardening.sql
-- Fixes the confirmed 🔴 cross-user read vulnerability on the private
-- `complaints` and `chat_attachments` storage buckets.
--
-- Previous policies ("authenticated read from buckets" / "management buckets")
-- allowed ANY authenticated user to SELECT every object in those buckets
-- (no auth.uid() / ownership check), and uploads were unrestricted by path.
--
-- Assumed path convention (standard Supabase pattern, also the contract any
-- future Flutter upload must follow):
--   complaints/{complaint_id}/<file>
--   chat_attachments/{room_id}/<file>
-- No Flutter code currently uploads to these buckets, so this change only
-- tightens the boundary and does not break any existing client flow.
--
-- Additive: drops the over-permissive policies (IF EXISTS) and recreates
-- least-privilege ones. No bucket/payload change.
-- ============================================================================

DROP POLICY IF EXISTS "authenticated read from buckets" ON storage.objects;
DROP POLICY IF EXISTS "authenticated read from management buckets" ON storage.objects;
DROP POLICY IF EXISTS "authenticated upload to complaints" ON storage.objects;
DROP POLICY IF EXISTS "authenticated upload to management buckets" ON storage.objects;

-- SELECT: the complaint owner (complainant/reporter) or an admin
CREATE POLICY "complaints_select_owner" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'complaints' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid IN (
        SELECT id FROM public.complaints
        WHERE complainant_id = auth.uid() OR reporter_id = auth.uid()
      )
    )
  );

-- SELECT: a chat-room participant or an admin
CREATE POLICY "chat_attachments_select_participant" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'chat_attachments' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid IN (
        SELECT id FROM public.chat_rooms
        WHERE auth.uid() = ANY(participant_ids)
      )
    )
  );

-- INSERT (upload): only into a path you own/participate in (path-traversal safe)
CREATE POLICY "complaints_insert_owner" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'complaints' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid IN (
        SELECT id FROM public.complaints
        WHERE complainant_id = auth.uid() OR reporter_id = auth.uid()
      )
    )
  );

CREATE POLICY "chat_attachments_insert_participant" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'chat_attachments' AND (
      public.is_admin()
      OR split_part(name, '/', 1)::uuid IN (
        SELECT id FROM public.chat_rooms
        WHERE auth.uid() = ANY(participant_ids)
      )
    )
  );
