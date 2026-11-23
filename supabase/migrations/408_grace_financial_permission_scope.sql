-- Financial grace changes require an explicit wallet-management grant and target scope.
BEGIN;
CREATE OR REPLACE FUNCTION public.admin_set_grace(p_user_id uuid, p_new_limit integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_region uuid;
  v_before integer;
  v_row    public.grace_accounts;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_new_limit IS NULL OR p_new_limit < 0 THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_LIMIT');
  END IF;
  v_region := public._member_region_id(p_user_id);
  IF NOT public._admin_write_scope(v_region)
     OR NOT public.has_permission('FINANCIAL_WALLET_MANAGE', public._ops_scope_region(v_region)) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  END IF;
  IF p_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.users WHERE id=p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_USER');
  END IF;

  -- This path has its own financial permission gate. Do not call a helper
  -- whose MEMBER_MODERATE permission could deny then silently continue.
  INSERT INTO public.grace_accounts(user_id) VALUES(p_user_id)
    ON CONFLICT(user_id) DO NOTHING;
  SELECT * INTO STRICT v_row FROM public.grace_accounts
    WHERE user_id=p_user_id FOR UPDATE;
  v_before := v_row.grace_limit;
  UPDATE public.grace_accounts SET grace_limit = p_new_limit, updated_at = now()
   WHERE user_id = p_user_id;

  INSERT INTO public.grace_audit_log
    (account_id, before, after, actor, reason, created_at)
  VALUES
    (p_user_id, v_before, p_new_limit, auth.uid(),
     COALESCE(p_reason, 'admin_adjustment'), now());

  PERFORM public.write_audit('GRACE_LIMIT_CHANGED', 'grace_accounts', p_user_id::text,
    jsonb_build_object('old', v_before, 'new', p_new_limit,
      'actor', auth.uid(), 'region', v_region, 'reason', p_reason));

  RETURN jsonb_build_object('ok', true, 'code', 'OK',
    'grace_limit', p_new_limit);
END;
$function$
;
COMMIT;
