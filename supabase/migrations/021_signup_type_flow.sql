-- 021_signup_type_flow.sql
-- Route sign-up metadata into the profile row.
--
-- With email confirmations ENABLED the client has no session at sign-up time,
-- so the profile row is created entirely by the handle_new_user() trigger. The
-- old trigger hardcoded role = 'customer', which collapsed provider / delivery
-- registrations into customers. This migration:
--   1. rewrites the trigger to copy user_type + verification_status from
--      auth.users.raw_user_meta_data (written by the client at sign-up)
--   2. re-runs the backfill for orphaned auth users
--   3. reconciles previously-broken rows (still 'customer' in user_type but
--      registered as provider / delivery) so existing test accounts line up
--   4. preserves the owner account role
--
-- NOTE: matches the LIVE schema, which has full_name but no name column.
-- Idempotent and safe to re-run.

-- ============================================================
-- 1. TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_user_type TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'user_type', ''),
    'customer'
  );
  v_verification TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'verification_status', ''),
    CASE WHEN v_user_type = 'customer' THEN 'approved' ELSE 'pending' END
  );
  v_full_name TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
    'User'
  );
BEGIN
  INSERT INTO public.users (
    id, email, full_name, phone, language, is_onboarded,
    role, user_type, verification_status, created_at, updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_full_name,
    NEW.phone,
    'en',
    false,
    v_user_type,
    v_user_type,
    v_verification,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. BACKFILL orphaned auth users (no profile row yet)
-- ============================================================

INSERT INTO public.users (
  id, email, full_name, phone, language, is_onboarded,
  role, user_type, verification_status, created_at, updated_at
)
SELECT
  au.id,
  COALESCE(au.email, ''),
  COALESCE(NULLIF(au.raw_user_meta_data->>'full_name', ''), 'User'),
  au.phone,
  'en',
  false,
  COALESCE(NULLIF(au.raw_user_meta_data->>'user_type', ''), 'customer'),
  COALESCE(NULLIF(au.raw_user_meta_data->>'user_type', ''), 'customer'),
  COALESCE(
    NULLIF(au.raw_user_meta_data->>'verification_status', ''),
    CASE
      WHEN COALESCE(NULLIF(au.raw_user_meta_data->>'user_type', ''), 'customer') = 'customer'
      THEN 'approved' ELSE 'pending'
    END
  ),
  au.created_at,
  NOW()
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. RECONCILE rows created by the old trigger
--    Only fixes rows that still read as a plain customer while auth metadata
--    says provider / delivery. Never touches rows an admin already approved
--    (those already have user_type = provider / delivery).
-- ============================================================

UPDATE public.users pu
SET
  role = m.meta_user_type,
  user_type = m.meta_user_type,
  verification_status = COALESCE(
    NULLIF(au.raw_user_meta_data->>'verification_status', ''),
    'pending'
  ),
  updated_at = NOW()
FROM auth.users au,
LATERAL (
  SELECT COALESCE(NULLIF(au.raw_user_meta_data->>'user_type', ''), '') AS meta_user_type
) m
WHERE au.id = pu.id
  AND m.meta_user_type IN ('provider', 'delivery')
  AND pu.user_type = 'customer';

-- ============================================================
-- 4. PRESERVE the owner account
-- ============================================================

UPDATE public.users SET role = 'owner' WHERE email = 'said.3pkarino@gmail.com';
