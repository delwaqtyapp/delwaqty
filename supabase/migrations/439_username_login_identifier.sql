-- 439: usernames become a real login identifier - case-insensitive
-- uniqueness, format validation, and a one-time backfill for legacy
-- email accounts.
--
-- Context: signup no longer collects email (the auth identifier is a
-- synthetic phone_<digits>@delwaqty.app address); login resolves a phone
-- number OR a username through the rate-limited security-definer RPCs
-- lookup_email_by_phone / lookup_email_by_username. The username lookup
-- already compares lower() on both sides, but the unique index
-- users_username_unique_idx is case-SENSITIVE: 'Ahmed' and 'ahmed' could
-- coexist and the lookup would pick one arbitrarily. This migration
-- closes that hole and gives existing email-era accounts a starting
-- username they can change from the profile page.
--
-- 1) Backfill: legacy real-email users get a sanitized local-part
--    username (deduplicated case-insensitively with _N suffixes).
--    Synthetic phone_ aliases stay NULL (their owners log in by phone
--    and set a username later from the profile page). Anonymized and
--    deactivated accounts are never touched. ONLY public.users.username
--    is written - no auth credentials, emails or passwords change.
-- 2) CHECK: username is 3-30 chars of [a-zA-Z0-9_] (ASCII slug; matches
--    the app's client-side validation).
-- 3) users_username_unique_idx is rebuilt on lower(username) so
--    uniqueness is case-insensitive like the lookup.
--
-- Pre-image guard: aborts without mutation unless users.username exists
-- and users_username_unique_idx is exactly the case-sensitive partial
-- btree the baseline records.
--
-- This migration is NOT applied to prod without the owner's explicit
-- order.

BEGIN;

DO $a0$
DECLARE
  v_def text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'users'
                    AND column_name = 'username') THEN
    RAISE EXCEPTION '439 precondition failed: public.users.username missing';
  END IF;
  SELECT indexdef INTO v_def FROM pg_indexes
   WHERE schemaname = 'public' AND tablename = 'users'
     AND indexname = 'users_username_unique_idx';
  IF v_def IS NULL OR v_def <>
     'CREATE UNIQUE INDEX users_username_unique_idx ON public.users USING btree (username) WHERE (username IS NOT NULL)' THEN
    RAISE EXCEPTION '439 precondition failed: users_username_unique_idx drifted from the pinned pre-image: %', coalesce(v_def, '<missing>');
  END IF;
END
$a0$;

-- (1) Backfill legacy real-email users.
DO $$
DECLARE
  r record;
  v_base text;
  v_candidate text;
  v_i int;
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
    IF length(v_base) < 3 THEN
      v_base := rpad(v_base, 3, '_');
    END IF;
    v_candidate := v_base;
    v_i := 1;
    WHILE EXISTS (SELECT 1 FROM public.users
                   WHERE username IS NOT NULL
                     AND lower(username) = lower(v_candidate)
                     AND id <> r.id)
    LOOP
      v_i := v_i + 1;
      v_candidate := left(v_base, 30 - length(v_i::text) - 1) || '_' || v_i::text;
    END LOOP;
    UPDATE public.users SET username = v_candidate, updated_at = now()
     WHERE id = r.id;
  END LOOP;
END
$$;

-- (2) Format validation.
ALTER TABLE public.users
  ADD CONSTRAINT users_username_format_chk
  CHECK (username IS NULL OR username ~ '^[a-zA-Z0-9_]{3,30}$');

-- (3) Case-insensitive uniqueness.
DROP INDEX public.users_username_unique_idx;
CREATE UNIQUE INDEX users_username_unique_idx
  ON public.users USING btree (lower(username))
  WHERE username IS NOT NULL;

COMMIT;
