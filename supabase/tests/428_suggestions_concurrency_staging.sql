-- 428: two-session rate-limit race proof for submit_suggestion.
-- *** COMMITTED-FIXTURE STAGING TEST — NOT a rollback-only suite. ***
-- Run section by section: setup -> race_1 & race_2 (parallel)
-- -> verify -> cleanup.
-- Extract a section with: awk '/-- == NAME ==/{f=1;next}/-- == /{if(f)exit}f'
--
-- Review #145:
-- (a) Fresh-only: setup ABORTS if the fixture user or the log table
--     already exists (no ON CONFLICT, no pre-delete). Cleanup deletes
--     only rows whose ownership is verified by the fixture email marker.
-- (b) Real overlap proof: race_1's transaction takes the per-user
--     advisory xact lock inside submit_suggestion and HOLDS it across
--     pg_sleep(4) before committing. race_2 runs concurrently, blocks on
--     the same lock, and after race_1 commits it recounts, hits the
--     10-per-24h limit and is rejected P0001. race_2 records its denial
--     and wait time in zz_sugg_race_log; verify asserts denied=true and
--     waited >= 3s (i.e. it really waited on race_1's lock), plus final
--     count exactly 10 with exactly one race row (race_1's).

-- == setup ==
do $$
begin
  assert not exists(select 1 from auth.users
    where id = 'face0000-0000-4000-8000-0000000000d1'),
    '428 race fixture user already exists; aborting (fresh-only)';
end $$;
create table public.zz_sugg_race_log(denied boolean not null, waited_seconds numeric not null);
revoke all on public.zz_sugg_race_log from public, anon, authenticated;
insert into auth.users(id,email) values
  ('face0000-0000-4000-8000-0000000000d1','zz-sugg-race@example.invalid');
update public.users set role='customer', user_type='customer', verification_status='approved'
where id = 'face0000-0000-4000-8000-0000000000d1';
insert into public.suggestions(user_id, app_role, category, subject, description)
select 'face0000-0000-4000-8000-0000000000d1', 'customer', 'other', 'zz-race-seed-' || g, 'seed'
from generate_series(1, 9) g;

-- == race_1 ==
-- Takes the per-user advisory xact lock inside submit_suggestion and
-- holds it across the sleep; commits at ~4s.
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000d1',true);
select public.submit_suggestion('race-winner', 'race body', 'other', 'customer');
select pg_sleep(4);
commit;

-- == race_2 ==
-- Runs concurrently with race_1. Blocks on race_1's advisory lock until
-- race_1 commits, then recounts (now 10) and is rejected P0001. Records
-- denial + wait time for the verify section. Without serialization this
-- would insert an 11th row in well under a second instead.
do $$
declare
  t0 timestamptz := clock_timestamp();
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000d1',true);
  begin
    perform public.submit_suggestion('race-loser', 'race body', 'other', 'customer');
  exception when raise_exception then
    v_denied := position('too many suggestions' in sqlerrm) > 0;
  end;
  insert into public.zz_sugg_race_log(denied, waited_seconds)
  values (v_denied, extract(epoch from clock_timestamp() - t0));
end $$;

-- == verify ==
do $$
declare v_total int; v_winner int; v_loser int; v_denied boolean; v_waited numeric;
begin
  select count(*) into v_total from public.suggestions
   where user_id = 'face0000-0000-4000-8000-0000000000d1';
  select count(*) into v_winner from public.suggestions
   where user_id = 'face0000-0000-4000-8000-0000000000d1' and subject = 'race-winner';
  select count(*) into v_loser from public.suggestions
   where user_id = 'face0000-0000-4000-8000-0000000000d1' and subject = 'race-loser';
  assert v_total = 10, 'race: expected exactly 10 suggestions, got ' || v_total;
  assert v_winner = 1, 'race: expected race_1 row, got ' || v_winner;
  assert v_loser = 0, 'race: race_2 must not have inserted, got ' || v_loser;
  select denied, waited_seconds into v_denied, v_waited from public.zz_sugg_race_log;
  assert v_denied, 'race: race_2 was not rejected (serialization failed)';
  assert v_waited >= 3, 'race: race_2 did not wait on race_1''s lock (waited ' || v_waited || 's)';
end $$;

-- == cleanup ==
-- Ownership-verified: only touches rows whose fixture email matches.
delete from public.suggestions s using auth.users u
 where s.user_id = u.id
   and u.id = 'face0000-0000-4000-8000-0000000000d1'
   and u.email = 'zz-sugg-race@example.invalid';
delete from auth.users
 where id = 'face0000-0000-4000-8000-0000000000d1'
   and email = 'zz-sugg-race@example.invalid';
drop table if exists public.zz_sugg_race_log;
