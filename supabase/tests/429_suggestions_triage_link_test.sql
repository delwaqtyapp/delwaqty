-- Rollback suite for migration 429 (suggestions triage link + app filter).
-- Synthetic fixtures in one rolled-back transaction, same shape as
-- 428_suggestions_test.sql. Run with psql -v ON_ERROR_STOP=1; any failed
-- assert aborts with a non-zero exit.
--
-- Covers: atomic triage (bad link rolls back the status write), https-only
-- link validation, admin-only RPCs (authenticated AND anon), linked_url
-- hidden from users and unwritable by them directly, app filter,
-- deterministic created_at+id ordering, legacy 3-arg list call, legacy
-- status RPC preserving the link, clearing the link.

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
  v_status text; v_ids uuid[];
begin
  select * into t from zz_ctx;

  perform set_config('request.jwt.claims', json_build_object('sub', t.c1)::text, true);
  set local role authenticated;
  s1 := public.submit_suggestion('a', 'b', 'app', 'customer');
  s2 := public.submit_suggestion('c', 'd', 'general', 'driver');

  -- A: a plain user cannot call any admin RPC
  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'reviewing', null, 'https://github.com/x/y/issues/1', true);
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A1: non-admin cannot triage (42501)';

  v_denied := false;
  begin
    perform * from public.admin_list_suggestions(null, 100, 0, null);
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A2: non-admin cannot list (42501)';

  -- A3: a plain user cannot UPDATE linked_url directly (guard trigger)
  v_denied := false;
  begin
    update public.suggestions set linked_url = 'https://evil.example/x' where id = s1;
  exception when raise_exception or insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A3: direct UPDATE of linked_url blocked by guard';

  -- A4: a plain user cannot read linked_url
  v_denied := false;
  begin
    perform linked_url from public.suggestions where id = s1;
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A4: user cannot select linked_url';

  -- A5/A6: anon is denied both admin RPCs
  reset role;
  set local role anon;
  perform set_config('request.jwt.claims', json_build_object('sub', t.c1)::text, true);
  v_denied := false;
  begin
    perform * from public.admin_list_suggestions(null, 100, 0, null);
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A5: anon cannot list (42501)';
  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'reviewing');
  exception when insufficient_privilege then v_denied := true;
  end;
  assert v_denied, 'A6: anon cannot triage (42501)';

  -- admin context from here
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', t.adm)::text, true);
  set local role authenticated;

  -- C: atomic triage writes status + trimmed link together
  perform public.admin_triage_suggestion(s1, 'reviewing', 'looking', '  https://github.com/x/y/issues/1  ', true);
  reset role;
  select linked_url, status into v_url, v_status from public.suggestions where id = s1;
  assert v_url = 'https://github.com/x/y/issues/1', 'C1: link stored trimmed';
  assert v_status = 'reviewing', 'C2: status written by triage';
  set local role authenticated;

  -- C3: invalid link aborts the WHOLE triage (status must not move)
  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'accepted', null, 'http://insecure.example/1', true);
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C3: non-https link rejected 22023';
  reset role;
  select status into v_status from public.suggestions where id = s1;
  assert v_status = 'reviewing', 'C4: failed triage left status untouched (atomic)';
  select linked_url into v_url from public.suggestions where id = s1;
  assert v_url = 'https://github.com/x/y/issues/1', 'C5: failed triage left link untouched (atomic)';
  set local role authenticated;

  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'accepted', null, 'javascript:alert(1)', true);
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C6: javascript: link rejected 22023';

  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'accepted', null, 'https://a.example/' || repeat('x', 500), true);
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C7: >500-char link rejected 22023';

  v_denied := false;
  begin
    perform public.admin_triage_suggestion(s1, 'bogus-status');
  exception when invalid_parameter_value then v_denied := true;
  end;
  assert v_denied, 'C8: invalid status rejected 22023';

  v_denied := false;
  begin
    perform public.admin_triage_suggestion(gen_random_uuid(), 'accepted');
  exception when no_data_found then v_denied := true;
  end;
  assert v_denied, 'C9: unknown id raises P0002';

  -- D: app filter
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

  -- E: legacy 3-argument list call still works (4th arg defaults)
  select count(*) into v_n from public.admin_list_suggestions(null, 100, 0)
   where id in (s1, s2);
  assert v_n = 2, 'E1: legacy 3-arg list call works';

  -- E2: deterministic order: same-transaction rows share created_at,
  -- so the id DESC tiebreaker must order them.
  select array_agg(id) into v_ids
    from (select id from public.admin_list_suggestions(null, 100, 0, null)
           where id in (s1, s2)) x;
  assert v_ids = (select array_agg(id order by id desc) from (values (s1), (s2)) v(id)),
    'E2: created_at ties break by id DESC';

  -- F: legacy status RPC preserves the link (older app builds)
  perform public.admin_update_suggestion_status(s1, 'accepted', 'done');
  reset role;
  select linked_url, status into v_url, v_status from public.suggestions where id = s1;
  assert v_status = 'accepted', 'F1: legacy status RPC updates status';
  assert v_url = 'https://github.com/x/y/issues/1', 'F2: legacy status RPC preserves link';
  set local role authenticated;

  -- G: triage without p_update_link preserves the link too
  perform public.admin_triage_suggestion(s1, 'implemented', 'shipped');
  reset role;
  select linked_url into v_url from public.suggestions where id = s1;
  assert v_url = 'https://github.com/x/y/issues/1', 'G1: status-only triage preserves link';
  set local role authenticated;

  -- H: blank link with p_update_link clears
  perform public.admin_triage_suggestion(s1, 'implemented', 'shipped', '   ', true);
  reset role;
  select linked_url into v_url from public.suggestions where id = s1;
  assert v_url is null, 'H1: blank clears link';
end $$;

rollback;
