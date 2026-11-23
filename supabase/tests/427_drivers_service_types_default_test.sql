-- 427 actual staging run (transaction-wrapped, fixtures rolled back).
-- The guard body is a VERBATIM copy of the migration's guard block.
-- Proves: apply path sets the full-array default, no-op rerun, drift
-- abort, and the trigger behavior around the new default.
BEGIN;

-- apply path (verbatim guard body from 427_drivers_service_types_default.sql)
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

DO $$
DECLARE
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
  u3 uuid := gen_random_uuid(); u4 uuid := gen_random_uuid();
  d1 uuid := gen_random_uuid(); d2 uuid := gen_random_uuid(); d3 uuid := gen_random_uuid();
  v_types text[]; v_msg text; v_def text;
BEGIN
  INSERT INTO auth.users(id,email) SELECT g, '427'||g::text||'@x.i' FROM unnest(ARRAY[u1,u2,u3,u4]) g;
  INSERT INTO public.users(id,email,role) SELECT g, '427'||g::text||'@x.i', 'driver' FROM unnest(ARRAY[u1,u2,u3,u4]) g
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;

  -- omitted service_types, accepts_deliveries defaulted (false): full array
  INSERT INTO public.drivers(id,user_id,full_name) VALUES (d1,u1,'427 D1');
  SELECT service_types INTO v_types FROM public.drivers WHERE id=d1;
  ASSERT v_types = ARRAY['food','grocery','pharmacy','parcel']::text[],
    '427: omitted service_types did not default to the full array: ' || coalesce(v_types::text,'<null>');

  -- omitted service_types with accepts_deliveries=true: previously the
  -- guard rejected this (empty array); now succeeds with the full array
  INSERT INTO public.drivers(id,user_id,full_name,accepts_deliveries) VALUES (d2,u2,'427 D2',true);
  SELECT service_types INTO v_types FROM public.drivers WHERE id=d2;
  ASSERT v_types = ARRAY['food','grocery','pharmacy','parcel']::text[],
    '427: accepts_deliveries insert did not get the full array';

  -- explicit subset untouched
  INSERT INTO public.drivers(id,user_id,full_name,service_types) VALUES (d3,u3,'427 D3',ARRAY['parcel']::text[]);
  SELECT service_types INTO v_types FROM public.drivers WHERE id=d3;
  ASSERT v_types = ARRAY['parcel']::text[], '427: explicit subset overwritten';

  -- invalid type still rejected by the trigger
  BEGIN
    INSERT INTO public.drivers(id,user_id,full_name,service_types) VALUES (gen_random_uuid(),u4,'427 D4',ARRAY['boat']::text[]);
    v_msg := NULL;
  EXCEPTION WHEN OTHERS THEN
    v_msg := SQLSTATE;
  END;
  ASSERT v_msg IS NOT NULL, '427: invalid service_types accepted';

  -- default change does not weaken the trigger on explicit empty +
  -- accepts_deliveries
  BEGIN
    INSERT INTO public.drivers(id,user_id,full_name,accepts_deliveries,service_types) VALUES (gen_random_uuid(),u4,'427 D5',true,ARRAY[]::text[]);
    v_msg := NULL;
  EXCEPTION WHEN OTHERS THEN
    v_msg := SQLSTATE;
  END;
  ASSERT v_msg IS NOT NULL, '427: explicit empty array with accepts_deliveries accepted';

  -- canonical default on the catalog matches the guard target
  SELECT pg_get_expr(a.adbin, a.adrelid) INTO v_def
    FROM pg_attrdef a
   WHERE a.adrelid = 'public.drivers'::regclass
     AND a.adnum = (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types');
  ASSERT v_def = 'ARRAY[''food''::text, ''grocery''::text, ''pharmacy''::text, ''parcel''::text]',
    '427: catalog default is not the canonical target: ' || v_def;
END $$;

-- no-op path: second verbatim run must not raise
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

-- drift path: a different default aborts without mutation
DO $t$
DECLARE
  v_msg text; v_before text; v_after text;
BEGIN
  SELECT pg_get_expr(a.adbin, a.adrelid) INTO v_before
    FROM pg_attrdef a WHERE a.adrelid = 'public.drivers'::regclass
     AND a.adnum = (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types');
  ALTER TABLE public.drivers ALTER COLUMN service_types SET DEFAULT ARRAY['parcel']::text[];
  BEGIN
    -- verbatim guard body
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
    END;
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
  END;
  ASSERT v_msg LIKE '427: drivers.service_types default drifted%',
    '427: drifted default did not abort: ' || coalesce(v_msg, '<no exception>');
  SELECT pg_get_expr(a.adbin, a.adrelid) INTO v_after
    FROM pg_attrdef a WHERE a.adrelid = 'public.drivers'::regclass
     AND a.adnum = (SELECT attnum FROM pg_attribute
                     WHERE attrelid = 'public.drivers'::regclass AND attname = 'service_types');
  ASSERT v_after = 'ARRAY[''parcel''::text]', '427: guard mutated a drifted default: ' || v_after;
  ASSERT v_before <> v_after OR v_before IS NOT NULL; -- trivially true; keeps v_before used
END $t$;

ROLLBACK;
