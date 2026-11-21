-- 170: log_admin_action must not raise on system context (bughunt F3).
-- dispatch_order (cron/service path) calls it with auth.uid() = NULL; the
-- raise rolled back the whole assignment. System context now logs with
-- actor NULL / actor_role 'system'.

create or replace function public.log_admin_action(
  p_action text, p_resource text, p_resource_id text,
  p_before jsonb default null, p_after jsonb default null,
  p_reason text default null, p_scope text default 'GLOBAL'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role  text;
  v_id    uuid;
begin
  if v_actor is null then
    insert into public.audit_log (actor, actor_role, scope, action, resource, resource_id, before, after, reason)
    values (null, 'system', p_scope, p_action, p_resource, p_resource_id, p_before, p_after, p_reason)
    returning id into v_id;
    return v_id;
  end if;

  select role into v_role from public.users where id = v_actor;
  insert into public.audit_log (actor, actor_role, scope, action, resource, resource_id, before, after, reason)
  values (v_actor, v_role, p_scope, p_action, p_resource, p_resource_id, p_before, p_after, p_reason)
  returning id into v_id;
  return v_id;
end;
$$;
