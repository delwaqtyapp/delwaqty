-- 178_provider_provisioning_lockdown.sql
-- Bughunt F21 (third pass, HIGH): resolve_my_service_provider auto-provisioned
-- a service_providers row for ANY authenticated caller with
-- is_verified = true, is_available = true, rating = 5.0, hourly_rate = 100.
-- Combined with the public "available providers" SELECT policy
-- (is_available = true), any user became a publicly listed VERIFIED 5-star
-- plumber in one RPC call (live-verified with a test customer).
-- Same shape as F16 (self-serve merchants, fixed in 164): provision the row
-- so app flows keep working, but dormant - unverified, unavailable, no
-- rating - until an admin verifies/activates via the admin RPCs (the column
-- guard already routes those fields through admin paths).

CREATE OR REPLACE FUNCTION public.resolve_my_service_provider()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_sp_id uuid;
  v_user record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_sp_id
    FROM public.service_providers
   WHERE user_id = v_uid
   ORDER BY created_at ASC
   LIMIT 1;

  IF v_sp_id IS NOT NULL THEN
    RETURN v_sp_id;
  END IF;

  SELECT id, full_name, avatar_url, profile_photo_url
    INTO v_user
    FROM public.users
   WHERE id = v_uid;

  IF v_user.id IS NOT NULL THEN
    INSERT INTO public.service_providers (
      user_id, name, category_type, description, profile_image_url,
      rating, rating_count, is_verified, is_available, hourly_rate
    )
    VALUES (
      v_uid,
      COALESCE(NULLIF(btrim(v_user.full_name), ''), 'Delwaqty Provider'),
      'plumbing',
      '',
      COALESCE(v_user.profile_photo_url, v_user.avatar_url),
      NULL,   -- no self-issued rating
      0,
      false,  -- not verified until an admin verifies
      false,  -- not publicly listed until activated
      NULL    -- rate set through the admin RPCs
    )
    RETURNING id INTO v_sp_id;
  END IF;

  RETURN v_sp_id;
END;
$function$;
