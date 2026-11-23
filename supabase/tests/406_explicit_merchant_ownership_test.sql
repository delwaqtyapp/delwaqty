-- STAGING ONLY. Isolate the exactly-one-unowned state, then roll everything back.
BEGIN;
CREATE TEMP TABLE t406 AS SELECT gen_random_uuid() customer_id,gen_random_uuid() owner_id,gen_random_uuid() unowned_id;
INSERT INTO auth.users(id,email,raw_user_meta_data) SELECT customer_id,'zz406-customer@example.invalid','{"user_type":"customer"}'::jsonb FROM t406 UNION ALL SELECT owner_id,'zz406-owner@example.invalid','{"user_type":"merchant"}'::jsonb FROM t406;
-- Assign existing unowned rows inside this rollback fixture to avoid count ambiguity.
UPDATE public.merchants SET owner_user_id=(SELECT owner_id FROM t406) WHERE owner_user_id IS NULL;
INSERT INTO public.merchants(id,name,status,is_open) SELECT unowned_id,'zz406-unowned','active',true FROM t406;
DO $$ BEGIN ASSERT (SELECT count(*) FROM public.merchants WHERE owner_user_id IS NULL)=1,'fixture must have exactly one unowned'; END $$;
GRANT SELECT ON t406 TO authenticated;
SET LOCAL ROLE authenticated;
DO $$ DECLARE t record; BEGIN
SELECT * INTO t FROM t406;
PERFORM set_config('request.jwt.claim.sub',t.customer_id::text,true);
ASSERT public.resolve_my_merchant() IS NULL,'customer captured the unowned merchant';
END $$;
RESET ROLE;
UPDATE public.merchants SET owner_user_id=(SELECT customer_id FROM t406) WHERE id=(SELECT unowned_id FROM t406);
SET LOCAL ROLE authenticated;
DO $$ DECLARE t record; BEGIN
SELECT * INTO t FROM t406;
PERFORM set_config('request.jwt.claim.sub',t.customer_id::text,true);
ASSERT public.resolve_my_merchant()=t.unowned_id,'explicit owned lookup broken';
END $$;
RESET ROLE;
SELECT 'PASS406: exactly-one-unowned customer denied; explicit owner lookup preserved' result;
ROLLBACK;
