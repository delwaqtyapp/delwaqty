-- Staging rollback-only. Requires migration391. No outbound messaging.
begin;
create temporary table _t391(provider_id uuid,merchant_id uuid,owner_id uuid);
insert into _t391 values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email,raw_user_meta_data)
select provider_id,'zz-test-391-provider@example.invalid','{"full_name":"zz-test-391-provider","user_type":"provider"}'::jsonb from _t391;
insert into auth.users(id,email,raw_user_meta_data)
select merchant_id,'zz-test-391-merchant@example.invalid','{"full_name":"zz-test-391-merchant","user_type":"merchant"}'::jsonb from _t391;
insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'zz-test-391-owner@example.invalid','{"full_name":"zz-test-391-owner","user_type":"customer"}'::jsonb from _t391;
update public.users set role='owner',user_type='owner',verification_status='approved' where id=(select owner_id from _t391);
do $test$
declare p uuid:=(select provider_id from _t391);m uuid:=(select merchant_id from _t391);o uuid:=(select owner_id from _t391);pr uuid;target uuid;
begin
assert not exists(select 1 from merchants where owner_user_id=p),'provider signup no storefront';
assert exists(select 1 from merchants where owner_user_id=m and type='restaurant'),'merchant signup retained';
perform set_config('request.jwt.claim.sub',p::text,true);
assert resolve_my_merchant() is null,'provider app initial entry null';
assert not exists(select 1 from merchants where owner_user_id=p),'resolver cannot create service storefront';
insert into provider_business_profiles(user_id,category_type,display_name,status) values(p,'plumbing','zz-test-391-plumber','pending') returning id into pr;
perform set_config('request.jwt.claim.sub',o::text,true);
perform decide_provider_profile_request(pr,'approved');
select service_provider_id into target from provider_business_profiles where id=pr;
assert target is not null,'approved home profile linked';
assert exists(select 1 from service_providers where id=target and user_id=p),'service target exists';
assert not exists(select 1 from merchants where owner_user_id=p),'home approval no merchant';
update users set active_provider_category='plumbing' where id=p;
perform set_config('request.jwt.claim.sub',p::text,true);
assert resolve_my_merchant() is null,'home entry stays null';
insert into provider_business_profiles(user_id,category_type,display_name,status) values(p,'grocery','zz-test-391-grocery','pending') returning id into pr;
update users set active_provider_category='grocery' where id=p;
assert resolve_my_merchant() is null,'pending category cannot synthesize target';
perform set_config('request.jwt.claim.sub',o::text,true);
perform decide_provider_profile_request(pr,'approved');
select merchant_id into target from provider_business_profiles where id=pr;
assert target is not null,'approved merchant category gets target';
perform set_config('request.jwt.claim.sub',p::text,true);
assert resolve_my_merchant()=target,'approved grocery resolves own target';
update provider_business_profiles set status='suspended' where id=pr;
assert resolve_my_merchant() is null,'suspended profile denied';
perform set_config('request.jwt.claim.sub','',true);
assert resolve_my_merchant() is null,'anonymous null';
end $test$;
select 'PASS391: signup triggers, provider first entry, home approval, grocery approval, suspension, merchant legacy, anon' result;
rollback;
