-- ============================================================================
-- 064_storage_docs_profiles_and_commission_region.sql
-- Safe, additive hardening.
--
-- A) driver-documents bucket + least-privilege policies.
--    The Flutter app uploads driver license/vehicle docs to the
--    'driver-documents' bucket (path "driver_licenses/<userId>/..."), but NO
--    bucket creation or storage policy for it exists in any migration. This
--    adds the bucket (idempotent) and owner/admin-scoped policies so uploads
--    actually work and no cross-driver leakage occurs.
--    Path convention: "<folder>/<userId>/<file>" -> owner = segment 2.
--
-- B) profiles bucket upload hardening.
--    Existing policy allowed ANY authenticated user to upload into ANY path
--    (avatar overwrite risk). Path convention: "avatars/<userId>/..." or
--    "<folder>/<userId>/..." -> owner = segment 2. Tighten INSERT/UPDATE/
--    DELETE to the owning user (admins still allowed). Public read unchanged.
--
-- C) Per-account commission region scope.
--    set_commission_rate gains a region check for entity_type='account': the
--    target user's region (user_region_preferences) must be within the
--    caller's authorized scope (_region_in_scope). Global rules
--    (account_type/service_type/service_category) remain platform-wide,
--    gated by PLATFORM_REVENUE. No historical data touched.
-- ============================================================================

-- ---------- A) driver-documents bucket + policies ----------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('driver-documents', 'driver-documents', false, 10485760,
        ARRAY['image/png','image/jpeg','image/webp','application/pdf'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "driver_documents_select_owner" ON storage.objects;
CREATE POLICY "driver_documents_select_owner" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'driver-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid IN (
        SELECT id FROM public.drivers WHERE user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "driver_documents_insert_owner" ON storage.objects;
CREATE POLICY "driver_documents_insert_owner" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'driver-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid IN (
        SELECT id FROM public.drivers WHERE user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "driver_documents_update_owner" ON storage.objects;
CREATE POLICY "driver_documents_update_owner" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'driver-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid IN (
        SELECT id FROM public.drivers WHERE user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS "driver_documents_delete_owner" ON storage.objects;
CREATE POLICY "driver_documents_delete_owner" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'driver-documents' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid IN (
        SELECT id FROM public.drivers WHERE user_id = auth.uid()
      )
    )
  );

-- ---------- B) profiles upload owner-scoping ----------
DROP POLICY IF EXISTS "authenticated upload to profiles bucket" ON storage.objects;
CREATE POLICY "profiles_insert_owner" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "profiles_update_owner" ON storage.objects;
CREATE POLICY "profiles_update_owner" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'profiles' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

DROP POLICY IF EXISTS "profiles_delete_owner" ON storage.objects;
CREATE POLICY "profiles_delete_owner" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'profiles' AND (
      public.is_admin()
      OR split_part(name, '/', 2)::uuid = auth.uid()
    )
  );

-- ---------- C) per-account commission region scope ----------
CREATE OR REPLACE FUNCTION public.set_commission_rate(
  p_entity_type text,
  p_entity_key text,
  p_rate numeric,
  p_effective_from date DEFAULT CURRENT_DATE,
  p_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
  v_current_id uuid;
  v_current_from date;
  v_old_to date;
  v_region uuid;
BEGIN
  IF NOT public.has_permission('PLATFORM_REVENUE', NULL) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_entity_type NOT IN ('account', 'account_type', 'service_type', 'service_category') THEN
    RAISE EXCEPTION 'Invalid entity type';
  END IF;
  IF p_entity_key IS NULL OR btrim(p_entity_key) = '' THEN
    RAISE EXCEPTION 'Entity key is required';
  END IF;
  IF p_rate IS NULL OR p_rate < 0 OR p_rate > 100 THEN
    RAISE EXCEPTION 'Rate must be between 0 and 100';
  END IF;

  -- Regional scope: a per-account override may only target a user whose
  -- region is within the caller's authorized scope. Global rules
  -- (account_type/service_type/service_category) are platform-wide.
  IF p_entity_type = 'account' THEN
    SELECT urp.region_id INTO v_region
      FROM public.user_region_preferences urp
     WHERE urp.user_id = p_entity_key::uuid
     LIMIT 1;
    IF v_region IS NOT NULL AND NOT public._region_in_scope(auth.uid(), v_region) THEN
      RAISE EXCEPTION 'Outside authorized region';
    END IF;
  END IF;

  p_effective_from := COALESCE(p_effective_from, CURRENT_DATE);

  SELECT c.id, c.effective_from INTO v_current_id, v_current_from
    FROM public.commission_rules c
   WHERE c.entity_type = p_entity_type
     AND c.entity_key = p_entity_key
     AND c.is_active
   ORDER BY c.effective_from DESC, c.created_at DESC
   LIMIT 1;

  IF v_current_id IS NOT NULL THEN
    v_old_to := GREATEST(v_current_from, p_effective_from);
    UPDATE public.commission_rules
       SET is_active = false,
           effective_to = v_old_to,
           updated_at = now()
     WHERE id = v_current_id;
  END IF;

  INSERT INTO public.commission_rules
    (entity_type, entity_key, rate, currency, effective_from,
     is_active, description, created_by, approved_by)
  VALUES (
    p_entity_type, p_entity_key, p_rate, 'SAR', p_effective_from,
    p_effective_from <= CURRENT_DATE,
    p_description, auth.uid(), auth.uid()
  )
  RETURNING id INTO v_new_id;

  PERFORM public.write_audit(
    'COMMISSION_RATE_CHANGED', 'commission_rules', v_new_id::text,
    jsonb_build_object('entity_type', p_entity_type,
                       'entity_key', p_entity_key,
                       'rate', p_rate,
                       'effective_from', p_effective_from,
                       'description', p_description));

  RETURN v_new_id;
END;
$$;
