-- Driver verification and private document custody. No existing driver is
-- downgraded; self-service registration no longer grants admin verification.
BEGIN;

CREATE OR REPLACE FUNCTION public.driver_complete_registration(p_full_name text, p_phone text DEFAULT NULL::text, p_vehicle_type text DEFAULT NULL::text, p_vehicle_plate text DEFAULT NULL::text, p_vehicle_color text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_vehicle uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_full_name IS NULL OR btrim(p_full_name) = '' THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  SELECT id INTO v_driver FROM public.drivers WHERE user_id = v_uid LIMIT 1;

  IF v_driver IS NULL THEN
    INSERT INTO public.drivers
      (user_id, full_name, phone, vehicle_type, vehicle_plate,
       vehicle_color, status, is_online, is_active, is_verified,
       verification_status, onboarding_step, created_at, updated_at)
    VALUES
      (v_uid, btrim(p_full_name), p_phone, p_vehicle_type, p_vehicle_plate,
       p_vehicle_color, 'offline', false, true, false, 'pending', 1,
       now(), now())
    RETURNING id INTO v_driver;
  ELSE
    UPDATE public.drivers
       SET full_name = btrim(p_full_name),
           phone = COALESCE(p_phone, phone),
           vehicle_type = COALESCE(p_vehicle_type, vehicle_type),
           vehicle_plate = COALESCE(p_vehicle_plate, vehicle_plate),
           vehicle_color = COALESCE(p_vehicle_color, vehicle_color),
           updated_at = now()
     WHERE id = v_driver
      RETURNING id INTO v_driver;
  END IF;

  -- A driver with no vehicle can never satisfy the dispatch filter.
  IF p_vehicle_type IS NOT NULL AND btrim(COALESCE(p_vehicle_plate,'')) <> '' THEN
    SELECT id INTO v_vehicle
      FROM public.vehicles
     WHERE driver_id = v_driver
       AND category = p_vehicle_type
     LIMIT 1;

    IF v_vehicle IS NULL THEN
      -- The live vehicles table uses `category` (not vehicle_type),
      -- `plate_number` (not vehicle_plate) and `color` (not
      -- vehicle_color).
      INSERT INTO public.vehicles
        (driver_id, category, plate_number, color, is_active, is_verified, created_at)
      VALUES
        (v_driver, p_vehicle_type, p_vehicle_plate, p_vehicle_color, true, false, now())
      RETURNING id INTO v_vehicle;
    ELSE
      UPDATE public.vehicles
         SET is_active = true,
             plate_number = COALESCE(p_vehicle_plate, plate_number),
             color = COALESCE(p_vehicle_color, color)
       WHERE id = v_vehicle;
    END IF;

    UPDATE public.drivers SET active_vehicle_id = v_vehicle WHERE id = v_driver;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'driver_id', v_driver, 'vehicle_id', v_vehicle
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.register_ride_driver(p_full_name text, p_phone text, p_category text, p_make text, p_model text, p_color text, p_plate text, p_seats integer DEFAULT 4)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public,pg_temp
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_driver_id UUID;
  v_vehicle_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;
  IF p_category NOT IN ('economy','comfort','premium','xl','motorbike','taxi') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_category');
  END IF;

  SELECT id INTO v_driver_id FROM drivers WHERE user_id = v_uid;
  IF v_driver_id IS NULL THEN
    INSERT INTO drivers (user_id, full_name, phone, vehicle_type, vehicle_model,
                         vehicle_color, vehicle_plate, is_online, is_verified,
                         verification_status, status, earnings_balance, rating,
                         total_trips)
      VALUES (v_uid, p_full_name, p_phone, p_category, p_make || ' ' || p_model,
              p_color, p_plate, false, false, 'pending', 'offline', 0, 5.0, 0)
      RETURNING id INTO v_driver_id;
  ELSE
    UPDATE drivers SET
      full_name = COALESCE(p_full_name, full_name),
      phone = COALESCE(p_phone, phone)
    WHERE id = v_driver_id;
  END IF;

  SELECT id INTO v_vehicle_id FROM vehicles
    WHERE driver_id = v_driver_id AND category = p_category LIMIT 1;
  IF v_vehicle_id IS NULL THEN
    INSERT INTO vehicles (driver_id, category, make, model, color, plate_number,
                          seats, is_active)
      VALUES (v_driver_id, p_category, p_make, p_model, p_color, p_plate,
              p_seats, true)
      RETURNING id INTO v_vehicle_id;
  ELSE
    UPDATE vehicles SET make = p_make, model = p_model, color = p_color,
      plate_number = p_plate, seats = p_seats, is_active = true
    WHERE id = v_vehicle_id;
  END IF;

  UPDATE drivers SET active_vehicle_id = v_vehicle_id WHERE id = v_driver_id;

  RETURN jsonb_build_object('success', true, 'driver_id', v_driver_id,
                            'vehicle_id', v_vehicle_id);
END;
$function$;


UPDATE public.driver_documents dd
 SET file_url=split_part(split_part(dd.file_url,'/storage/v1/object/sign/driver-documents/',2),'?',1)
 WHERE dd.file_url LIKE '%/storage/v1/object/sign/driver-documents/%'
 AND EXISTS(SELECT 1 FROM storage.objects obj WHERE obj.bucket_id='driver-documents'
   AND obj.name=split_part(split_part(dd.file_url,'/storage/v1/object/sign/driver-documents/',2),'?',1));

DROP POLICY IF EXISTS "driver docs owner rw" ON public.driver_documents;
CREATE POLICY "driver documents read" ON public.driver_documents FOR SELECT TO authenticated
 USING (public.is_admin() OR driver_id IN (SELECT id FROM public.drivers WHERE user_id=auth.uid()));


DROP POLICY IF EXISTS "driver_documents_select_owner" ON storage.objects;
CREATE POLICY "driver_documents_select_owner" ON storage.objects FOR SELECT TO authenticated USING (bucket_id='driver-documents' AND (public.is_admin() OR split_part(name,'/',2)=auth.uid()::text
 OR EXISTS(SELECT 1 FROM public.drivers d WHERE d.user_id=auth.uid() AND d.id::text=split_part(name,'/',2))));

DROP POLICY IF EXISTS "driver_documents_insert_owner" ON storage.objects;
CREATE POLICY "driver_documents_insert_owner" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='driver-documents' AND (public.is_admin() OR split_part(name,'/',2)=auth.uid()::text
 OR EXISTS(SELECT 1 FROM public.drivers d WHERE d.user_id=auth.uid() AND d.id::text=split_part(name,'/',2))));

DROP POLICY IF EXISTS "driver_documents_update_owner" ON storage.objects;
CREATE POLICY "driver_documents_update_owner" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='driver-documents' AND (public.is_admin() OR split_part(name,'/',2)=auth.uid()::text
 OR EXISTS(SELECT 1 FROM public.drivers d WHERE d.user_id=auth.uid() AND d.id::text=split_part(name,'/',2)))) WITH CHECK (bucket_id='driver-documents' AND (public.is_admin() OR split_part(name,'/',2)=auth.uid()::text
 OR EXISTS(SELECT 1 FROM public.drivers d WHERE d.user_id=auth.uid() AND d.id::text=split_part(name,'/',2))));

DROP POLICY IF EXISTS "driver_documents_delete_owner" ON storage.objects;
CREATE POLICY "driver_documents_delete_owner" ON storage.objects FOR DELETE TO authenticated USING (bucket_id='driver-documents' AND (public.is_admin() OR split_part(name,'/',2)=auth.uid()::text
 OR EXISTS(SELECT 1 FROM public.drivers d WHERE d.user_id=auth.uid() AND d.id::text=split_part(name,'/',2))));

CREATE OR REPLACE FUNCTION public.upsert_driver_document(p_driver_id uuid, p_doc_type text, p_file_url text, p_file_name text DEFAULT NULL::text, p_file_size integer DEFAULT NULL::integer, p_expires_at date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id UUID;
  v_existing UUID;
  v_driver_id UUID;
BEGIN
  -- Canonical identity: caller may provide either the drivers.id (canonical) or,
  -- defensively, the users.id of their own account. Both must be owned by the
  -- caller unless they are an owner.
  v_driver_id := p_driver_id;
  IF NOT EXISTS (SELECT 1 FROM public.drivers WHERE id = p_driver_id) THEN
    SELECT id INTO v_driver_id FROM public.drivers WHERE user_id = p_driver_id;
    IF v_driver_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'reason', 'DRIVER_NOT_FOUND');
    END IF;
  END IF;

  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = v_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;

  IF p_doc_type NOT IN ('identity','driving_license','vehicle_registration','insurance','vehicle_photo','profile_photo')
    OR p_file_url IS NULL OR p_file_url LIKE '%://%'
    OR (split_part(p_file_url,'/',2) <> v_driver_id::text AND split_part(p_file_url,'/',2) <> auth.uid()::text)
    OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='driver-documents' AND name=p_file_url)
    OR (p_expires_at IS NOT NULL AND p_expires_at < current_date) THEN
    RETURN jsonb_build_object('success',false,'reason','INVALID_DOCUMENT');
  END IF;

  PERFORM 1 FROM public.drivers WHERE id=v_driver_id FOR UPDATE;
  SELECT id INTO v_existing FROM driver_documents
  WHERE driver_id = v_driver_id AND doc_type = p_doc_type
  ORDER BY created_at DESC LIMIT 1;

  IF v_existing IS NOT NULL THEN
    UPDATE driver_documents SET
      file_url = p_file_url,
      file_name = COALESCE(p_file_name, file_name),
      file_size = COALESCE(p_file_size, file_size),
      expires_at = p_expires_at,
      status = 'pending',
      rejection_reason = NULL,
      reviewed_at = NULL
    WHERE id = v_existing RETURNING id INTO v_id;
  ELSE
    INSERT INTO driver_documents (driver_id, doc_type, file_url, file_name, file_size, expires_at, status)
    VALUES (v_driver_id, p_doc_type, p_file_url, p_file_name, p_file_size, p_expires_at, 'pending')
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'document_id', v_id);
END;
$function$;


CREATE OR REPLACE FUNCTION public.driver_application_documents_ready(p_driver_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT NOT EXISTS (
  SELECT 1 FROM (VALUES('driving_license'),('vehicle_registration')) required(doc_type)
  WHERE NOT EXISTS(SELECT 1 FROM public.driver_documents doc
    JOIN storage.objects obj ON obj.bucket_id='driver-documents' AND obj.name=doc.file_url
    WHERE doc.driver_id=p_driver_id AND doc.doc_type=required.doc_type
    AND doc.status IN ('pending','verified')
    AND (doc.expires_at IS NULL OR doc.expires_at >= current_date)));
$$;
REVOKE ALL ON FUNCTION public.driver_application_documents_ready(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.complete_driver_onboarding(p_driver_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF auth.uid() IS NULL OR d.user_id IS DISTINCT FROM auth.uid() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 IF NOT public.driver_application_documents_ready(p_driver_id) THEN
  RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active=true) THEN
  RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
 END IF;
 UPDATE public.drivers SET onboarding_completed=true,onboarding_step=5,
   verification_status=CASE WHEN is_verified THEN verification_status ELSE 'pending' END,
   updated_at=now() WHERE id=p_driver_id;
 RETURN jsonb_build_object('success',true);
END; $$;

CREATE OR REPLACE FUNCTION public.review_driver_application(p_driver_id uuid,p_approve boolean,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'reason','DRIVER_NOT_FOUND'); END IF;
 IF p_approve IS NULL THEN RETURN jsonb_build_object('success',false,'reason','INVALID_DECISION'); END IF;
 IF p_approve THEN
  IF NOT public.driver_application_documents_ready(p_driver_id) THEN
   RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active) THEN
   RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
  END IF;
 ELSE
  IF btrim(COALESCE(p_reason,''))='' THEN RETURN jsonb_build_object('success',false,'reason','REASON_REQUIRED'); END IF;
 END IF;
 UPDATE public.driver_documents SET status=CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,
   reviewed_at=now(), rejection_reason=CASE WHEN p_approve THEN NULL ELSE p_reason END
   WHERE driver_id=p_driver_id AND doc_type IN ('driving_license','vehicle_registration');
 UPDATE public.drivers SET is_verified=p_approve,
   verification_status=CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,updated_at=now()
   WHERE id=p_driver_id;
 IF p_approve THEN UPDATE public.vehicles SET is_verified=true WHERE driver_id=p_driver_id AND is_active; END IF;
 INSERT INTO public.notifications(user_id,title,body,type,data,deep_link,send_push)
 VALUES(d.user_id,CASE WHEN p_approve THEN 'تمت مراجعة حساب السائق' ELSE 'مستندات السائق محتاجة مراجعة' END,
 CASE WHEN p_approve THEN 'تم قبول المستندات وتفعيل حساب السائق' ELSE p_reason END,
 'verification',jsonb_build_object('driver_id',p_driver_id,'approved',p_approve),'/driver/documents',true);
 RETURN jsonb_build_object('success',true);
END; $$;

CREATE OR REPLACE FUNCTION public.guard_vehicle_verification()
RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF current_user IN ('authenticated','anon') AND NOT public.is_admin() THEN
  IF TG_OP='INSERT' THEN
   IF COALESCE(NEW.is_verified,false) THEN RAISE EXCEPTION 'Vehicle verification requires admin review'; END IF;
  ELSE
   IF NEW.is_verified IS DISTINCT FROM OLD.is_verified OR NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    RAISE EXCEPTION 'Vehicle verification and ownership are server-managed';
   END IF;
  END IF;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS guard_vehicle_verification ON public.vehicles;
CREATE TRIGGER guard_vehicle_verification BEFORE INSERT OR UPDATE ON public.vehicles
 FOR EACH ROW EXECUTE FUNCTION public.guard_vehicle_verification();


REVOKE ALL ON FUNCTION public.driver_complete_registration(text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.driver_complete_registration(text,text,text,text,text) TO authenticated,service_role;

REVOKE ALL ON FUNCTION public.register_ride_driver(text,text,text,text,text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.register_ride_driver(text,text,text,text,text,text,text,integer) TO authenticated,service_role;

REVOKE ALL ON FUNCTION public.upsert_driver_document(uuid,text,text,text,integer,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.upsert_driver_document(uuid,text,text,text,integer,date) TO authenticated,service_role;

REVOKE ALL ON FUNCTION public.complete_driver_onboarding(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_driver_onboarding(uuid) TO authenticated,service_role;

REVOKE ALL ON FUNCTION public.review_driver_application(uuid,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.review_driver_application(uuid,boolean,text) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';
COMMIT;