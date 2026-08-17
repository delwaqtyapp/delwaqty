-- ============================================================
-- 046_profile_registration_roles_language.sql
-- Step 11 — profile + registration (customer/provider/driver)
-- (docs/HANDOFF/STEP_11_PROFILE_REGISTRATION.md).
--
-- Additive + idempotent. Two targeted fixes that unblock the
-- registration role flows and honor the language preference the
-- register wizard already collects.
--
-- Scope (locked design):
--   1. users.user_type CHECK — the app registers merchant and driver
--      roles (UserType enum + 4-role wizard), but migration 020 only
--      allowed ('customer','provider','delivery'). Every merchant/driver
--      sign-up therefore violated the CHECK on insert. Widen to the full
--      role vocabulary that users.role already allows
--      ('customer','merchant','driver','admin','owner','provider','delivery').
--   2. handle_new_user() — the signup trigger hardcoded language='en'.
--      Read the language preference from raw_user_meta_data (the register
--      wizard step 2 collects ar/en) so the profile language survives the
--      email-confirmation path. Backward compatible (defaults to 'en').
--
-- Date of birth is NOT touched here: users.date_of_birth + the
-- users_guard_account_fields trigger + update_member_dob RPC already
-- exist (migration 035) and are granted to authenticated. Step 11 wires
-- the Flutter profile page to update_member_dob.
--
-- Security (035 lessons): REVOKE-before-GRANT; the trigger stays SECURITY
-- DEFINER scoped to public,pg_temp; no new RPCs are added, so no ACL
-- surface changes.
-- ============================================================

-- ─── 1. WIDEN users.user_type CHECK ──────────────────────────────────────

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_user_type_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_user_type_check
  CHECK (
    user_type IN (
      'customer', 'merchant', 'driver', 'provider', 'delivery'
    )
  );

-- ─── 2. handle_new_user: persist language preference ────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
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
  v_language TEXT := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'language', ''),
    'en'
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
    v_language,
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
$function$;

-- ============================================================
-- END 046_profile_registration_roles_language.sql
-- ============================================================
