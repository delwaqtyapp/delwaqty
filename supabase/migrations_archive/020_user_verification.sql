-- 020_user_verification.sql
-- Account verification / approval workflow for providers + delivery users.
--
-- New sign-ups pick a user type (customer / provider / delivery). Providers
-- and delivery users must upload an ID card + profile photo and wait for an
-- admin to approve them before they can use the platform. Customers are
-- approved immediately.
--
-- Idempotent and safe to re-run:
--   * adds the verification columns to public.users (existing rows become
--     customer / approved)
--   * extends the users.role CHECK to include 'provider', 'delivery', 'owner'
--   * grants admins SELECT + UPDATE on public.users (verification decisions)
--   * ensures the public `profiles` storage bucket exists + upload policy

-- ============================================================
-- 1. COLUMNS on public.users
--    user_type:          customer (default) | provider | delivery
--    verification_status:approved (default) | pending  | rejected
--    id_card_url / profile_photo_url: document URLs in the profiles bucket
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS user_type TEXT NOT NULL DEFAULT 'customer',
  ADD COLUMN IF NOT EXISTS verification_status TEXT NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS id_card_url TEXT,
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_user_type_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_user_type_check
  CHECK (user_type IN ('customer', 'provider', 'delivery'));

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_verification_status_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_verification_status_check
  CHECK (verification_status IN ('pending', 'approved', 'rejected'));

-- ============================================================
-- 2. ROLE CHECK extension
--    The app persists userType as role for provider/delivery sign-ups, so
--    'provider' and 'delivery' must be allowed; 'owner' already exists in the
--    live DB (migration 006). Constraint name may or may not exist depending
--    on how the schema drifted, so drop + recreate guarded.
-- ============================================================

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_role_check;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.users'::regclass AND conname = 'users_role_check'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_role_check
      CHECK (role IN ('customer', 'merchant', 'driver', 'admin', 'owner', 'provider', 'delivery'));
  END IF;
END
$$;

-- ============================================================
-- 3. ADMIN RLS on public.users
--    Admin (is_admin / is_owner) must list pending verification requests and
--    flip verification_status. Existing own-row policies remain intact.
-- ============================================================

DROP POLICY IF EXISTS "users_select_admin" ON public.users;
DROP POLICY IF EXISTS "users_update_admin" ON public.users;

CREATE POLICY "users_select_admin" ON public.users
  FOR SELECT USING (public.is_admin());

CREATE POLICY "users_update_admin" ON public.users
  FOR UPDATE USING (public.is_admin());

GRANT SELECT, UPDATE ON public.users TO authenticated;

-- ============================================================
-- 4. STORAGE: ensure the public `profiles` bucket exists (used by avatar +
--    verification documents) + an authenticated upload policy.
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profiles', 'profiles', true, 52428800, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "authenticated upload to profiles bucket" ON storage.objects;

CREATE POLICY "authenticated upload to profiles bucket" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND auth.role() = 'authenticated'
  );

-- ============================================================
-- 5. VERIFICATION (optional — run in SQL Editor to inspect final state)
-- ============================================================
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'users'
-- ORDER BY ordinal_position;
--
-- SELECT tablename, policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'users'
-- ORDER BY cmd;
