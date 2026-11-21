-- 169: Fix live-share token exposure (bughunt F9).
-- The "public read by token" policy listed every ACTIVE session to anyone,
-- including the share_token itself. Feature is not wired into the shipped
-- app. Public SELECT dropped; share views go through a SECURITY DEFINER
-- function that takes the token and returns only that session (no token
-- field). Owner read/write policy unchanged.

drop policy if exists "live share public read by token" on public.live_share_sessions;

create or replace function public.get_live_share_by_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.live_share_sessions%rowtype;
begin
  select * into v_row
    from public.live_share_sessions
   where share_token = btrim(coalesce(p_token, ''))
     and is_active = true
     and expires_at > now()
   limit 1;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'ride_id', v_row.ride_id,
    'expires_at', v_row.expires_at
  );
end;
$$;

grant execute on function public.get_live_share_by_token(text) to anon, authenticated;
