-- 366: align assign_admin_region with the #35 lookup contract (same defect
-- class): the member drawer passes a member uuid as fallback, but 361's
-- redefinition looked up by email only. Restore email OR uuid OR phone
-- lookup; keep the 361 country-scope gate and _admin_exec_region delegation.
BEGIN;

CREATE OR REPLACE FUNCTION public.assign_admin_region(p_email text, p_region text, p_scope text DEFAULT 'descendants'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_region_id uuid;
BEGIN
  IF NOT public._is_country_admin_uid(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_region IS NULL OR btrim(p_region) = '' THEN
    RAISE EXCEPTION 'Region is required';
  END IF;
  SELECT id INTO v_uid
    FROM public.users
   WHERE lower(email) = lower(btrim(p_email))
      OR id::text = btrim(p_email)
      OR phone = btrim(p_email)
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  SELECT id INTO v_region_id
    FROM public.regions
   WHERE name_ar ILIKE btrim(p_region)
      OR name_en ILIKE btrim(p_region)
   ORDER BY is_active DESC, type = 'governorate' DESC
   LIMIT 1;
  IF v_region_id IS NULL THEN
    RAISE EXCEPTION 'Region not found';
  END IF;

  PERFORM public._admin_exec_region(auth.uid(), v_uid, v_region_id, p_scope);
END;
$function$;

COMMIT;
