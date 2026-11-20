-- Rollback-only synthetic metadata and accounts. No real files or money.
BEGIN;
DO $$
DECLARE u uuid:=gen_random_uuid(); admin_uid uuid:=gen_random_uuid(); d uuid; v uuid; a jsonb; p text; docid uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u::text||'@example.invalid'),(admin_uid,admin_uid::text||'@example.invalid');
 INSERT INTO public.users(id,email,role,role_key) VALUES(u,u::text||'@example.invalid','customer',NULL),(admin_uid,admin_uid::text||'@example.invalid','owner','owner') ON CONFLICT(id) DO UPDATE SET role=excluded.role,role_key=excluded.role_key;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Synthetic driver',NULL,'motorbike','AUDIT',NULL);
 PERFORM set_config('role','none',true);
 d:=(a->>'driver_id')::uuid;v:=(a->>'vehicle_id')::uuid;
 IF d IS NULL THEN RAISE EXCEPTION 'registration failed: %',a; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND NOT is_verified AND verification_status='pending') THEN RAISE EXCEPTION 'driver self-verified'; END IF;
 IF EXISTS(SELECT 1 FROM public.vehicles WHERE id=v AND is_verified) THEN RAISE EXCEPTION 'vehicle self-verified'; END IF;
 PERFORM set_config('role','authenticated',true);
 a:=public.complete_driver_onboarding(d);
 IF a->>'reason' <> 'REQUIRED_DOCUMENTS_MISSING' THEN RAISE EXCEPTION 'missing docs accepted: %',a; END IF;
 a:=public.upsert_driver_document(d,'driving_license','other/invalid/file.jpg');
 IF a->>'success' <> 'false' THEN RAISE EXCEPTION 'invalid path accepted'; END IF;
 BEGIN
  UPDATE public.vehicles SET is_verified=true WHERE id=v;
  RAISE EXCEPTION 'vehicle self-approval allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='vehicle self-approval allowed' THEN RAISE; END IF;
 END;
 PERFORM set_config('role','none',true);
 -- Metadata-only fixtures: no file is uploaded and every row rolls back.
 p:='driver_licenses/'||d::text||'/audit.jpg';
 INSERT INTO storage.objects(bucket_id,name) VALUES('driver-documents',p);
 PERFORM set_config('role','authenticated',true);
 a:=public.upsert_driver_document(d,'driving_license',p,'audit.jpg',1,NULL);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'own document rejected: %',a; END IF;
 PERFORM set_config('role','none',true);
 p:='driver_vehicles/'||d::text||'/audit.jpg';
 INSERT INTO storage.objects(bucket_id,name) VALUES('driver-documents',p);
 PERFORM set_config('role','authenticated',true);
 a:=public.upsert_driver_document(d,'vehicle_registration',p,'audit.jpg',1,NULL);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'registration doc rejected: %',a; END IF;
 a:=public.complete_driver_onboarding(d);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'valid onboarding failed: %',a; END IF;
 a:=public.review_driver_application(d,true,NULL);
 IF a->>'reason' <> 'FORBIDDEN' THEN RAISE EXCEPTION 'self admin approval allowed'; END IF;
 PERFORM set_config('role','none',true);
 PERFORM set_config('request.jwt.claim.sub',admin_uid::text,true);
 PERFORM set_config('role','authenticated',true);
 IF (SELECT count(*) FROM public.driver_documents WHERE driver_id=d) <> 2 THEN RAISE EXCEPTION 'admin cannot see documents'; END IF;
 a:=public.review_driver_application(d,true,NULL);
 IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'admin approval failed: %',a; END IF;
 PERFORM set_config('role','none',true);
 IF NOT EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND is_verified) THEN RAISE EXCEPTION 'driver not verified'; END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Edited driver',NULL,'motorbike','AUDIT',NULL);
 PERFORM set_config('role','none',true);
 IF NOT EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND is_verified) THEN RAISE EXCEPTION 'edit removed admin decision'; END IF;
 UPDATE public.drivers SET is_verified=false,verification_status='rejected' WHERE id=d;
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Edited rejected driver',NULL,'motorbike','AUDIT',NULL);
 PERFORM set_config('role','none',true);
 IF EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND is_verified) THEN RAISE EXCEPTION 'edit bypassed rejection'; END IF;
END $$;
SELECT 'onboarding/verification assertions passed; fixtures rolled back' AS result;

ROLLBACK;
