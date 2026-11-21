-- 189: Notification audience targeting + device-token app tagging.
-- Root fix for pushes arriving in the wrong app flavor: every notification
-- now carries an explicit audience (customer/driver/provider/admin/all),
-- every device token is tagged with the app flavor that registered it, and
-- stale cross-account token bindings on the same device+app are dropped at
-- registration time.
--
-- Derivation precedence (mirrors the app-side channel rules):
--   1. explicit data.target_app / target_role / audience marker
--   2. app-owned deep_link prefixes (/admin, /driver, /provider, /merchant-dashboard)
--   3. unambiguous ops types (admin ops set, provider_profile, promotion/reward)
--   4. recipient role (customer->customer, driver->driver, merchant->provider,
--      admin/owner->admin)
--   5. 'all'

-- 1. Audience column.
alter table public.notifications
  add column if not exists audience text not null default 'all';
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'notifications_audience_check') then
    alter table public.notifications
      add constraint notifications_audience_check
      check (audience in ('customer','driver','provider','admin','all'));
  end if;
end $$;
create index if not exists notifications_user_unread_audience_idx
  on public.notifications (user_id, is_read, audience);

-- 2. Pure derivation function (used by the trigger and the backfill).
create or replace function public._notification_audience_for(
  p_type text, p_deep_link text, p_data jsonb, p_user_id uuid
) returns text
language plpgsql stable security definer set search_path = public
as $func$
declare
  v_marker text;
  v_role text;
begin
  -- 1. explicit marker in the payload
  v_marker := lower(coalesce(
    p_data->>'target_app', p_data->>'target_role', p_data->>'audience', ''));
  if v_marker in ('customer','client','user') then return 'customer'; end if;
  if v_marker in ('driver','delivery','courier') then return 'driver'; end if;
  if v_marker in ('provider','merchant','vendor','partner') then return 'provider'; end if;
  if v_marker in ('admin','owner','super_admin','operational') then return 'admin'; end if;
  if v_marker in ('all','broadcast') then return 'all'; end if;

  -- 2. app-owned deep-link prefixes
  if p_deep_link is not null then
    if p_deep_link like '/admin%' then return 'admin'; end if;
    if p_deep_link like '/driver%' then return 'driver'; end if;
    if p_deep_link like '/provider%' or p_deep_link like '/merchant-dashboard%' then
      return 'provider';
    end if;
  end if;

  -- 3. unambiguous types
  if p_type in ('admin_management','approval',
                'emergency_alert','complaint_escalated','complaint_assigned',
                'chat_assigned','chat_escalated','topup_request_pending','appeal') then
    return 'admin';
  end if;
  if p_type in ('provider_profile','providerProfile') then
    return 'provider';
  end if;
  if p_type in ('promotion','reward') then
    return 'customer';
  end if;

  -- 4. recipient role
  select role into v_role from public.users where id = p_user_id;
  if v_role = 'customer' then return 'customer'; end if;
  if v_role = 'driver' then return 'driver'; end if;
  if v_role in ('merchant','provider') then return 'provider'; end if;
  if v_role in ('admin','owner','super_admin') then return 'admin'; end if;

  return 'all';
end;
$func$;
revoke all on function public._notification_audience_for(text, text, jsonb, uuid) from public, anon, authenticated;

create or replace function public._notifications_set_audience()
returns trigger
language plpgsql security definer set search_path = public
as $func$
begin
  if new.audience is null or new.audience = 'all' then
    new.audience := public._notification_audience_for(
      new.type, new.deep_link, new.data, new.user_id);
  end if;
  return new;
end;
$func$;
drop trigger if exists notifications_set_audience on public.notifications;
create trigger notifications_set_audience
  before insert on public.notifications
  for each row execute function public._notifications_set_audience();

-- Backfill existing rows.
update public.notifications n
   set audience = public._notification_audience_for(n.type, n.deep_link, n.data, n.user_id)
 where n.audience = 'all';

-- 3. Device tokens: app flavor tag.
alter table public.notification_tokens
  add column if not exists app text;
create index if not exists notification_tokens_user_app_active_idx
  on public.notification_tokens (user_id, app) where is_active;

-- 4. register_device_token with app tagging + stale cross-account cleanup.
drop function if exists public.register_device_token(text, text, text, text);
create or replace function public.register_device_token(
  p_token text, p_platform text, p_device_id text,
  p_app_version text default null, p_app text default null
) returns void
language plpgsql security definer set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_token is null or btrim(p_token) = '' then
    raise exception 'token is required';
  end if;
  if p_platform is null or btrim(p_platform) = '' then
    raise exception 'platform is required';
  end if;

  insert into public.notification_tokens
    (user_id, token, platform, device_id, app_version, app, is_active, last_seen_at)
  values
    (v_uid, p_token, p_platform, p_device_id, p_app_version, p_app, true, now())
  on conflict (user_id, token)
  do update set
    platform = excluded.platform,
    device_id = excluded.device_id,
    app_version = excluded.app_version,
    app = coalesce(excluded.app, notification_tokens.app),
    is_active = true,
    last_seen_at = now(),
    updated_at = now();

  -- Token rotation: other ACTIVE tokens of this user on the same device are
  -- superseded (re-install / refresh).
  if p_device_id is not null and btrim(p_device_id) <> '' then
    update public.notification_tokens
       set is_active = false, updated_at = now()
     where user_id = v_uid
       and device_id = p_device_id
       and token <> p_token
       and is_active = true;

    -- Cross-account leak fix: another account's token for the SAME app on the
    -- SAME device must not keep receiving pushes after an account switch.
    if p_app is not null and btrim(p_app) <> '' then
      update public.notification_tokens
         set is_active = false, updated_at = now()
       where device_id = p_device_id
         and app = p_app
         and user_id <> v_uid
         and is_active = true;
    end if;
  end if;
end;
$func$;
grant execute on function public.register_device_token(text, text, text, text, text) to authenticated;

-- 5. Logout deactivation becomes app-scoped when the app tag is supplied.
create or replace function public.deactivate_device_tokens(p_device_id text, p_app text default null)
returns void
language plpgsql security definer set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  update public.notification_tokens
     set is_active = false, updated_at = now()
   where user_id = v_uid
     and device_id = p_device_id
     and (p_app is null or app = p_app or app is null);
end;
$func$;
grant execute on function public.deactivate_device_tokens(text, text) to authenticated;

-- 6. Mapping correction (moderation/admin_topup are member-facing too):
-- re-derive any rows the first pass sent to admin on type alone.
update public.notifications n
   set audience = public._notification_audience_for(n.type, n.deep_link, n.data, n.user_id)
 where n.audience = 'admin'
   and n.type in ('moderation','admin_topup');
