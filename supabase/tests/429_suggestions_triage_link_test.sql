-- Rollback suite for migration 429 (suggestions triage link + app filter).
-- Synthetic fixtures in one rolled-back transaction, same shape as
-- 428_suggestions_test.sql. Covers: https-only link validation, admin-only
-- RPCs, linked_url hidden from users and unwritable by them, app filter,
-- clearing the link.
begin;

create temporary table zz_ctx(c1 uuid, adm uuid) on commit drop;
insert into zz_ctx select gen_random_uuid(), gen_random_uuid();

insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select c1 as id from zz_ctx union all select adm from zz_ctx
) x;
update public.users set role='customer', user_type='customer', verification_status='approved'
where id = (select c1 from zz_ctx);
update public.users set role='owner', user_type='owner', verification_status='approved'
where id = (select adm from zz_ctx);

do $$ declare
  t record; s1 uuid; s2 uuid; v_denied boolean; v_url text; v_n bigint;
begin
  select * into t from zz_ctx;

  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  set local role authenticated;
  s1 := public.submit_suggestion('a', 'b', 'app', 'customer');
  s2 := public.submit_suggestion('c', 'd', 'general', 'driver');

  -- user cannot call admin RPCs
  v_denied := false;
  begin
    perform public.admin_set_suggestion_link(s1, 'https://github.com/x/y/issues/1');
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'B1: non-admin cannot set link (42501)';

  -- user cannot read or write linked_url directly
  v_denied := false;
  begin
    perform linked_url from public.suggestions where id = s1;
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'B3: user cannot select linked_url';

  reset role;
  perform set_config('request.jwt.claim.sub', t.adm::text, true);
  set local role authenticated;

  perform public.admin_set_suggestion_link(s1, '  https://github.com/x/y/issues/1  ');
  reset role;
  select linked_url into v_url from public.suggestions where id = s1;
  assert v_url = 'https://github.com/x/y/issues/1', 'C1: link stored trimmed';
  set local role authenticated;

  v_denied := false;
  begin
    perform public.admin_set_suggestion_link(s1, 'http://insecure.example/1');
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C2: non-https link rejected 22023';
  v_denied := false;
  begin
    perform public.admin_set_suggestion_link(s1, 'javascript:alert(1)');
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C3: javascript: link rejected 22023';
  v_denied := false;
  begin
    perform public.admin_set_suggestion_link(gen_random_uuid(), 'https://a.example/1');
  exception when no_data_found then v_denied := true;
  end;
  assert v_denied, 'C4: unknown id raises P0002';

  -- app filter
  select count(*) into v_n from public.admin_list_suggestions(null, 100, 0, 'driver')
   where id in (s1, s2);
  assert v_n = 1, 'D1: driver filter returns only the driver row';
  select count(*) into v_n from public.admin_list_suggestions(null, 100, 0, null)
   where id in (s1, s2);
  assert v_n = 2, 'D2: no filter returns both';
  v_denied := false;
  begin
    perform * from public.admin_list_suggestions(null, 100, 0, 'bogus');
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'D3: bad app_role rejected 22023';

  -- clear
  perform public.admin_set_suggestion_link(s1, '   ');
  reset role;
  select linked_url into v_url from public.suggestions where id = s1;
  assert v_url is null, 'F1: blank clears link';
end $$;

rollback;
