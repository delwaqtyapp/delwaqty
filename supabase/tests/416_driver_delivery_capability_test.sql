-- Rollback-only synthetic metadata and accounts. No real files or money.
BEGIN;

DO $$
DECLARE u uuid:=gen_random_uuid(); admin_uid uuid:=gen_random_uuid(); d uuid; v uuid; a jsonb; p text; docid uuid;
BEGIN
 INSERT INTO auth.users(id,email) VALUES(u,u::text||'@example.invalid'),(admin_uid,admin_uid::text||'@example.invalid');
 INSERT INTO public.users(id,email,role,role_key) VALUES(u,u::text||'@example.invalid','delivery',NULL),(admin_uid,admin_uid::text||'@example.invalid','owner','owner') ON CONFLICT(id) DO UPDATE SET role=excluded.role,role_key=excluded.role_key;
 UPDATE public.users SET user_type='delivery',verification_status='pending',account_status='active',status='active' WHERE id=u;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Synthetic driver',NULL,'motorcycle','AUDIT',NULL);
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
 PERFORM set_config('role','authenticated',true);
 FOREACH p IN ARRAY ARRAY['motorcycle','tuk_tuk','tricycle','car'] LOOP
  a:=public.add_driver_vehicle(d,p,NULL,NULL,NULL,NULL,'AUDIT-'||p,1,NULL);
  IF a->>'success' <> 'true' THEN RAISE EXCEPTION 'fleet type rejected: % %',p,a; END IF;
 END LOOP;
 BEGIN
  a:=public.add_driver_vehicle(d,'bicycle',NULL,NULL,NULL,NULL,'INVALID',1,NULL);
  RAISE EXCEPTION 'unsupported fleet type allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='unsupported fleet type allowed' THEN RAISE; END IF;
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
 PERFORM set_config('role','none',true);
 ASSERT (SELECT service_types FROM public.drivers WHERE id=d)=ARRAY['food','grocery','pharmacy','parcel']::text[],'delivery capabilities initialized';
 ASSERT (SELECT accepts_deliveries FROM public.drivers WHERE id=d),'delivery opt-in initialized';
 PERFORM set_config('role','authenticated',true);
 a:=public.update_driver_capabilities(d,ARRAY['ride'],true,15,20);
 ASSERT a->>'reason'='INVALID_CAPABILITIES','passenger rides accepted';
 a:=public.update_driver_capabilities(d,ARRAY[]::text[],true,15,20);
 ASSERT a->>'reason'='INVALID_CAPABILITIES','enabled empty service set accepted';
 a:=public.update_driver_capabilities(d,ARRAY['food'],true,15,20);
 ASSERT a->>'success'='true','delivery subset toggle rejected';
 a:=public.update_driver_capabilities(d,ARRAY[]::text[],false,15,20);
 ASSERT a->>'success'='true','delivery opt-out rejected';
 a:=public.complete_driver_onboarding(d);
 ASSERT a->>'success'='true','repeat onboarding rejected';
 PERFORM set_config('role','none',true);
 ASSERT NOT (SELECT accepts_deliveries FROM public.drivers WHERE id=d),'repeat onboarding reset opt-out';
 PERFORM set_config('role','authenticated',true);
 BEGIN
  UPDATE public.drivers SET service_types=ARRAY['ride'] WHERE id=d;
  RAISE EXCEPTION 'direct ride update accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 BEGIN
  UPDATE public.drivers SET max_weight_kg=-1 WHERE id=d;
  RAISE EXCEPTION 'direct invalid weight accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 BEGIN
  UPDATE public.drivers SET accepts_deliveries=NULL WHERE id=d;
  RAISE EXCEPTION 'direct NULL toggle accepted';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 a:=public.update_driver_capabilities(d,ARRAY['food'],true,15,20);
 ASSERT a->>'reason'='FORBIDDEN','foreign caller accepted';
 PERFORM set_config('request.jwt.claim.sub','',true);
 a:=public.update_driver_capabilities(d,ARRAY['food'],true,15,20);
 ASSERT a->>'reason'='FORBIDDEN','anon claim accepted';
 PERFORM set_config('request.jwt.claim.sub',u::text,true);


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
 ASSERT (SELECT verification_status FROM users WHERE id=u)='approved','member approved';
 ASSERT public._approved_app_channels(u)=ARRAY['driver'],'driver invitation eligible';
 ASSERT (SELECT count(*) FROM notifications WHERE user_id=u AND deep_link='/profile/app-invitations')=1,'one invitation';
 a:=public.review_driver_application(d,true,NULL);
 ASSERT (SELECT count(*) FROM notifications WHERE user_id=u AND deep_link='/profile/app-invitations')=1,'repeat no duplicate';
 a:=public.review_driver_application(d,false,'zz-test rejection');
 ASSERT (SELECT verification_status FROM users WHERE id=u)='rejected','member rejected';
 ASSERT public._approved_app_channels(u)='{}'::text[],'rejected hidden';
 UPDATE users SET account_status='suspended' WHERE id=u;
 a:=public.review_driver_application(d,true,NULL);
 ASSERT (SELECT account_status FROM users WHERE id=u)='suspended','suspension preserved';
 ASSERT public._approved_app_channels(u)='{}'::text[],'suspended hidden';
 UPDATE users SET role='provider',user_type='provider',verification_status='pending' WHERE id=u;
 a:=public.review_driver_application(d,true,NULL);
 ASSERT (SELECT verification_status FROM users WHERE id=u)='pending','unrelated role not approved';

 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Edited driver',NULL,'motorcycle','AUDIT',NULL);
 PERFORM set_config('role','none',true);
 IF NOT EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND is_verified) THEN RAISE EXCEPTION 'edit removed admin decision'; END IF;
 UPDATE public.drivers SET is_verified=false,verification_status='rejected' WHERE id=d;
 PERFORM set_config('role','authenticated',true);
 a:=public.driver_complete_registration('Edited rejected driver',NULL,'motorcycle','AUDIT',NULL);
 PERFORM set_config('role','none',true);
 IF EXISTS(SELECT 1 FROM public.drivers WHERE id=d AND is_verified) THEN RAISE EXCEPTION 'edit bypassed rejection'; END IF;
END $$;
SELECT 'onboarding/verification assertions passed; fixtures rolled back' AS result;

ROLLBACK;
