-- Staging-only rollback suite for migration 428 (platform suggestions).
-- Synthetic zz-test fixtures inside one rolled-back transaction.
-- Covers: submit RPC validation + rate limit, RLS ownership (insert /
-- select / update own, no cross-user read or write), admin-field guard
-- trigger, admin list + triage RPCs (happy path, invalid status, not
-- found, denied principals), and RLS defense-in-depth behind the RPCs.
begin;

create temporary table zz_ctx(c1 uuid, c2 uuid, adm uuid, plain_admin uuid) on commit drop;
insert into zz_ctx select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid();

insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select c1 as id from zz_ctx union all select c2 from zz_ctx union all
  select adm from zz_ctx union all select plain_admin from zz_ctx
) x;
-- handle_new_user auto-creates public.users from the auth.users insert.
update public.users set role='customer', user_type='customer', verification_status='approved'
where id in (select c1 from zz_ctx union select c2 from zz_ctx);
-- adm is an owner (passes is_admin()); plain_admin has role admin but no
-- active admin_management row (must NOT pass is_admin()).
update public.users set role='owner', user_type='owner', verification_status='approved'
where id = (select adm from zz_ctx);
update public.users set role='admin', user_type='admin', verification_status='approved'
where id = (select plain_admin from zz_ctx);

do $$ declare
  t record; s1 uuid; s2 uuid; v_count int; v_denied boolean; v_i int;
  v_status text; v_reviewed_by uuid; v_row public.suggestions;
begin
  select * into t from zz_ctx;

  -- ============ A. submit_suggestion happy path + validation ==========
  perform set_config('request.jwt.claim.sub', t.c1::text, true);

  s1 := public.submit_suggestion('  زرار تتبع أسرع  ', 'عايزين الزرار يفتح الخريطة على طول', 'app', 'customer');
  assert s1 is not null, 'A1: submit returned id';
  assert exists(select 1 from public.suggestions
    where id = s1 and user_id = t.c1 and app_role = 'customer'
      and category = 'app' and subject = 'زرار تتبع أسرع' and status = 'pending'
      and admin_notes = '{}'),
    'A1: row stored trimmed with defaults';

  s2 := public.submit_suggestion('موضوع', 'وصف', 'general', 'customer');
  assert exists(select 1 from public.suggestions where id = s2 and status = 'pending'),
    'A2: second submit ok';

  -- A3. Empty subject rejected, nothing written.
  v_denied := false; v_count := (select count(*) from public.suggestions where user_id = t.c1);
  begin
    perform public.submit_suggestion('   ', 'وصف', 'general', 'customer');
  exception when others then v_denied := position('subject is required' in sqlerrm) > 0; end;
  assert v_denied, 'A3: empty subject rejected';
  assert (select count(*) from public.suggestions where user_id = t.c1) = v_count,
    'A3: rejected submit wrote nothing';

  -- A4. Invalid category / app_role rejected.
  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'nonsense', 'customer');
  exception when others then v_denied := position('invalid category' in sqlerrm) > 0; end;
  assert v_denied, 'A4a: invalid category rejected';
  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'general', 'nonsense');
  exception when others then v_denied := position('invalid app_role' in sqlerrm) > 0; end;
  assert v_denied, 'A4b: invalid app_role rejected';

  -- A5. Rate limit: 10 per rolling 24h (2 already used -> 8 more ok, 11th fails).
  for v_i in 1..8 loop
    perform public.submit_suggestion('س' || v_i, 'وصف', 'other', 'customer');
  end loop;
  assert (select count(*) from public.suggestions where user_id = t.c1) = 10, 'A5: 10 stored';
  v_denied := false;
  begin
    perform public.submit_suggestion('زيادة', 'وصف', 'other', 'customer');
  exception when others then v_denied := position('too many suggestions' in sqlerrm) > 0; end;
  assert v_denied, 'A5: 11th submit within 24h rejected';

  -- ============ B. RLS ownership (direct table access) ================
  perform set_config('request.jwt.claim.sub', t.c2::text, true);
  set local role authenticated;

  -- B1. c2 cannot see c1's rows.
  assert not exists(select 1 from public.suggestions where user_id = t.c1),
    'B1: cross-user select blocked by RLS';

  -- B2. c2 cannot insert a row as c1.
  v_denied := false;
  begin
    insert into public.suggestions(user_id, app_role, subject, description)
    values (t.c1, 'customer', 'x', 'y');
  exception when others then v_denied := true; end;
  assert v_denied, 'B2: insert with foreign user_id blocked';

  -- B3. c2 cannot update or delete c1's row.
  update public.suggestions set description = 'hack' where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'B3a: cross-user update blocked';
  delete from public.suggestions where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'B3b: cross-user delete blocked';

  reset role;
  -- B4. c1 can edit own text but not handling fields (guard trigger).
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  set local role authenticated;
  update public.suggestions set description = 'وصف معدل' where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 1, 'B4a: own text edit allowed';
  v_denied := false;
  begin
    update public.suggestions set status = 'accepted' where id = s1;
  exception when others then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'B4b: own status edit blocked by guard';
  assert (select status from public.suggestions where id = s1) = 'pending',
    'B4b: status unchanged after blocked edit';
  v_denied := false;
  begin
    update public.suggestions set resolution_note = 'x' where id = s1;
  exception when others then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'B4c: own resolution_note edit blocked by guard';
  reset role;

  -- ============ C. Admin RPCs =========================================
  -- C1. Non-admin principals denied on both admin RPCs.
  for v_i in 1..2 loop
    perform set_config('request.jwt.claim.sub',
      (case v_i when 1 then t.c1 else t.plain_admin end)::text, true);
    v_denied := false;
    begin
      perform 1 from public.admin_list_suggestions(null, 10, 0) limit 1;
    exception when others then v_denied := position('admin only' in sqlerrm) > 0; end;
    assert v_denied, 'C1a: list denied for non-admin principal ' || v_i;
    v_denied := false;
    begin
      perform public.admin_update_suggestion_status(s1, 'reviewing', null);
    exception when others then v_denied := position('admin only' in sqlerrm) > 0; end;
    assert v_denied, 'C1b: status denied for non-admin principal ' || v_i;
  end loop;
  assert (select status from public.suggestions where id = s1) = 'pending',
    'C1: denied calls changed nothing';

  -- C2. Admin happy path: list + triage.
  perform set_config('request.jwt.claim.sub', t.adm::text, true);
  select count(*) into v_count from public.admin_list_suggestions(null, 100, 0);
  assert v_count = 10, 'C2a: admin list returns all rows, got ' || v_count;
  select count(*) into v_count from public.admin_list_suggestions('pending', 100, 0);
  assert v_count = 10, 'C2b: status filter works';

  perform public.admin_update_suggestion_status(s1, 'accepted', 'هنعملها في الإصدار الجاي');
  select status, reviewed_by into v_status, v_reviewed_by
    from public.suggestions where id = s1;
  assert v_status = 'accepted' and v_reviewed_by = t.adm
    and exists(select 1 from public.suggestions
      where id = s1 and resolution_note = 'هنعملها في الإصدار الجاي'
        and reviewed_at is not null),
    'C2c: triage wrote status + note + reviewer';

  select count(*) into v_count from public.admin_list_suggestions('pending', 100, 0);
  assert v_count = 9, 'C2d: filter reflects triage';

  -- C3. Invalid status and unknown id rejected.
  v_denied := false;
  begin
    perform public.admin_update_suggestion_status(s1, 'nonsense', null);
  exception when others then v_denied := position('invalid status' in sqlerrm) > 0; end;
  assert v_denied, 'C3a: invalid status rejected';
  v_denied := false;
  begin
    perform public.admin_update_suggestion_status(gen_random_uuid(), 'reviewing', null);
  exception when others then v_denied := position('not found' in sqlerrm) > 0; end;
  assert v_denied, 'C3b: unknown id rejected';
  v_denied := false;
  begin
    perform 1 from public.admin_list_suggestions('nonsense', 10, 0) limit 1;
  exception when others then v_denied := position('invalid status' in sqlerrm) > 0; end;
  assert v_denied, 'C3c: invalid list filter rejected';

  -- C4. Admin direct-table RLS path also works (mirrors complaints).
  set local role authenticated;
  assert exists(select 1 from public.suggestions where id = s2),
    'C4: admin direct select via RLS';
  reset role;

  -- ============ D. ACL on the RPCs ====================================
  -- D1. anon cannot execute any of the three RPCs.
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  set local role anon;
  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'general', 'customer');
  exception when others then v_denied := true; end;
  assert v_denied, 'D1a: anon submit denied';
  v_denied := false;
  begin
    perform 1 from public.admin_list_suggestions(null, 10, 0) limit 1;
  exception when others then v_denied := true; end;
  assert v_denied, 'D1b: anon list denied';
  reset role;

  perform set_config('request.jwt.claim.sub', '', true);
end $$;

drop table zz_ctx;
rollback;
