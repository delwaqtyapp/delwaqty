-- Staging-only rollback suite for migration 428 v2 (platform
-- suggestions). Synthetic zz-test fixtures inside one rolled-back
-- transaction. Specific SQLSTATEs throughout (no WHEN OTHERS).
-- Covers: submit RPC validation incl. length pre-checks, rate limit,
-- forged direct INSERT blocked (RPC-only creation), RLS ownership,
-- guard-trigger protection of every handling field, internal-column
-- hiding (admin_notes / reviewed_at / reviewed_by), admin list + triage
-- RPCs with fixture-scoped counts, resolution_note clearing, denied
-- principals, anon ACL denial, and real authenticated-role RPC calls.
-- The two-session rate-limit race lives in
-- 428_suggestions_concurrency_staging.sql (committed fixtures).
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
  v_status text; v_reviewed_by uuid; v_notes text[];
begin
  select * into t from zz_ctx;

  -- ============ A. submit_suggestion (real authenticated role) ========
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  set local role authenticated;

  s1 := public.submit_suggestion('  زرار تتبع أسرع  ', 'عايزين الزرار يفتح الخريطة على طول', 'app', 'customer');
  assert s1 is not null, 'A1: submit returned id';
  reset role; -- internal columns are hidden from authenticated; check as owner
  assert exists(select 1 from public.suggestions
    where id = s1 and user_id = t.c1 and app_role = 'customer'
      and category = 'app' and subject = 'زرار تتبع أسرع' and status = 'pending'
      and admin_notes = '{}' and reviewed_at is null and reviewed_by is null),
    'A1: row stored trimmed with defaults, created_at server-owned';
  set local role authenticated;

  s2 := public.submit_suggestion('موضوع', 'وصف', 'general', 'customer');

  -- A2. Validation with specific SQLSTATEs (22023 invalid_parameter_value).
  v_denied := false;
  begin
    perform public.submit_suggestion('   ', 'وصف', 'general', 'customer');
  exception when invalid_parameter_value then
    v_denied := position('subject is required' in sqlerrm) > 0;
  end;
  assert v_denied, 'A2a: empty subject rejected 22023';

  v_denied := false;
  begin
    perform public.submit_suggestion(repeat('س', 121), 'وصف', 'general', 'customer');
  exception when invalid_parameter_value then
    v_denied := position('subject too long' in sqlerrm) > 0;
  end;
  assert v_denied, 'A2b: 121-char subject rejected 22023 (pre-checked)';

  v_denied := false;
  begin
    perform public.submit_suggestion('س', repeat('و', 2001), 'general', 'customer');
  exception when invalid_parameter_value then
    v_denied := position('description too long' in sqlerrm) > 0;
  end;
  assert v_denied, 'A2c: 2001-char description rejected 22023 (pre-checked)';

  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'nonsense', 'customer');
  exception when invalid_parameter_value then
    v_denied := position('invalid category' in sqlerrm) > 0;
  end;
  assert v_denied, 'A2d: invalid category rejected 22023';

  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'general', 'nonsense');
  exception when invalid_parameter_value then
    v_denied := position('invalid app_role' in sqlerrm) > 0;
  end;
  assert v_denied, 'A2e: invalid app_role rejected 22023';

  reset role;
  assert (select count(*) from public.suggestions where user_id = t.c1) = 2,
    'A2: rejected submits wrote nothing';
  set local role authenticated;

  -- A3. Rate limit: 10 per rolling 24h (2 used -> 8 more ok, 11th fails P0001).
  for v_i in 1..8 loop
    perform public.submit_suggestion('س' || v_i, 'وصف', 'other', 'customer');
  end loop;
  reset role;
  assert (select count(*) from public.suggestions where user_id = t.c1) = 10, 'A3: 10 stored';
  set local role authenticated;
  v_denied := false;
  begin
    perform public.submit_suggestion('زيادة', 'وصف', 'other', 'customer');
  exception when raise_exception then
    v_denied := position('too many suggestions' in sqlerrm) > 0;
  end;
  assert v_denied, 'A3: 11th submit within 24h rejected P0001';

  -- ============ B. Forged direct INSERT blocked (RPC-only creation) ===
  -- B1. Hostile insert carrying every handling field at once.
  v_denied := false;
  begin
    insert into public.suggestions(user_id, app_role, category, subject, description,
      status, admin_notes, resolution_note, reviewed_at, reviewed_by, created_at)
    values (t.c1, 'customer', 'general', 'مزور', 'مزور',
      'implemented', array['مزور'], 'مزور', now(), t.adm, now() - interval '30 days');
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'B1: forged direct INSERT denied (no INSERT grant/policy)';
  reset role;
  assert (select count(*) from public.suggestions where user_id = t.c1) = 10,
    'B1: forged insert wrote nothing';
  set local role authenticated;

  -- ============ C. RLS ownership + guard (authenticated role) =========
  perform set_config('request.jwt.claim.sub', t.c2::text, true);

  -- C1. c2 cannot see c1's rows.
  assert not exists(select 1 from public.suggestions where user_id = t.c1),
    'C1: cross-user select blocked by RLS';

  -- C2. c2 cannot insert even as themself via the table (RPC only).
  v_denied := false;
  begin
    insert into public.suggestions(user_id, app_role, subject, description)
    values (t.c2, 'customer', 'x', 'y');
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'C2: direct self-insert also denied';

  -- C3. c2 cannot update or delete c1's row.
  update public.suggestions set description = 'hack' where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'C3a: cross-user update blocked';
  delete from public.suggestions where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'C3b: cross-user delete blocked';

  -- C4. c1 edits: own text ok; every handling field blocked by the guard.
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  update public.suggestions set description = 'وصف معدل' where id = s1;
  get diagnostics v_count = row_count;
  assert v_count = 1, 'C4a: own text edit allowed';

  v_denied := false;
  begin
    update public.suggestions set status = 'accepted' where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4b: own status edit blocked by guard';

  v_denied := false;
  begin
    update public.suggestions set admin_notes = array['مزور'] where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4c: own admin_notes edit blocked by guard';

  v_denied := false;
  begin
    update public.suggestions set resolution_note = 'x' where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4d: own resolution_note edit blocked by guard';

  v_denied := false;
  begin
    update public.suggestions set reviewed_at = now() where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4e: own reviewed_at edit blocked by guard';

  v_denied := false;
  begin
    update public.suggestions set reviewed_by = t.c1 where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4f: own reviewed_by edit blocked by guard';

  v_denied := false;
  begin
    update public.suggestions set created_at = now() - interval '30 days' where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C4g: own created_at edit blocked by guard';

  -- C5. Cross-user user_id move denied (guard protects user_id).
  v_denied := false;
  begin
    update public.suggestions set user_id = t.c2 where id = s1;
  exception when raise_exception then
    v_denied := position('managed by the admin team' in sqlerrm) > 0;
  end;
  assert v_denied, 'C5: user_id move blocked by guard';
  reset role;
  assert (select user_id from public.suggestions where id = s1) = t.c1,
    'C5: row still owned by c1';
  set local role authenticated;

  -- ============ D. Internal columns hidden from own read ==============
  -- D1. c1 can select the granted columns but NOT admin_notes.
  perform 1 from public.suggestions
    where id = s1 and resolution_note is null limit 1;
  v_denied := false;
  begin
    perform array_length(admin_notes, 1) from public.suggestions where id = s1;
  exception when insufficient_privilege then v_denied := true;
            when undefined_column then v_denied := true;
  end;
  assert v_denied, 'D1a: admin_notes hidden from authenticated select';
  v_denied := false;
  begin
    perform reviewed_at from public.suggestions where id = s1;
  exception when insufficient_privilege then v_denied := true;
            when undefined_column then v_denied := true;
  end;
  assert v_denied, 'D1b: reviewed_at hidden from authenticated select';
  v_denied := false;
  begin
    perform reviewed_by from public.suggestions where id = s1;
  exception when insufficient_privilege then v_denied := true;
            when undefined_column then v_denied := true;
  end;
  assert v_denied, 'D1c: reviewed_by hidden from authenticated select';

  reset role;

  -- ============ E. Admin RPCs (real authenticated role) ===============
  -- E1. Denied principals on both admin RPCs, fixture-scoped no-change.
  for v_i in 1..2 loop
    perform set_config('request.jwt.claim.sub',
      (case v_i when 1 then t.c1 else t.plain_admin end)::text, true);
    set local role authenticated;
    v_denied := false;
    begin
      perform 1 from public.admin_list_suggestions(null, 10, 0) limit 1;
    exception when insufficient_privilege then
      v_denied := position('admin only' in sqlerrm) > 0;
    end;
    assert v_denied, 'E1a: list denied 42501 for principal ' || v_i;
    v_denied := false;
    begin
      perform public.admin_update_suggestion_status(s1, 'reviewing', null);
    exception when insufficient_privilege then
      v_denied := position('admin only' in sqlerrm) > 0;
    end;
    assert v_denied, 'E1b: status denied 42501 for principal ' || v_i;
    reset role;
  end loop;
  reset role;
  assert (select status from public.suggestions where id = s1) = 'pending',
    'E1: denied calls changed nothing';

  -- E2. Admin happy path with fixture-scoped counts.
  perform set_config('request.jwt.claim.sub', t.adm::text, true);
  set local role authenticated;
  select count(*) into v_count
    from public.admin_list_suggestions(null, 100, 0) l where l.user_id = t.c1;
  assert v_count = 10, 'E2a: admin list returns fixture rows, got ' || v_count;
  select count(*) into v_count
    from public.admin_list_suggestions('pending', 100, 0) l where l.user_id = t.c1;
  assert v_count = 10, 'E2b: status filter works';

  perform public.admin_update_suggestion_status(s1, 'accepted', 'هنعملها في الإصدار الجاي');
  reset role; -- reviewed_at/reviewed_by are internal columns
  select status, reviewed_by into v_status, v_reviewed_by
    from public.suggestions where id = s1;
  assert v_status = 'accepted' and v_reviewed_by = t.adm
    and exists(select 1 from public.suggestions
      where id = s1 and resolution_note = 'هنعملها في الإصدار الجاي'
        and reviewed_at is not null),
    'E2c: triage wrote status + note + reviewer';
  set local role authenticated;

  -- E2d. Admin can CLEAR resolution_note (unconditional set).
  perform public.admin_update_suggestion_status(s1, 'reviewing', null);
  reset role;
  assert exists(select 1 from public.suggestions
    where id = s1 and status = 'reviewing' and resolution_note is null),
    'E2d: resolution_note cleared';
  set local role authenticated;

  -- E2e. Admin writes internal admin_notes directly (RLS admin update);
  -- the admin list RPC exposes them, the user read path never does.
  update public.suggestions set admin_notes = array['ملاحظة داخلية'] where id = s2;
  get diagnostics v_count = row_count;
  assert v_count = 1, 'E2e: admin direct admin_notes write allowed';
  reset role; -- RPC is definer-owned, but read the row directly for clarity
  select s.admin_notes into v_notes from public.suggestions s where s.id = s2;
  assert v_notes = array['ملاحظة داخلية'],
    'E2e: admin_notes written';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', t.adm::text, true);
  select l.admin_notes into v_notes
    from public.admin_list_suggestions(null, 100, 0) l where l.id = s2;
  reset role;
  assert v_notes = array['ملاحظة داخلية'],
    'E2e: admin_notes visible through the admin RPC';

  -- E3. Invalid status / unknown id with specific SQLSTATEs.
  perform set_config('request.jwt.claim.sub', t.adm::text, true);
  set local role authenticated;
  v_denied := false;
  begin
    perform public.admin_update_suggestion_status(s1, 'nonsense', null);
  exception when invalid_parameter_value then
    v_denied := position('invalid status' in sqlerrm) > 0;
  end;
  assert v_denied, 'E3a: invalid status rejected 22023';
  v_denied := false;
  begin
    perform public.admin_update_suggestion_status(gen_random_uuid(), 'reviewing', null);
  exception when no_data_found then
    v_denied := position('not found' in sqlerrm) > 0;
  end;
  assert v_denied, 'E3b: unknown id rejected P0002';
  v_denied := false;
  begin
    perform 1 from public.admin_list_suggestions('nonsense', 10, 0) limit 1;
  exception when invalid_parameter_value then
    v_denied := position('invalid status' in sqlerrm) > 0;
  end;
  assert v_denied, 'E3c: invalid list filter rejected 22023';
  reset role;

  -- ============ F. anon ACL ===========================================
  perform set_config('request.jwt.claim.sub', t.c1::text, true);
  set local role anon;
  v_denied := false;
  begin
    perform public.submit_suggestion('س', 'وصف', 'general', 'customer');
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'F1a: anon submit denied (function ACL)';
  v_denied := false;
  begin
    perform 1 from public.admin_list_suggestions(null, 10, 0) limit 1;
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'F1b: anon list denied (function ACL)';
  v_denied := false;
  begin
    perform public.admin_update_suggestion_status(s1, 'reviewing', null);
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'F1c: anon admin_update denied (function ACL)';
  reset role;

  perform set_config('request.jwt.claim.sub', '', true);
end $$;

drop table zz_ctx;
rollback;
