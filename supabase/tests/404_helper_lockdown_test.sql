BEGIN;
INSERT INTO auth.users(id,email) VALUES ('fb040000-0000-4000-8000-000000000001','zz404-owner@example.invalid'),('fb040000-0000-4000-8000-000000000002','zz404-customer@example.invalid');
INSERT INTO public.users(id,email,role,user_type,verification_status) VALUES
('fb040000-0000-4000-8000-000000000001','zz404-owner@example.invalid','owner','customer','approved'),
('fb040000-0000-4000-8000-000000000002','zz404-customer@example.invalid','customer','customer','approved') ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role,user_type=EXCLUDED.user_type,verification_status=EXCLUDED.verification_status;
INSERT INTO public.merchants(id,name,owner_user_id) VALUES ('fb040000-0000-4000-8000-000000000003','zz404-unowned',NULL);
INSERT INTO public.chat_rooms(id,room_type,participant_ids,status) VALUES ('fb040000-0000-4000-8000-000000000004','support',ARRAY['fb040000-0000-4000-8000-000000000002'::uuid],'open');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fb040000-0000-4000-8000-000000000002',true);
DO $$ DECLARE sig text; BEGIN
FOREACH sig IN ARRAY ARRAY['_reward_config_exec(uuid,uuid,text,jsonb,text)','_assign_chat_to_admin(uuid,uuid,text)','_commission_bucket_amount(timestamp with time zone,timestamp with time zone,text)','_ensure_wallet(uuid)','delete_user_data(uuid,text)','deactivate_stale_tokens(interval)','cleanup_invalid_token(text)'] LOOP
ASSERT NOT has_function_privilege('authenticated',('public.'||sig)::regprocedure,'EXECUTE'), sig;
ASSERT NOT has_function_privilege('anon',('public.'||sig)::regprocedure,'EXECUTE'), sig;
END LOOP;
BEGIN PERFORM public._reward_config_exec('fb040000-0000-4000-8000-000000000001',NULL,'birthday','{"enabled":false,"benefit":{"kind":"none"}}','probe'); RAISE EXCEPTION 'direct helper allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
BEGIN PERFORM public._assign_chat_to_admin('fb040000-0000-4000-8000-000000000004','fb040000-0000-4000-8000-000000000001','assigned'); RAISE EXCEPTION 'direct chat helper allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
BEGIN PERFORM public._commission_bucket_amount(now(),now(),'merchant'); RAISE EXCEPTION 'commission helper allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
ASSERT public.resolve_my_merchant() IS NULL, 'unowned merchant leaked';
ASSERT public.get_wallet_balance(auth.uid()) IS NOT NULL, 'wallet wrapper broken';
END $$;
SELECT set_config('request.jwt.claim.sub','fb040000-0000-4000-8000-000000000001',true);
SELECT public.assign_support_chat('fb040000-0000-4000-8000-000000000004','fb040000-0000-4000-8000-000000000001');
SELECT public.platform_revenue_overview('all');
SELECT public.request_reward_config_change('birthday','{"enabled":false,"benefit":{"kind":"none"}}',NULL,'zz404-wrapper');
RESET ROLE;
DO $$ BEGIN ASSERT (SELECT assigned_admin_id FROM public.chat_rooms WHERE id='fb040000-0000-4000-8000-000000000004')='fb040000-0000-4000-8000-000000000001'::uuid; END $$;
SELECT 'PASS404: helper ACLs, blocked customer probes, unowned lookup, wallet/chat/revenue/reward wrapper paths' result;
ROLLBACK;
