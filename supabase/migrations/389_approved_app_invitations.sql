-- 389: approved and active accounts receive a Customer-app download invitation.
-- URLs and APK availability stay in the existing signed OTA channel.
create or replace function public._approved_app_channels_at(p_uid uuid, p_table text, p_old jsonb)
returns text[] language sql stable security definer
set search_path = public, pg_temp as $$
  with
  users as (
    select t.* from public.users t where t.id=p_uid and not (p_table is not distinct from 'users' and to_jsonb(t)->>'id' = p_old->>'id')
    union all select (jsonb_populate_record(null::public.users,p_old)).* where p_table='users' and p_old is not null
  ),
  drivers as (
    select t.* from public.drivers t where t.user_id=p_uid and not (p_table is not distinct from 'drivers' and to_jsonb(t)->>'id' = p_old->>'id')
    union all select (jsonb_populate_record(null::public.drivers,p_old)).* where p_table='drivers' and p_old is not null
  ),
  merchants as (
    select t.* from public.merchants t where t.owner_user_id=p_uid and not (p_table is not distinct from 'merchants' and to_jsonb(t)->>'id' = p_old->>'id')
    union all select (jsonb_populate_record(null::public.merchants,p_old)).* where p_table='merchants' and p_old is not null
  ),
  provider_business_profiles as (
    select t.* from public.provider_business_profiles t where t.user_id=p_uid and not (p_table is not distinct from 'provider_business_profiles' and to_jsonb(t)->>'id' = p_old->>'id')
    union all select (jsonb_populate_record(null::public.provider_business_profiles,p_old)).* where p_table='provider_business_profiles' and p_old is not null
  ),
  service_providers as (
    select t.* from public.service_providers t where t.user_id=p_uid and not (p_table is not distinct from 'service_providers' and to_jsonb(t)->>'id' = p_old->>'id')
    union all select (jsonb_populate_record(null::public.service_providers,p_old)).* where p_table='service_providers' and p_old is not null
  ),
  admin_management as (
    select t.* from public.admin_management t where t.admin_id=p_uid and not (p_table is not distinct from 'admin_management' and to_jsonb(t)->>'admin_id' = p_old->>'admin_id')
    union all select (jsonb_populate_record(null::public.admin_management,p_old)).* where p_table='admin_management' and p_old is not null
  )
  select coalesce(array_agg(channel order by channel), '{}'::text[]) from (
    select 'driver'::text as channel from users u
    where u.id=p_uid and u.account_status='active' and u.status='active'
      and u.anonymized_at is null and u.verification_status='approved'
      and (u.role in ('driver','delivery') or u.user_type in ('driver','delivery'))
      and exists(select 1 from drivers d where d.user_id=u.id
        and d.is_active and d.is_verified and d.verification_status='verified')
    union
    select 'provider' from users u
    where u.id=p_uid and u.account_status='active' and u.status='active'
      and u.anonymized_at is null and u.verification_status='approved'
      and (u.role in ('provider','merchant') or u.user_type in ('provider','merchant'))
      and (exists(select 1 from provider_business_profiles p
                   where p.user_id=u.id and p.status='approved'
                     and (exists(select 1 from merchants m where m.id=p.merchant_id and m.owner_user_id=u.id and m.status='active')
                       or exists(select 1 from service_providers s where s.id=p.service_provider_id and s.user_id=u.id and s.is_verified)))
        or (not exists(select 1 from provider_business_profiles p where p.user_id=u.id)
            and (exists(select 1 from merchants m where m.owner_user_id=u.id and m.status='active')
              or exists(select 1 from service_providers s where s.user_id=u.id and s.is_verified))))
    union
    select 'admin' from users u
    where u.id=p_uid and u.account_status='active' and u.status='active'
      and u.anonymized_at is null and u.verification_status='approved'
      and (u.role='owner' or (u.role='admin' and exists(
        select 1 from admin_management a where a.admin_id=u.id and a.is_active)))
  ) eligible;
$$;
revoke all on function public._approved_app_channels_at(uuid,text,jsonb) from public,anon,authenticated;

create or replace function public._approved_app_channels(p_uid uuid)
returns text[] language sql stable security definer
set search_path=public,pg_temp as $$
  select public._approved_app_channels_at(p_uid,null,null);
$$;
revoke all on function public._approved_app_channels(uuid) from public,anon,authenticated;

create or replace function public.get_my_app_invitations()
returns jsonb language sql stable security definer
set search_path=public,pg_temp as $$
  select jsonb_build_object('channels',public._approved_app_channels(auth.uid()));
$$;
revoke all on function public.get_my_app_invitations() from public,anon;
grant execute on function public.get_my_app_invitations() to authenticated;

create table if not exists public.app_invitation_deliveries(
  user_id uuid not null references public.users(id) on delete cascade,
  channel text not null check(channel in ('driver','provider','admin')),
  created_at timestamptz not null default now(),
  primary key(user_id,channel)
);
alter table public.app_invitation_deliveries enable row level security;
revoke all on public.app_invitation_deliveries from anon,authenticated;

create or replace function public._notify_approved_app_invitation()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid; v_channel text; v_new text; v_before text[] := '{}'::text[];
begin
  if tg_table_name='users' then v_uid:=new.id;
  elsif tg_table_name='merchants' then v_uid:=new.owner_user_id;
  elsif tg_table_name='admin_management' then v_uid:=new.admin_id;
  else v_uid:=new.user_id; end if;
  if v_uid is null then return new; end if;
  if tg_op='UPDATE' then
    v_before:=public._approved_app_channels_at(v_uid,tg_table_name,to_jsonb(old));
  else
    -- Exclude the inserted row when reconstructing eligibility before INSERT.
    v_before:=public._approved_app_channels_at(v_uid,tg_table_name,
      case when tg_table_name='admin_management' then jsonb_build_object('admin_id',to_jsonb(new)->'admin_id')
           else jsonb_build_object('id',to_jsonb(new)->'id') end);
  end if;
  foreach v_channel in array public._approved_app_channels(v_uid) loop
    if v_channel=any(v_before) then continue; end if;
    insert into public.app_invitation_deliveries(user_id,channel)
      values(v_uid,v_channel) on conflict do nothing returning channel into v_new;
    if v_new is not null then
      insert into public.notifications(user_id,title,body,type,data,deep_link,
        idempotency_key,audience,send_push)
      values(v_uid,'تطبيقك جاهز للتحميل','تم تفعيل صلاحيتك. حمّل التطبيق المناسب من دعوات التطبيقات.',
        'account',jsonb_build_object('target_app','customer','channel',v_channel),
        '/profile/app-invitations','app-invitation-'||v_uid||'-'||v_channel,'customer',true)
      on conflict (idempotency_key) where idempotency_key is not null do nothing;
    end if;
    v_new:=null;
  end loop;
  return new;
end; $$;
revoke all on function public._notify_approved_app_invitation() from public,anon,authenticated;

drop trigger if exists app_invitation_user on public.users;
create trigger app_invitation_user after insert or update of role,user_type,verification_status,account_status,status on public.users
for each row execute function public._notify_approved_app_invitation();
drop trigger if exists app_invitation_driver on public.drivers;
create trigger app_invitation_driver after insert or update of is_active,is_verified,verification_status on public.drivers
for each row execute function public._notify_approved_app_invitation();
drop trigger if exists app_invitation_merchant on public.merchants;
create trigger app_invitation_merchant after insert or update of status on public.merchants
for each row execute function public._notify_approved_app_invitation();
drop trigger if exists app_invitation_provider on public.provider_business_profiles;
create trigger app_invitation_provider after insert or update of status,merchant_id,service_provider_id on public.provider_business_profiles
for each row execute function public._notify_approved_app_invitation();
drop trigger if exists app_invitation_service on public.service_providers;
create trigger app_invitation_service after insert or update of is_verified on public.service_providers
for each row execute function public._notify_approved_app_invitation();
drop trigger if exists app_invitation_admin on public.admin_management;
create trigger app_invitation_admin after insert or update of is_active on public.admin_management
for each row execute function public._notify_approved_app_invitation();

insert into public.notification_destinations(route_pattern,allowed_roles,is_active)
values('/profile/app-invitations',null,true)
on conflict(route_pattern) do update set is_active=true,allowed_roles=null;
-- No bulk notification backfill. Existing eligible accounts can see the page;
-- later activation events notify once. Revocation removes live page access.
