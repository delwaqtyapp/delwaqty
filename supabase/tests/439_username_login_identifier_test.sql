-- Suite for migration 439 (username login identifier), post-apply
-- behavior only. The migration itself is exercised pre-apply by
-- supabase/harness/439_harness.sh (clean apply, invalid legacy names,
-- case-fold collisions, phone-shaped names).
-- Synthetic fixtures only: @example.invalid emails, never real accounts.
-- DISPOSABLE-DATABASE-ONLY: auth.users fixtures persist; run on a
-- throwaway clone, never on staging or prod.

create temporary table zz439(a uuid, b uuid);
insert into zz439 select gen_random_uuid(), gen_random_uuid();
insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select a as id from zz439 union all select b from zz439
) x;
update public.users set email='suite.legacy@example.invalid', username='SuiteUser' where id=(select a from zz439);

-- 1) CHECK: rejects punctuation, short values, dashes, all-digit names;
--    accepts letters/underscores/digits mixed.
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
  BEGIN
    UPDATE public.users SET username='ok-name-9' WHERE id=(select b from zz439);
    ASSERT false, 'format CHECK must reject dashes';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.users SET username='012345678' WHERE id=(select b from zz439);
    ASSERT false, 'format CHECK must reject all-digit phone-shaped names';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.users SET username='123' WHERE id=(select b from zz439);
    ASSERT false, 'format CHECK must reject short all-digit names';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
UPDATE public.users SET username='ok_name9' WHERE id=(select b from zz439);
ROLLBACK;

-- 2) Case-insensitive uniqueness: 'legacyuser' collides with 'SuiteUser'.
BEGIN;
DO $$
BEGIN
  BEGIN
    UPDATE public.users SET username='SUITEUSER' WHERE id=(select b from zz439);
    ASSERT false, 'unique index must reject a case-variant duplicate';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END $$;
ROLLBACK;

-- 3) Lookup consistency: a case-variant lookup resolves the one
-- canonical row.
BEGIN;
DO $$
DECLARE v text;
BEGIN
  v := public.lookup_email_by_username('SUITEUSER');
  ASSERT v = 'suite.legacy@example.invalid', format('case-insensitive lookup, got %s', v);
END $$;
ROLLBACK;

-- 4) NULL usernames stay valid (legacy accounts pick one later).
BEGIN;
UPDATE public.users SET username=NULL WHERE id=(select b from zz439);
ROLLBACK;
