-- 427: drivers.service_types default (load-team item 6, 2026-11-23).
--
-- The column defaulted to ARRAY[]::text[]. A driver row inserted without
-- service_types got the empty array, and driver_capability_bounds_guard
-- (416) rejects accepts_deliveries=true with an empty array - so such an
-- insert failed outright. 416 already backfilled existing rows and treats
-- 'food, grocery, pharmacy, parcel' as the canonical full delivery set.
-- Make the column default that full array so an insert that omits
-- service_types lands on the same canonical set.
--
-- Behavior change (intended, per the load-team item): an INSERT with
-- accepts_deliveries=true and no explicit service_types now succeeds with
-- the full delivery array instead of raising. Explicit service_types are
-- untouched; the trigger's subset/bounds checks are unchanged.
--
-- Guard: exact canonical pre-state default (ARRAY[]::text[]) required;
-- already at target -> no-op; anything else aborts without mutation.
-- Convergent: prod and staging share this default.

BEGIN;

DO $g$
DECLARE
  v_def text;
  c_pre    constant text := 'ARRAY[]::text[]';
  c_target constant text := 'ARRAY[''food''::text, ''grocery''::text, ''pharmacy''::text, ''parcel''::text]';
BEGIN
  SELECT pg_get_expr(a.adbin, a.adrelid) INTO v_def
    FROM pg_attrdef a
   WHERE a.adrelid = 'public.drivers'::regclass
     AND a.adnum = (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types');

  IF NOT FOUND THEN
    RAISE EXCEPTION '427: drivers.service_types has no default - aborting';
  END IF;

  IF v_def = c_target THEN
    RAISE NOTICE '427: drivers.service_types default already at target - no-op';
  ELSIF v_def IS DISTINCT FROM c_pre THEN
    RAISE EXCEPTION '427: drivers.service_types default drifted - aborting WITHOUT mutation: %', v_def;
  ELSE
    ALTER TABLE public.drivers ALTER COLUMN service_types
      SET DEFAULT ARRAY['food','grocery','pharmacy','parcel']::text[];
  END IF;
END $g$;

COMMIT;
