-- 428: two-session rate-limit race proof for submit_suggestion.
-- *** COMMITTED-FIXTURE STAGING TEST — NOT a rollback-only suite. ***
-- Real two-session races need committed rows, so every section commits.
-- Run section by section: setup -> race_1 & race_2 (parallel)
-- -> verify -> cleanup.
-- Extract a section with: awk '/-- == NAME ==/{f=1;next}/-- == /{if(f)exit}f'
-- Fixture user holds 9 suggestions; two overlapping submits race for the
-- 10th slot. The per-user advisory xact lock serializes them: the loser
-- recounts after the winner commits and is rejected (P0001), so the
-- final count is exactly 10, never 11.

-- == setup ==
insert into auth.users(id,email) values
  ('face0000-0000-4000-8000-0000000000d1','zz-sugg-race@example.invalid')
on conflict (id) do nothing;
update public.users set role='customer', user_type='customer', verification_status='approved'
where id = 'face0000-0000-4000-8000-0000000000d1';
delete from public.suggestions where user_id = 'face0000-0000-4000-8000-0000000000d1';
insert into public.suggestions(user_id, app_role, category, subject, description)
select 'face0000-0000-4000-8000-0000000000d1', 'customer', 'other', 'zz-race-seed-' || g, 'seed'
from generate_series(1, 9) g;

-- == race_1 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000d1',true);
select pg_sleep(1.5);
select public.submit_suggestion('race-subject', 'race body', 'other', 'customer');
commit;

-- == race_2 ==
begin;
select set_config('request.jwt.claim.sub','face0000-0000-4000-8000-0000000000d1',true);
select pg_sleep(1.5);
select public.submit_suggestion('race-subject', 'race body', 'other', 'customer');
commit;

-- == verify ==
do $$
declare v_total int; v_race int;
begin
  select count(*) into v_total from public.suggestions
   where user_id = 'face0000-0000-4000-8000-0000000000d1';
  select count(*) into v_race from public.suggestions
   where user_id = 'face0000-0000-4000-8000-0000000000d1' and subject = 'race-subject';
  assert v_total = 10, 'race: expected exactly 10 suggestions, got ' || v_total;
  assert v_race = 1, 'race: expected exactly 1 race winner, got ' || v_race;
end $$;

-- == cleanup ==
delete from public.suggestions where user_id = 'face0000-0000-4000-8000-0000000000d1';
delete from auth.users where id = 'face0000-0000-4000-8000-0000000000d1';
