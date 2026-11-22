-- Run on staging after migration 389. All fixtures and queued push work roll back.
begin;
create temporary table invitation_test_context(uid uuid, supervisor uuid);
insert into invitation_test_context values(gen_random_uuid(),gen_random_uuid());
insert into public.users(id,email,full_name,role,user_type,verification_status,account_status,status)
select supervisor,'zz-test-invitation-supervisor@example.invalid','zz-test-invitation-supervisor','owner','owner','approved','active','active' from invitation_test_context;
insert into public.users(id,email,full_name,role,user_type,verification_status,account_status,status)
select uid,'zz-test-invitation@example.invalid','zz-test-invitation','admin','admin','pending','active','active' from invitation_test_context;
insert into public.admin_management(admin_id,supervisor_id,is_active)
select uid,supervisor,true from invitation_test_context;
do $$ declare u uuid:=(select uid from invitation_test_context); begin
  assert public._approved_app_channels(u)='{}'::text[], 'pending admin must be hidden';
  update public.users set verification_status='rejected' where id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'rejected admin must be hidden';
  assert not exists(select 1 from public.notifications where user_id=u and deep_link='/profile/app-invitations'), 'no pending notifications';
  update public.users set verification_status='approved' where id=u;
  assert public._approved_app_channels(u)=array['admin'], 'approved active tree admin invited';
  assert (select count(*) from public.notifications where user_id=u and deep_link='/profile/app-invitations')=1, 'one approval notification';
  assert exists(select 1 from public.notifications where user_id=u and deep_link='/profile/app-invitations' and audience='customer'), 'customer audience';
  update public.users set status='active' where id=u;
  update public.admin_management set is_active=true where admin_id=u;
  assert (select count(*) from public.notifications where user_id=u and deep_link='/profile/app-invitations')=1, 'no duplicate on unrelated update';
  update public.admin_management set is_active=false where admin_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'inactive admin hidden';
  update public.admin_management set is_active=true where admin_id=u;
  assert (select count(*) from public.notifications where user_id=u and deep_link='/profile/app-invitations')=1, 'one lifetime invite per channel';
  -- Simulate pre-migration eligible account with no delivery ledger.
  delete from public.notifications where user_id=u and deep_link='/profile/app-invitations';
  delete from public.app_invitation_deliveries where user_id=u;
  update public.users set status='active' where id=u;
  update public.admin_management set is_active=true where admin_id=u;
  assert not exists(select 1 from public.notifications where user_id=u and deep_link='/profile/app-invitations'), 'no lazy existing-user backfill';
  -- An unrelated row INSERT cannot notify an existing eligible channel.
  insert into public.merchants(owner_user_id,name,status) values(u,'zz-test-invitation-unrelated','pending');
  assert not exists(select 1 from public.notifications where user_id=u and deep_link='/profile/app-invitations'), 'insert must compare previous eligibility';
  update public.users set account_status='suspended' where id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'suspended admin hidden';
  update public.users set account_status='active',role='delivery',user_type='delivery' where id=u;
  insert into public.drivers(user_id,full_name,is_active,is_verified,verification_status) values(u,'zz-test-invitation-driver',true,false,'pending');
  assert public._approved_app_channels(u)='{}'::text[], 'pending driver hidden';
  update public.drivers set is_verified=true,verification_status='verified' where user_id=u;
  assert public._approved_app_channels(u)=array['driver'], 'verified driver invited';
  update public.drivers set is_active=false where user_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'inactive driver hidden';
  update public.users set role='provider',user_type='provider' where id=u;
  update public.merchants set status='active' where owner_user_id=u;
  assert public._approved_app_channels(u)=array['provider'], 'legacy active provider invited';
  insert into public.provider_business_profiles(user_id,category_type,display_name,status,merchant_id)
   select u,'restaurant','zz-test-invitation-profile','pending',id from public.merchants where owner_user_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'pending profile blocks legacy fallback';
  update public.provider_business_profiles set status='approved' where user_id=u;
  assert public._approved_app_channels(u)=array['provider'], 'approved profile invited';
  update public.provider_business_profiles set status='suspended' where user_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'suspended profile cannot use legacy fallback';
  update public.provider_business_profiles set status='approved' where user_id=u;
  update public.merchants set status='suspended' where owner_user_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'suspended store hidden';
  -- Approved profile can be linked to its active target after both exist.
  delete from public.notifications where user_id=u and deep_link='/profile/app-invitations';
  delete from public.app_invitation_deliveries where user_id=u;
  update public.provider_business_profiles set merchant_id=null where user_id=u;
  update public.merchants set status='active' where owner_user_id=u;
  assert public._approved_app_channels(u)='{}'::text[], 'unlinked profile hidden';
  update public.provider_business_profiles set merchant_id=(select id from public.merchants where owner_user_id=u limit 1) where user_id=u;
  assert public._approved_app_channels(u)=array['provider'], 'linked profile eligible';
  assert (select count(*) from public.notifications where user_id=u and deep_link='/profile/app-invitations')=1, 'link-only activation notifies';
  assert not has_function_privilege('anon','public.get_my_app_invitations()','EXECUTE'), 'anon cannot fetch';
  assert not has_function_privilege('authenticated','public._approved_app_channels(uuid)','EXECUTE'), 'cannot inspect other users';
  assert not has_function_privilege('authenticated','public._approved_app_channels_at(uuid,text,jsonb)','EXECUTE'), 'cannot supply old rows';
  assert not has_table_privilege('authenticated','public.app_invitation_deliveries','INSERT'), 'cannot forge ledger';
end $$;
select 'PASS: invitation predicates, transitions, notification routing/dedupe and permissions' as result;
rollback;
