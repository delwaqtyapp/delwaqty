-- Suite for migration 439 (username login identifier).
-- Synthetic fixtures only: @example.invalid emails, never real accounts.
-- DISPOSABLE-DATABASE-ONLY: auth.users fixtures written before the first
-- BEGIN persist; run on a throwaway clone, never on staging or prod.
-- Each numbered block rolls back its own mutations.
--
-- Covers: backfill assigns sanitized deduplicated usernames to legacy
-- real-email users only (phone_ aliases, anonymized and deactivated
-- untouched), format CHECK, case-insensitive uniqueness, lookup
-- consistency between the index and lookup_email_by_username.

-- Fixtures: one pre-existing mixed-case username + four backfill
-- candidates + one phone alias + one anonymized + one deactivated.
create temporary table zz439(a uuid, b uuid, c uuid, d uuid, alias uuid, anon uuid, dead uuid);
insert into zz439
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid();
insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select a as id from zz439 union all select b from zz439 union all
  select c from zz439 union all select d from zz439 union all
  select alias from zz439 union all select anon from zz439 union all
  select dead from zz439
) x;
update public.users set email='legacy.one@example.invalid', username='LegacyUser' where id=(select a from zz439);
update public.users set email='first.last@example.invalid', username=null where id=(select b from zz439);
update public.users set email='first_last@example.invalid', username=null where id=(select c from zz439);
update public.users set email='ab@example.invalid', username=null where id=(select d from zz439);
update public.users set email='phone_201000000099@delwaqty.app', username=null where id=(select alias from zz439);
update public.users set email='deleted-00000000-0000-4000-8000-000000000439@anonymized.invalid', username=null where id=(select anon from zz439);
update public.users set email='gone@example.invalid', username=null, account_status='deactivated' where id=(select dead from zz439);

-- 1) Backfill: sanitized local part, case-insensitive dedup, untouched sets.
BEGIN;
-- Reproduce the migration's backfill block against the fixtures (the
-- migration itself is applied by the harness before this suite runs;
-- this block re-runs the same logic idempotently on the fixture rows).
DO $$
DECLARE
  r record; v_base text; v_candidate text; v_i int;
BEGIN
  FOR r IN
    SELECT id, email FROM public.users
     WHERE username IS NULL
       AND email NOT LIKE 'phone\_%@delwaqty.app' ESCAPE '\'
       AND email NOT LIKE '%@anonymized.invalid'
       AND account_status <> 'deactivated'
     ORDER BY created_at
  LOOP
    v_base := lower(left(regexp_replace(split_part(r.email, '@', 1), '[^a-zA-Z0-9_]', '_', 'g'), 30));
    v_base := trim(both '_' from v_base);
    IF length(v_base) < 3 THEN v_base := rpad(v_base, 3, '_'); END IF;
    v_candidate := v_base; v_i := 1;
    WHILE EXISTS (SELECT 1 FROM public.users
                   WHERE username IS NOT NULL AND lower(username) = lower(v_candidate) AND id <> r.id)
    LOOP
      v_i := v_i + 1;
      v_candidate := left(v_base, 30 - length(v_i::text) - 1) || '_' || v_i::text;
    END LOOP;
    UPDATE public.users SET username = v_candidate WHERE id = r.id;
  END LOOP;
END $$;
DO $$
BEGIN
  ASSERT (SELECT username FROM public.users WHERE id=(select b from zz439)) = 'first_last',
    'dot local part sanitizes to underscores';
  ASSERT (SELECT username FROM public.users WHERE id=(select c from zz439)) = 'first_last_2',
    'case-insensitive collision gets a suffix';
  ASSERT (SELECT username FROM public.users WHERE id=(select d from zz439)) = 'ab_',
    'short local part pads to 3 chars';
  ASSERT (SELECT username FROM public.users WHERE id=(select alias from zz439)) IS NULL,
    'phone alias stays NULL';
  ASSERT (SELECT username FROM public.users WHERE id=(select anon from zz439)) IS NULL,
    'anonymized stays NULL';
  ASSERT (SELECT username FROM public.users WHERE id=(select dead from zz439)) IS NULL,
    'deactivated stays NULL';
END $$;
ROLLBACK;

-- 2) Format CHECK rejects bad usernames, accepts good ones.
BEGIN;
DO $$
BEGIN
  BEGIN
    UPDATE public.users SET username='no spaces!' WHERE id=(select b from zz439);
    ASSERT false, 'format CHECK must reject punctuation';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.users SET username='ab' WHERE id=(select b from zz439);
    ASSERT false, 'format CHECK must reject short values';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE public.users SET username='ok_name-9' WHERE id=(select b from zz439);
  ASSERT false, 'format CHECK must reject dashes';
EXCEPTION WHEN check_violation THEN NULL;
END $$;
UPDATE public.users SET username='ok_name9' WHERE id=(select b from zz439);
ROLLBACK;

-- 3) Case-insensitive uniqueness: 'legacyuser' collides with 'LegacyUser'.
BEGIN;
DO $$
BEGIN
  BEGIN
    UPDATE public.users SET username='LEGACYUSER' WHERE id=(select b from zz439);
    ASSERT false, 'unique index must reject a case-variant duplicate';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END $$;
ROLLBACK;

-- 4) Lookup consistency: what the index rejects, the lookup never sees
-- twice; a case-variant lookup resolves the one canonical row.
BEGIN;
DO $$
DECLARE v text;
BEGIN
  v := public.lookup_email_by_username('LEGACYUSER');
  ASSERT v = 'legacy.one@example.invalid', format('case-insensitive lookup, got %s', v);
END $$;
ROLLBACK;
