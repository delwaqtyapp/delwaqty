-- 404: internal helper ACL lockdown and explicit merchant ownership.
BEGIN;
REVOKE ALL ON FUNCTION public._reward_config_exec(uuid,uuid,text,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._reward_config_exec(uuid,uuid,text,jsonb,text) TO service_role;
REVOKE ALL ON FUNCTION public._assign_chat_to_admin(uuid,uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._assign_chat_to_admin(uuid,uuid,text) TO service_role;
REVOKE ALL ON FUNCTION public._commission_bucket_amount(timestamp with time zone,timestamp with time zone,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._commission_bucket_amount(timestamp with time zone,timestamp with time zone,text) TO service_role;
REVOKE ALL ON FUNCTION public._ensure_wallet(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._ensure_wallet(uuid) TO service_role;
REVOKE ALL ON FUNCTION public.delete_user_data(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_data(uuid,text) TO service_role;
REVOKE ALL ON FUNCTION public.deactivate_stale_tokens(interval) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.deactivate_stale_tokens(interval) TO service_role;
REVOKE ALL ON FUNCTION public.cleanup_invalid_token(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_invalid_token(text) TO service_role;

COMMIT;
