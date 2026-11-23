-- STAGING ONLY, synthetic fixtures, fully rolled back. No real balance changes.
BEGIN;
CREATE TEMP TABLE t408 AS SELECT gen_random_uuid() owner_id, gen_random_uuid() admin_id, gen_random_uuid() customer_id, gen_random_uuid() no_region_id, gen_random_uuid() region_a, gen_random_uuid() region_b;
INSERT INTO auth.users(id,email,raw_user_meta_data)
SELECT owner_id,'zz408-owner@example.invalid','{"user_type":"owner"}'::jsonb FROM t408 UNION ALL
SELECT admin_id,'zz408-admin@example.invalid','{"user_type":"admin"}'::jsonb FROM t408 UNION ALL
SELECT customer_id,'zz408-customer@example.invalid','{"user_type":"customer"}'::jsonb FROM t408 UNION ALL
SELECT no_region_id,'zz408-noregion@example.invalid','{"user_type":"customer"}'::jsonb FROM t408;
UPDATE public.users SET role='owner',user_type='owner',verification_status='approved' WHERE id=(SELECT owner_id FROM t408);
UPDATE public.users SET role='admin',user_type='admin',verification_status='approved' WHERE id=(SELECT admin_id FROM t408);
INSERT INTO public.regions(id,code,type,name_ar,name_en)
SELECT region_a,'ZZ408A','city','408A','zz408A' FROM t408 UNION ALL SELECT region_b,'ZZ408B','city','408B','zz408B' FROM t408;
INSERT INTO public.admin_management(admin_id,supervisor_id,is_active) SELECT admin_id,owner_id,true FROM t408;
INSERT INTO public.admin_region_assignments(admin_id,region_id,scope) SELECT admin_id,region_a,'self' FROM t408;
INSERT INTO public.user_region_preferences(user_id,region_id,source) SELECT customer_id,region_a,'manual' FROM t408;
INSERT INTO public.grace_accounts(user_id,grace_limit) SELECT customer_id,7 FROM t408 UNION ALL SELECT no_region_id,9 FROM t408;
GRANT SELECT ON t408 TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE t record;r jsonb; BEGIN
 SELECT * INTO t FROM t408;
 PERFORM set_config('request.jwt.claim.sub',t.customer_id::text,true);
 r:=public.admin_set_grace(t.customer_id,20,'zz408'); ASSERT r->>'ok'='false','customer accepted';
 PERFORM set_config('request.jwt.claim.sub',t.admin_id::text,true);
 r:=public.admin_set_grace(t.customer_id,20,'zz408'); ASSERT r->>'ok'='false','nonfinancial admin accepted';
END $$;
RESET ROLE;
INSERT INTO public.admin_permission_grants(admin_id,permission,granted_by) SELECT admin_id,'FINANCIAL_WALLET_MANAGE',owner_id FROM t408;
SET LOCAL ROLE authenticated;
DO $$ DECLARE t record;r jsonb; BEGIN
 SELECT * INTO t FROM t408;
 PERFORM set_config('request.jwt.claim.sub',t.admin_id::text,true);
 r:=public.admin_set_grace(t.no_region_id,20,'zz408'); ASSERT r->>'ok'='false','regional admin accepted unknown region';
 r:=public.admin_set_grace(t.customer_id,NULL,'zz408'); ASSERT r->>'code'='INVALID_LIMIT','NULL accepted';
 r:=public.admin_set_grace(t.customer_id,-1,'zz408'); ASSERT r->>'code'='INVALID_LIMIT','negative accepted';
 r:=public.admin_set_grace(t.customer_id,20,'zz408'); ASSERT r->>'ok'='true','financial in-region denied';
END $$;
RESET ROLE;
UPDATE public.user_region_preferences SET region_id=(SELECT region_b FROM t408) WHERE user_id=(SELECT customer_id FROM t408);
SET LOCAL ROLE authenticated;
DO $$ DECLARE t record;r jsonb; BEGIN
 SELECT * INTO t FROM t408;
 PERFORM set_config('request.jwt.claim.sub',t.admin_id::text,true);
 r:=public.admin_set_grace(t.customer_id,30,'zz408'); ASSERT r->>'ok'='false','foreign region accepted';
END $$;
RESET ROLE;
DO $$ BEGIN
 ASSERT (SELECT grace_limit FROM public.grace_accounts WHERE user_id=(SELECT customer_id FROM t408))=20,'unexpected grace change';
 ASSERT (SELECT grace_limit FROM public.grace_accounts WHERE user_id=(SELECT no_region_id FROM t408))=9,'unknown region changed';
 ASSERT (SELECT count(*) FROM public.grace_audit_log WHERE account_id=(SELECT customer_id FROM t408) AND reason='zz408')=1,'audit cardinality';
END $$;
SELECT 'PASS408: financial permission, target scope, NULL/negative, denied attempts unchanged, one audit' result;
ROLLBACK;
