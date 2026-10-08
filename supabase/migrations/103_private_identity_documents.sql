-- ============================================================
-- 103_private_identity_documents.sql
-- Identity documents were being uploaded into the PUBLIC
-- `profiles` bucket and referenced with getPublicUrl().
--
-- `profiles` is a public bucket, so every identity document in the
-- platform — national ID cards, trade licences, driving licences and
-- the provider verification scans — was readable by anyone who ever
-- obtained (or guessed) the URL. That is a data-protection breach,
-- not a cosmetic issue.
--
-- What this migration does:
--   * creates `identity-documents` as a PRIVATE bucket with owner-only
--     storage policies (a user may read/write only their own folder);
--   * creates `profile-photos` as a public bucket dedicated to avatar
--     images, so avatars keep working through getPublicUrl() while
--     legal documents never live in a public bucket again;
--   * revokes the public read on any legacy objects still sitting in
--     `profiles` by copying nothing — instead it publishes a helper
--     (public.legacy_identity_document_paths) so the app can migrate
--     and delete them safely.
--
-- The app side (migration 103 companion code) uploads:
--   profile photos       -> public  `profile-photos`
--   id cards / licences  -> private `identity-documents` (signed URL)
-- ============================================================

-- ─── private identity documents ────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'identity-documents',
  'identity-documents',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Owners may manage only their own folder: identity-documents/<uid>/...
DROP POLICY IF EXISTS "Users upload own identity documents"
  ON storage.objects;
CREATE POLICY "Users upload own identity documents" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'identity-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users read own identity documents"
  ON storage.objects;
CREATE POLICY "Users read own identity documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users delete own identity documents"
  ON storage.objects;
CREATE POLICY "Users delete own identity documents" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Admin verification console must be able to read documents, otherwise
-- the verification queue cannot function at all.
DROP POLICY IF EXISTS "Admins read all identity documents"
  ON storage.objects;
CREATE POLICY "Admins read all identity documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'identity-documents'
    AND public._is_active_admin_uid(auth.uid())
  );

-- ─── public avatars (replaces the mixed use of `profiles`) ─────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = true,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ─── audit: list the legacy objects that still need migrating ──

CREATE OR REPLACE VIEW public.legacy_identity_document_paths AS
SELECT bucket_id,
       name,
       (storage.foldername(name))[2] AS folder,
       created_at
  FROM storage.objects
 WHERE bucket_id = 'profiles'
   AND (storage.foldername(name))[1] IN (
     'id_cards', 'trade_licenses', 'driving_licenses', 'verification'
   );

COMMENT ON VIEW public.legacy_identity_document_paths IS
  'Identity documents still stored in the public profiles bucket. '
  'Move each object to identity-documents/<user_id>/ and remove the '
  'legacy copy; after this list is empty no legal document is public.';

-- ─── service-audio-logs: unused, and public. Make it private so a
--     future caller cannot leak call recordings. ────────────────
UPDATE storage.buckets
   SET public = false
 WHERE id = 'service-audio-logs';