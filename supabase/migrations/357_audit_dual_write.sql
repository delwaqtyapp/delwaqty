CREATE OR REPLACE FUNCTION public.write_audit(p_action text, p_resource text, p_resource_id text DEFAULT NULL::text, p_details jsonb DEFAULT NULL::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
BEGIN
  INSERT INTO public.activity_logs
    (user_id, action, resource, resource_id, details, timestamp)
  VALUES (
    COALESCE(auth.uid()::text, 'system'),
    p_action,
    p_resource,
    p_resource_id,
    p_details,
    now()
  );
  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  INSERT INTO public.audit_log
    (actor, actor_role, action, resource, resource_id, after)
  VALUES (
    auth.uid(),
    v_role,
    p_action,
    p_resource,
    p_resource_id,
    p_details
  );
END;
$function$;
