-- 439: usernames become a real login identifier - case-insensitive
-- uniqueness, format validation, phone-shape reservation.
--
-- Context: signup no longer collects email (the auth identifier is a
-- synthetic phone_<digits>@delwaqty.app address); login resolves a phone
-- number OR a username through the rate-limited security-definer RPCs
-- lookup_email_by_phone / lookup_email_by_username. The username lookup
-- already compares lower() on both sides, but the unique index
-- users_username_unique_idx is case-SENSITIVE: 'Ahmed' and 'ahmed' could
-- coexist and the lookup would pick one arbitrarily.
--
-- Rules (the companion app PR aligns client-side validation to these
-- exact rules; until it lands the server constraint is the only
-- enforcement):
--   username ~ '^[a-zA-Z0-9_]{3,30}$'  (ASCII slug)
--   username !~ '^[0-9]+$'             (never phone-shaped: the client
--     routes all-digit identifiers to the phone-number login path, so a
--     digit-only username equal to someone's phone could resolve the
--     wrong account)
--
-- NO BACKFILL: existing accounts keep a NULL username and keep signing
-- in with their real email (still accepted by the client); they pick a
-- username later from the profile page. Backfilling from email local
-- parts was rejected on review: guessable usernames would make real
-- emails harvestable through the anon lookup_email_by_username RPC.
-- This migration writes NO user data at all.
--
-- Pre-image guard (A0): aborts unless users.username exists and
-- users_username_unique_idx is exactly the case-sensitive partial btree
-- the baseline records.
-- Preflight (A1): aborts with explicit diagnostics if any EXISTING
-- username violates the new rules or collides case-insensitively with
-- another - nothing is ever silently renamed.
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

-- A1 preflight: every existing username must already satisfy the new
-- rules and be case-insensitively unique.
DO $a1$
DECLARE
  v_bad text;
BEGIN
  SELECT string_agg(format('%s (id %s)', username, id), ', ') INTO v_bad
    FROM public.users
   WHERE username IS NOT NULL
     AND (username !~ '^[a-zA-Z0-9_]{3,30}$' OR username ~ '^[0-9]+$');
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION '439 preflight failed: existing usernames violate the new rules: %. Rename them explicitly first; 439 never renames.', v_bad;
  END IF;

  SELECT string_agg(dup, ', ') INTO v_bad FROM (
    SELECT format('%s -> %s', lower(username), string_agg(username, ' / ')) AS dup
      FROM public.users
     WHERE username IS NOT NULL
     GROUP BY lower(username)
    HAVING count(*) > 1
  ) z;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION '439 preflight failed: case-insensitive username collisions: %. Resolve them explicitly first.', v_bad;
  END IF;
END
$a1$;

-- Format validation + phone-shape reservation.
ALTER TABLE public.users
  ADD CONSTRAINT users_username_format_chk
  CHECK (username IS NULL OR
         (username ~ '^[a-zA-Z0-9_]{3,30}$' AND username !~ '^[0-9]+$'));

-- Case-insensitive uniqueness.
DROP INDEX public.users_username_unique_idx;
CREATE UNIQUE INDEX users_username_unique_idx
  ON public.users USING btree (lower(username))
  WHERE username IS NOT NULL;

COMMIT;
