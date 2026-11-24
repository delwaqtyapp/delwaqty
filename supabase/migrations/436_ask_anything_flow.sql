-- 436: ask-anything courier flow (owner decision 2026-11-24, issue #28;
-- code review #206-#211, security review B1/B2).
--
-- The owner's product decision for the ask-anything button (kept as is):
-- the customer picks a unit (kilo / half / quarter) or an EGP amount and
-- writes the product; the delivery price is set by the driver (minimum
-- 15 EGP for the first shop + 5 EGP per extra shop by the declared shop
-- count, rising with distance - main's product decision under the
-- owner's delegation, from the owner's own voice-note words: "15 EGP
-- for the first shop, +5 for each extra shop, may rise with distance,
-- set by the driver" - #211) and the
-- customer accepts, rejects or negotiates - never forced; the driver buys
-- at the shops and records each item with its shop name and real price
-- (typed, or a receipt photo); the customer sees a live itemized invoice
-- and approves each item before it is bought; rejected items are
-- cancelled by the driver while still at the shop. Final charge = locked
-- agreed delivery price + approved items total. Goods are paid separately
-- from the fare; the platform takes commission on the fare only.
-- Ask-anything rides are CASH ONLY (security B2b): the driver fronts the
-- goods money. No pharmacy items.
--
-- The 15+5/shop floor binds BOTH sides of the negotiation (#211):
-- driver proposals and customer counters below the floor are rejected
-- by propose_courier_quote, and clients must enforce the same floor on
-- a customer counter before calling the API.
--
-- Money semantics (confirmed by the owner via main, 2026-11-24):
-- rides.fare is LOCKED to the accepted quote; goods money never passes
-- through rides.fare. Under cash the driver fronts goods money at the
-- shop and is reimbursed by the customer on delivery, so no goods
-- driver_obligation exists (booking one would double-charge the driver);
-- the itemized invoice plus rides.courier_goods_total are the goods-money
-- ledger that #152 asked for.
--
-- Security shape follows 430: clients never write these tables directly;
-- every write is a SECURITY DEFINER RPC that derives identity from
-- auth.uid() and the ride row. SELECT is granted to the rider and the
-- assigned driver (plus active admins) through RLS policies only.
-- Replaced global functions are pinned to their exact live pre-images
-- (md5) before replacement; only marked 436 blocks are added.

BEGIN;

-- ── Pre-image and schema-drift guards (#210, B1) ────────────────────────

DO $$
DECLARE
  -- #210: exact regprocedure signatures for every replaced global.
  f_rde constant regprocedure := 'public._record_delivery_earnings(uuid)'::regprocedure;
  f_start constant regprocedure := 'public.start_trip(uuid,uuid,text)'::regprocedure;
  f_cancel constant regprocedure := 'public.cancel_ride_lifecycle(uuid,text,text)'::regprocedure;
  f_resolve constant regprocedure := 'public.resolve_delivery_incident(uuid,text,text)'::regprocedure;
  v_md5 text;
  v_owner text;
  v_secdef boolean;
  v_config text[];
  v_acl text;
  v_rides_owner text;
BEGIN
  SELECT pg_get_userbyid(t.relowner) INTO v_rides_owner
    FROM pg_class t WHERE t.relname = 'rides' AND t.relnamespace = 'public'::regnamespace;

  -- Every replaced global is pinned by the FULL md5 of its live body
  -- (prosrc; pg_get_functiondef for start_trip, matching the security
  -- reviewer's pin) and must be SECURITY DEFINER, owned by the rides
  -- owner, with the exact search_path and effective EXECUTE set below
  -- (#210, B1). Effective ACLs are compared as sorted grantee sets via
  -- aclexplode, so grantor identity never false-trips the guard.
  SELECT md5(p.prosrc), pg_get_userbyid(p.proowner), p.prosecdef, p.proconfig,
         (SELECT string_agg(g, ',' ORDER BY g) FROM (
            SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                        ELSE a.grantee::regrole::text END
                   || '=' || a.privilege_type AS g
              FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a) x)
    INTO v_md5, v_owner, v_secdef, v_config, v_acl
    FROM pg_proc p WHERE p.oid = f_rde;
  IF v_md5 IS DISTINCT FROM 'fb95f00d5003d6b493823b69baa1cd65' THEN
    RAISE EXCEPTION '436: _record_delivery_earnings pre-image drifted (got %, want fb95f00d5003d6b493823b69baa1cd65) - rebuild this migration on the live body', v_md5;
  END IF;
  IF v_secdef IS DISTINCT FROM true
     OR v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[]
     OR v_owner IS DISTINCT FROM v_rides_owner
     OR v_acl IS DISTINCT FROM 'postgres=EXECUTE,service_role=EXECUTE' THEN
    RAISE EXCEPTION '436: _record_delivery_earnings property drifted (secdef %, config %, owner %, acl %)', v_secdef, v_config, v_owner, v_acl;
  END IF;

  SELECT md5(pg_get_functiondef(p.oid)), pg_get_userbyid(p.proowner), p.prosecdef, p.proconfig,
         (SELECT string_agg(g, ',' ORDER BY g) FROM (
            SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                        ELSE a.grantee::regrole::text END
                   || '=' || a.privilege_type AS g
              FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a) x)
    INTO v_md5, v_owner, v_secdef, v_config, v_acl
    FROM pg_proc p WHERE p.oid = f_start;
  IF v_md5 IS DISTINCT FROM 'a5cbc1a373cd7414047c7422fb5f6f4a' THEN
    RAISE EXCEPTION '436: start_trip pre-image drifted (got %, want a5cbc1a373cd7414047c7422fb5f6f4a)', v_md5;
  END IF;
  IF v_secdef IS DISTINCT FROM true
     OR v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[]
     OR v_owner IS DISTINCT FROM v_rides_owner
     OR v_acl IS DISTINCT FROM 'authenticated=EXECUTE,postgres=EXECUTE,service_role=EXECUTE' THEN
    RAISE EXCEPTION '436: start_trip property drifted (secdef %, config %, owner %, acl %)', v_secdef, v_config, v_owner, v_acl;
  END IF;

  SELECT md5(p.prosrc), pg_get_userbyid(p.proowner), p.prosecdef, p.proconfig,
         (SELECT string_agg(g, ',' ORDER BY g) FROM (
            SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                        ELSE a.grantee::regrole::text END
                   || '=' || a.privilege_type AS g
              FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a) x)
    INTO v_md5, v_owner, v_secdef, v_config, v_acl
    FROM pg_proc p WHERE p.oid = f_cancel;
  IF v_md5 IS DISTINCT FROM '89e175d7e4c7f7023881338201a5d7d5' THEN
    RAISE EXCEPTION '436: cancel_ride_lifecycle pre-image drifted (got %, want 89e175d7e4c7f7023881338201a5d7d5)', v_md5;
  END IF;
  IF v_secdef IS DISTINCT FROM true
     OR v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[]
     OR v_owner IS DISTINCT FROM v_rides_owner
     OR v_acl IS DISTINCT FROM 'authenticated=EXECUTE,postgres=EXECUTE,service_role=EXECUTE' THEN
    RAISE EXCEPTION '436: cancel_ride_lifecycle property drifted (secdef %, config %, owner %, acl %)', v_secdef, v_config, v_owner, v_acl;
  END IF;

  SELECT md5(p.prosrc), pg_get_userbyid(p.proowner), p.prosecdef, p.proconfig,
         (SELECT string_agg(g, ',' ORDER BY g) FROM (
            SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                        ELSE a.grantee::regrole::text END
                   || '=' || a.privilege_type AS g
              FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a) x)
    INTO v_md5, v_owner, v_secdef, v_config, v_acl
    FROM pg_proc p WHERE p.oid = f_resolve;
  IF v_md5 IS DISTINCT FROM '8e99388bbc8196b10b011da3d5e66ce9' THEN
    RAISE EXCEPTION '436: resolve_delivery_incident pre-image drifted (got %, want 8e99388bbc8196b10b011da3d5e66ce9)', v_md5;
  END IF;
  IF v_secdef IS DISTINCT FROM true
     OR v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[]
     OR v_owner IS DISTINCT FROM v_rides_owner
     OR v_acl IS DISTINCT FROM 'authenticated=EXECUTE,postgres=EXECUTE,service_role=EXECUTE' THEN
    RAISE EXCEPTION '436: resolve_delivery_incident property drifted (secdef %, config %, owner %, acl %)', v_secdef, v_config, v_owner, v_acl;
  END IF;

  -- Column-shape drift checks for every rides column this migration
  -- reads or writes.
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('fare', 'numeric'), ('status', 'text'), ('rider_id', 'uuid'),
      ('driver_id', 'uuid'), ('service_type', 'text'), ('order_id', 'uuid'),
      ('merchant_id', 'uuid'), ('payment_method', 'text'),
      ('currency', 'text'), ('items_summary', 'text'),
      ('dropoff_notes', 'text'), ('priority', 'text')
    ) AS want(col, typ)
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
       WHERE c.table_schema = 'public' AND c.table_name = 'rides'
         AND c.column_name = want.col AND c.data_type = want.typ
    )
  ) THEN
    RAISE EXCEPTION '436: rides column shape drifted from the expected pre-image';
  END IF;
END $$;

-- ── Tables ──────────────────────────────────────────────────────────────

CREATE TABLE public.courier_request_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  unit text NOT NULL CHECK (unit IN ('kilo', 'half', 'quarter', 'amount')),
  amount_egp numeric(10,2) CHECK (amount_egp IS NULL OR (amount_egp > 0 AND amount_egp <= 100000)),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT courier_request_items_unit_amount_match
    CHECK ((unit = 'amount') = (amount_egp IS NOT NULL))
);

CREATE TABLE public.courier_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  proposed_by_role text NOT NULL CHECK (proposed_by_role IN ('driver', 'customer')),
  proposed_by uuid NOT NULL,
  amount numeric(10,2) NOT NULL CHECK (amount >= 15 AND amount <= 50000),
  note text CHECK (note IS NULL OR length(note) <= 300),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz
);
-- One open negotiation at a time per ride.
CREATE UNIQUE INDEX courier_quotes_one_pending
  ON public.courier_quotes(ride_id) WHERE status = 'pending';
CREATE INDEX courier_quotes_ride ON public.courier_quotes(ride_id);

CREATE TABLE public.courier_invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
  shop_name text NOT NULL,
  product_name text NOT NULL,
  unit text CHECK (unit IS NULL OR unit IN ('kilo', 'half', 'quarter', 'piece', 'amount')),
  quantity numeric(10,3) CHECK (quantity IS NULL OR (quantity > 0 AND quantity <= 1000)),
  price numeric(10,2) NOT NULL CHECK (price >= 0 AND price <= 100000),
  receipt_photo_url text CHECK (receipt_photo_url IS NULL OR length(receipt_photo_url) <= 1000),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  cancelled_at timestamptz
);
CREATE INDEX courier_invoice_items_ride ON public.courier_invoice_items(ride_id);

ALTER TABLE public.courier_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courier_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courier_invoice_items ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.courier_request_items FROM anon, authenticated;
REVOKE ALL ON public.courier_quotes FROM anon, authenticated;
REVOKE ALL ON public.courier_invoice_items FROM anon, authenticated;
GRANT SELECT ON public.courier_request_items TO authenticated;
GRANT SELECT ON public.courier_quotes TO authenticated;
GRANT SELECT ON public.courier_invoice_items TO authenticated;

CREATE POLICY courier_request_items_select ON public.courier_request_items
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.rides r
             WHERE r.id = ride_id AND r.rider_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.rides r
                JOIN public.drivers d ON d.id = r.driver_id
             WHERE r.id = ride_id AND d.user_id = auth.uid())
    OR public._is_active_admin_uid(auth.uid())
  );

CREATE POLICY courier_quotes_select ON public.courier_quotes
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.rides r
             WHERE r.id = ride_id AND r.rider_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.rides r
                JOIN public.drivers d ON d.id = r.driver_id
             WHERE r.id = ride_id AND d.user_id = auth.uid())
    OR public._is_active_admin_uid(auth.uid())
  );

CREATE POLICY courier_invoice_items_select ON public.courier_invoice_items
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.rides r
             WHERE r.id = ride_id AND r.rider_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.rides r
                JOIN public.drivers d ON d.id = r.driver_id
             WHERE r.id = ride_id AND d.user_id = auth.uid())
    OR public._is_active_admin_uid(auth.uid())
  );

-- Live itemized invoice: add the three tables to the realtime
-- publication. The publication on the live project is supabase_realtime;
-- older local scripts used a publication named n, so cover both and
-- never claim the table was added when no publication exists.
DO $$
DECLARE
  v_pub text;
  v_tab text;
BEGIN
  SELECT pubname INTO v_pub FROM pg_publication
   WHERE pubname IN ('supabase_realtime', 'n')
   ORDER BY CASE pubname WHEN 'supabase_realtime' THEN 0 ELSE 1 END
   LIMIT 1;
  IF v_pub IS NOT NULL THEN
    FOREACH v_tab IN ARRAY ARRAY['courier_request_items', 'courier_quotes', 'courier_invoice_items'] LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                      WHERE pubname = v_pub AND schemaname = 'public'
                        AND tablename = v_tab) THEN
        EXECUTE format('ALTER PUBLICATION %I ADD TABLE public.%I', v_pub, v_tab);
      END IF;
    END LOOP;
  END IF;
END $$;

-- ── Ride columns ────────────────────────────────────────────────────────

ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS is_ask_anything boolean NOT NULL DEFAULT false;
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_shop_count integer NOT NULL DEFAULT 1
  CHECK (courier_shop_count BETWEEN 1 AND 20);
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_quote_locked boolean NOT NULL DEFAULT false;
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_goods_total numeric(10,2) NOT NULL DEFAULT 0
  CHECK (courier_goods_total >= 0 AND courier_goods_total <= 5000000);
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_shopping_finished boolean NOT NULL DEFAULT false;

-- Security B2b: ask-anything rides are cash only - the driver fronts the
-- goods money at the shop.
ALTER TABLE public.rides ADD CONSTRAINT rides_ask_anything_cash_only
  CHECK (NOT is_ask_anything OR payment_method = 'cash');

-- ── Request RPC ─────────────────────────────────────────────────────────

-- Ask-anything request: the 430 courier creation with structured items.
-- fare/order_id/merchant_id stay server-controlled exactly as in
-- request_courier_delivery; payment_method is pinned to cash (B2b); the
-- fare is locked later by quote acceptance.
CREATE OR REPLACE FUNCTION public.request_courier_shopping(
  p_pickup_latitude numeric,
  p_pickup_longitude numeric,
  p_pickup_address text,
  p_dropoff_latitude numeric,
  p_dropoff_longitude numeric,
  p_dropoff_address text,
  p_items jsonb,
  p_estimated_shops integer DEFAULT 1,
  p_dropoff_notes text DEFAULT NULL,
  p_priority text DEFAULT 'standard'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_delivery_id uuid;
  v_open int;
  v_item jsonb;
  v_unit text;
  v_name text;
  v_amount numeric;
  v_summary text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  IF p_pickup_latitude IS NULL OR p_pickup_longitude IS NULL
     OR p_dropoff_latitude IS NULL OR p_dropoff_longitude IS NULL
     OR p_pickup_latitude NOT BETWEEN -90 AND 90
     OR p_dropoff_latitude NOT BETWEEN -90 AND 90
     OR p_pickup_longitude NOT BETWEEN -180 AND 180
     OR p_dropoff_longitude NOT BETWEEN -180 AND 180
     OR p_pickup_latitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_dropoff_latitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_pickup_longitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_dropoff_longitude::float8 IN ('Infinity'::float8, '-Infinity'::float8, 'NaN'::float8)
     OR p_pickup_address IS NULL OR btrim(p_pickup_address) = ''
     OR p_dropoff_address IS NULL OR btrim(p_dropoff_address) = ''
     OR length(p_pickup_address) > 500 OR length(p_dropoff_address) > 500
     OR length(COALESCE(p_dropoff_notes, '')) > 500 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  IF p_priority NOT IN ('standard', 'priority', 'express') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  IF p_estimated_shops IS NULL OR p_estimated_shops NOT BETWEEN 1 AND 20 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  -- Items: a jsonb array of 1..20 entries, each
  -- {"product_name": str, "unit": kilo|half|quarter|amount, "amount_egp": n?}.
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) < 1 OR jsonb_array_length(p_items) > 20 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
    END IF;
    v_name := v_item ->> 'product_name';
    v_unit := v_item ->> 'unit';
    IF v_name IS NULL OR btrim(v_name) = '' OR length(v_name) > 200 THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
    END IF;
    IF v_unit IS NULL OR v_unit NOT IN ('kilo', 'half', 'quarter', 'amount') THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
    END IF;
    IF v_unit = 'amount' THEN
      BEGIN
        v_amount := (v_item ->> 'amount_egp')::numeric;
      EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
      END;
      -- BETWEEN rejects NULL, NaN and both infinities.
      IF v_amount IS NULL OR NOT (v_amount BETWEEN 0.01 AND 100000) THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
      END IF;
    ELSIF v_item ? 'amount_egp' AND v_item ->> 'amount_egp' IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_ITEMS');
    END IF;
  END LOOP;

  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));
  SELECT count(*) INTO v_open
    FROM public.rides
   WHERE rider_id = v_uid AND status = 'searching';
  IF v_open >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TOO_MANY_OPEN_RIDES');
  END IF;

  SELECT string_agg(btrim(x ->> 'product_name'), '، ')
    INTO v_summary
    FROM jsonb_array_elements(p_items) x;

  INSERT INTO public.rides (
    rider_id,
    pickup_latitude, pickup_longitude, pickup_address,
    dropoff_latitude, dropoff_longitude, dropoff_address,
    ride_type, service_type, status,
    items_summary, dropoff_notes, priority,
    fare, order_id, merchant_id, payment_method,
    is_ask_anything, courier_shop_count
  ) VALUES (
    v_uid,
    p_pickup_latitude, p_pickup_longitude, p_pickup_address,
    p_dropoff_latitude, p_dropoff_longitude, p_dropoff_address,
    'motorcycle', 'courier', 'searching',
    left(v_summary, 500), p_dropoff_notes, COALESCE(p_priority, 'standard'),
    NULL, NULL, NULL, 'cash',
    true, p_estimated_shops
  ) RETURNING id INTO v_delivery_id;

  INSERT INTO public.courier_request_items (ride_id, product_name, unit, amount_egp)
  SELECT v_delivery_id,
         btrim(x ->> 'product_name'),
         x ->> 'unit',
         CASE WHEN x ->> 'unit' = 'amount' THEN (x ->> 'amount_egp')::numeric END
    FROM jsonb_array_elements(p_items) x;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_id', v_delivery_id,
    'quote_baseline', 15 + 5 * (p_estimated_shops - 1)
  );
END;
$function$;

-- ── Quote RPCs ──────────────────────────────────────────────────────────

-- The driver proposes the delivery price (at or above the 15+5/shop
-- baseline by the declared shop count; it may rise with distance). The
-- rider answers with respond_courier_quote; the rider's counters also go
-- through this RPC - the caller's role is derived from the ride, never
-- from the caller. The 15+5/shop floor binds both sides (#211). Caps:
-- 20 quotes per ride, 10s between proposals.
CREATE OR REPLACE FUNCTION public.propose_courier_quote(
  p_ride_id uuid,
  p_amount numeric,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  r public.rides%ROWTYPE;
  v_driver_id uuid;
  v_role text;
  v_quote_id uuid;
  v_baseline numeric;
  v_count int;
  v_last timestamptz;
  v_driver_uid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  -- BETWEEN rejects NULL, NaN and both infinities.
  IF p_amount IS NULL OR NOT (p_amount BETWEEN 15 AND 50000) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_AMOUNT');
  END IF;
  IF p_note IS NOT NULL AND length(p_note) > 300 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  -- Canonical lock order (#208): ride first, then quote rows.
  SELECT * INTO r FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  -- Re-read state under the lock: live negotiation only.
  IF r.status NOT IN ('matched', 'arrived') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  IF r.courier_quote_locked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_ALREADY_LOCKED');
  END IF;

  SELECT id INTO v_driver_id FROM public.drivers WHERE user_id = v_uid;
  IF v_driver_id IS NOT NULL AND r.driver_id = v_driver_id THEN
    v_role := 'driver';
  ELSIF r.rider_id = v_uid THEN
    -- The rider only counters an open driver quote; the driver opens.
    IF NOT EXISTS (SELECT 1 FROM public.courier_quotes
                    WHERE ride_id = p_ride_id AND status = 'pending'
                      AND proposed_by_role = 'driver') THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'NO_QUOTE_TO_COUNTER');
    END IF;
    v_role := 'customer';
  ELSE
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  -- #211: the 15+5/shop baseline binds both sides - neither a driver
  -- proposal nor a customer counter may go below it.
  v_baseline := 15 + 5 * (r.courier_shop_count - 1);
  IF p_amount < v_baseline THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'BELOW_BASELINE',
                            'baseline', v_baseline);
  END IF;

  -- Caps and throttle, checked under the ride lock.
  SELECT count(*), max(created_at) INTO v_count, v_last
    FROM public.courier_quotes WHERE ride_id = p_ride_id;
  IF v_count >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_CAP');
  END IF;
  IF v_last IS NOT NULL AND v_last > now() - interval '10 seconds' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'THROTTLED');
  END IF;

  UPDATE public.courier_quotes
     SET status = 'superseded', decided_at = now()
   WHERE ride_id = p_ride_id AND status = 'pending';

  INSERT INTO public.courier_quotes
    (ride_id, proposed_by_role, proposed_by, amount, note)
  VALUES (p_ride_id, v_role, v_uid, p_amount, p_note)
  RETURNING id INTO v_quote_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (p_ride_id, 'courier_quote_proposed', v_role,
          jsonb_build_object('quote_id', v_quote_id, 'amount', p_amount));

  IF v_role = 'driver' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
    VALUES (r.rider_id, 'عرض سعر التوصيل',
            'الكابتن اقترح ' || p_amount::text || ' جنيه للتوصيلة. تقدر تقبل أو ترفض أو تفاوض.',
            'courier_quote',
            jsonb_build_object('ride_id', p_ride_id, 'quote_id', v_quote_id, 'amount', p_amount),
            true);
  ELSE
    SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
    VALUES (v_driver_uid, 'عرض مضاد من العميل',
            'العميل اقترح ' || p_amount::text || ' جنيه للتوصيلة.',
            'courier_quote',
            jsonb_build_object('ride_id', p_ride_id, 'quote_id', v_quote_id, 'amount', p_amount),
            true);
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'quote_id', v_quote_id,
    'role', v_role,
    'quote_baseline', v_baseline
  );
END;
$function$;

-- Accept or reject the open quote. Only the current counterparty of
-- whoever proposed it may answer, on a live (matched/arrived), unlocked
-- ride, with the proposer still in place (#207). Accept LOCKS rides.fare
-- to the agreed amount and enforces the 15+5/shop floor on every path
-- (#209). Canonical lock order: ride first, then the quote (#208).
CREATE OR REPLACE FUNCTION public.respond_courier_quote(
  p_quote_id uuid,
  p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  q public.courier_quotes%ROWTYPE;
  r public.rides%ROWTYPE;
  v_ride_id uuid;
  v_driver_uid uuid;
  v_baseline numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  -- A NULL action must fall to INVALID_INPUT, never to accept (#207).
  IF p_action IS NULL OR p_action NOT IN ('accept', 'reject') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT cq.ride_id INTO v_ride_id FROM public.courier_quotes cq
   WHERE cq.id = p_quote_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  -- Ride first, then the quote (#208); re-read everything under the locks.
  SELECT * INTO r FROM public.rides WHERE id = v_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.status NOT IN ('matched', 'arrived') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  IF r.courier_quote_locked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_ALREADY_LOCKED');
  END IF;

  SELECT * INTO q FROM public.courier_quotes WHERE id = p_quote_id FOR UPDATE;
  IF q.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_NOT_PENDING');
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;

  IF q.proposed_by_role = 'driver' THEN
    -- Only the rider answers, and only while the proposing driver is
    -- still the assigned driver.
    IF r.rider_id IS DISTINCT FROM v_uid THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
    END IF;
    IF v_driver_uid IS DISTINCT FROM q.proposed_by THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'DRIVER_CHANGED');
    END IF;
  ELSE
    -- Only the currently assigned driver answers the rider's counter.
    IF v_driver_uid IS DISTINCT FROM v_uid THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
    END IF;
    IF r.rider_id IS DISTINCT FROM q.proposed_by THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'RIDER_CHANGED');
    END IF;
  END IF;

  IF p_action = 'reject' THEN
    UPDATE public.courier_quotes
       SET status = 'rejected', decided_at = now()
     WHERE id = p_quote_id;
    INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
    VALUES (q.ride_id, 'courier_quote_rejected',
            CASE WHEN q.proposed_by_role = 'driver' THEN 'customer' ELSE 'driver' END,
            jsonb_build_object('quote_id', p_quote_id));
    INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
    VALUES (
      CASE WHEN q.proposed_by_role = 'driver' THEN v_driver_uid ELSE r.rider_id END,
      'عرض السعر مرفوض',
      'عرض ' || q.amount::text || ' جنيه اترفض. ممكن عرض جديد بالتفاوض.',
      'courier_quote',
      jsonb_build_object('ride_id', q.ride_id, 'quote_id', p_quote_id, 'amount', q.amount),
      true);
    RETURN jsonb_build_object('ok', true, 'locked', false);
  END IF;

  -- accept: the 15+5/shop floor holds on every acceptance path (#209).
  v_baseline := 15 + 5 * (r.courier_shop_count - 1);
  IF q.amount < v_baseline THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'BELOW_BASELINE',
                            'baseline', v_baseline);
  END IF;

  UPDATE public.courier_quotes
     SET status = 'accepted', decided_at = now()
   WHERE id = p_quote_id;

  UPDATE public.rides
     SET fare = q.amount,
         courier_quote_locked = true
   WHERE id = q.ride_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (q.ride_id, 'courier_quote_accepted',
          CASE WHEN q.proposed_by_role = 'driver' THEN 'customer' ELSE 'driver' END,
          jsonb_build_object('quote_id', p_quote_id, 'amount', q.amount));

  INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
  VALUES (
    CASE WHEN q.proposed_by_role = 'driver' THEN v_driver_uid ELSE r.rider_id END,
    'اتفقنا على سعر التوصيل',
    'سعر التوصيلة اتفق عليه: ' || q.amount::text || ' جنيه.',
    'courier_quote',
    jsonb_build_object('ride_id', q.ride_id, 'quote_id', p_quote_id, 'amount', q.amount),
    true);

  RETURN jsonb_build_object('ok', true, 'locked', true, 'fare', q.amount);
END;
$function$;

-- ── Invoice RPCs ────────────────────────────────────────────────────────

-- The driver records each item at the shop: shop name, product and the
-- real price (typed, or a receipt photo). Items start pending: the
-- customer approves each one before it is bought. Caps (#209, B2): 50
-- attempted rows (cancelled included) and 20 distinct live shops per
-- ride, 5,000,000 EGP money-active aggregate, 1s between attempts
-- (cancelled rows keep the cadence busy); while a rejected item awaits
-- cancellation the driver cannot add more items (B2).
CREATE OR REPLACE FUNCTION public.add_courier_invoice_item(
  p_ride_id uuid,
  p_shop_name text,
  p_product_name text,
  p_price numeric,
  p_unit text DEFAULT NULL,
  p_quantity numeric DEFAULT NULL,
  p_receipt_photo_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  r public.rides%ROWTYPE;
  v_item_id uuid;
  v_count int;
  v_shops int;
  v_goods numeric;
  v_last timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  -- BETWEEN rejects NULL, NaN and both infinities.
  IF p_shop_name IS NULL OR btrim(p_shop_name) = '' OR length(p_shop_name) > 200
     OR p_product_name IS NULL OR btrim(p_product_name) = '' OR length(p_product_name) > 200
     OR p_price IS NULL OR NOT (p_price BETWEEN 0 AND 100000)
     OR (p_unit IS NOT NULL AND p_unit NOT IN ('kilo', 'half', 'quarter', 'piece', 'amount'))
     OR (p_quantity IS NOT NULL AND NOT (p_quantity BETWEEN 0.001 AND 1000))
     OR (p_receipt_photo_url IS NOT NULL AND length(p_receipt_photo_url) > 1000) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.driver_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.drivers d
                     WHERE d.id = r.driver_id AND d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;
  -- Shopping happens after the price is agreed and before the trip
  -- starts; terminal and post-shopping states refuse new items (#208).
  IF r.status NOT IN ('matched', 'arrived')
     OR NOT r.courier_quote_locked
     OR r.courier_shopping_finished THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;

  -- A rejected item must be cancelled before anything else is added (B2).
  IF EXISTS (SELECT 1 FROM public.courier_invoice_items
              WHERE ride_id = p_ride_id AND status = 'rejected') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'REJECTED_ITEMS_OPEN');
  END IF;

  -- Caps and throttle count EVERY attempted row, cancelled ones
  -- included, so add-cancel-readd loops cannot bypass them (#209).
  SELECT count(*), max(created_at)
    INTO v_count, v_last
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id;
  IF v_count >= 50 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ITEM_CAP');
  END IF;
  IF v_last IS NOT NULL AND v_last > now() - interval '1 second' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'THROTTLED');
  END IF;
  -- The money-active aggregate counts live items only (pending +
  -- approved; rejected and cancelled rows never move money). It stays
  -- strictly below 5,000,000 EGP: at the per-item cap (100,000) and
  -- item cap (50) the theoretical maximum is exactly 5,000,000, so
  -- this bound is the real enforcement.
  SELECT COALESCE(sum(price), 0) INTO v_goods
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id AND status IN ('pending', 'approved');
  IF v_goods + p_price >= 5000000 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'GOODS_CAP');
  END IF;

  -- A new shop may not push the ride past 20 distinct shops (the
  -- courier_shop_count CHECK is 1..20).
  SELECT count(DISTINCT lower(btrim(shop_name))) INTO v_shops
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id AND status <> 'cancelled';
  IF NOT EXISTS (
       SELECT 1 FROM public.courier_invoice_items
        WHERE ride_id = p_ride_id AND status <> 'cancelled'
          AND lower(btrim(shop_name)) = lower(btrim(p_shop_name))
     ) AND v_shops >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'SHOP_CAP');
  END IF;

  INSERT INTO public.courier_invoice_items
    (ride_id, shop_name, product_name, unit, quantity, price, receipt_photo_url)
  VALUES (p_ride_id, btrim(p_shop_name), btrim(p_product_name),
          p_unit, p_quantity, p_price, p_receipt_photo_url)
  RETURNING id INTO v_item_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (p_ride_id, 'courier_invoice_item_added', 'driver',
          jsonb_build_object('item_id', v_item_id, 'shop', btrim(p_shop_name),
                             'price', p_price));

  RETURN jsonb_build_object('ok', true, 'item_id', v_item_id);
END;
$function$;

-- The customer approves or rejects a pending item before it is bought.
-- Ride-first lock order; terminal and post-shopping states refuse new
-- decisions (#207/#208).
CREATE OR REPLACE FUNCTION public.decide_courier_invoice_item(
  p_item_id uuid,
  p_action text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  it public.courier_invoice_items%ROWTYPE;
  r public.rides%ROWTYPE;
  v_ride_id uuid;
  v_driver_uid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  -- A NULL action must fall to INVALID_INPUT (#207).
  IF p_action IS NULL OR p_action NOT IN ('approve', 'reject') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT i.ride_id INTO v_ride_id FROM public.courier_invoice_items i
   WHERE i.id = p_item_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  -- Ride first, then the item (#208); re-read under the locks.
  SELECT * INTO r FROM public.rides WHERE id = v_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.status NOT IN ('matched', 'arrived') OR r.courier_shopping_finished THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  IF r.rider_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO it FROM public.courier_invoice_items WHERE id = p_item_id FOR UPDATE;
  IF it.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ITEM_NOT_PENDING');
  END IF;

  UPDATE public.courier_invoice_items
     SET status = CASE WHEN p_action = 'approve' THEN 'approved' ELSE 'rejected' END,
         decided_at = now()
   WHERE id = p_item_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (it.ride_id,
          CASE WHEN p_action = 'approve' THEN 'courier_invoice_item_approved'
               ELSE 'courier_invoice_item_rejected' END,
          'customer',
          jsonb_build_object('item_id', p_item_id));

  -- A rejection reaches the driver while he is still at the shop.
  IF p_action = 'reject' AND r.driver_id IS NOT NULL THEN
    SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
    IF v_driver_uid IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
      VALUES (v_driver_uid, 'صنف مرفوض',
              'العميل رفض "' || left(it.product_name, 100) || '". الغيه وانت في المحل.',
              'courier_invoice',
              jsonb_build_object('ride_id', it.ride_id, 'item_id', p_item_id),
              true);
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- The driver cancels a pending or rejected item (he is still at the shop).
CREATE OR REPLACE FUNCTION public.cancel_courier_invoice_item(
  p_item_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  it public.courier_invoice_items%ROWTYPE;
  r public.rides%ROWTYPE;
  v_ride_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  SELECT i.ride_id INTO v_ride_id FROM public.courier_invoice_items i
   WHERE i.id = p_item_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = v_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.status NOT IN ('matched', 'arrived') OR r.courier_shopping_finished THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  IF r.driver_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.drivers d
                     WHERE d.id = r.driver_id AND d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  SELECT * INTO it FROM public.courier_invoice_items WHERE id = p_item_id FOR UPDATE;
  IF it.status NOT IN ('pending', 'rejected') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;

  UPDATE public.courier_invoice_items
     SET status = 'cancelled', cancelled_at = now()
   WHERE id = p_item_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (it.ride_id, 'courier_invoice_item_cancelled', 'driver',
          jsonb_build_object('item_id', p_item_id));

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- The driver ends shopping: every invoice item must be decided and every
-- rejected item cancelled, then the goods total (approved items only) is
-- locked onto the ride. Not repeatable (#208). start_trip refuses
-- ask-anything rides before this point.
CREATE OR REPLACE FUNCTION public.finish_courier_shopping(
  p_ride_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  r public.rides%ROWTYPE;
  v_pending int;
  v_rejected int;
  v_goods numeric;
  v_shops int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.driver_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.drivers d
                     WHERE d.id = r.driver_id AND d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;
  IF NOT r.courier_quote_locked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_NOT_LOCKED');
  END IF;
  IF r.status NOT IN ('matched', 'arrived') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  -- Not repeatable (#208).
  IF r.courier_shopping_finished THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;

  SELECT count(*) FILTER (WHERE status = 'pending'),
         count(*) FILTER (WHERE status = 'rejected')
    INTO v_pending, v_rejected
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id;
  IF v_pending > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ITEMS_PENDING',
                            'pending_items', v_pending);
  END IF;
  IF v_rejected > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'REJECTED_ITEMS_OPEN',
                            'rejected_items', v_rejected);
  END IF;

  SELECT COALESCE(sum(price), 0), count(DISTINCT lower(btrim(shop_name)))
    INTO v_goods, v_shops
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id AND status = 'approved';
  IF v_goods >= 5000000 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'GOODS_CAP');
  END IF;

  UPDATE public.rides
     SET courier_goods_total = v_goods,
         courier_shopping_finished = true,
         courier_shop_count = GREATEST(v_shops, 1)
   WHERE id = p_ride_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (p_ride_id, 'courier_shopping_finished', 'driver',
          jsonb_build_object('goods_total', v_goods, 'shops', v_shops));

  RETURN jsonb_build_object('ok', true, 'goods_total', v_goods,
                            'shops', v_shops, 'fare', r.fare,
                            'customer_total', COALESCE(r.fare, 0) + v_goods);
END;
$function$;

-- ── start_trip guard (B1: exact live body + the marked 436 guard) ──────

CREATE OR REPLACE FUNCTION public.start_trip(p_ride_id uuid, p_driver_id uuid, p_otp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'arrived' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  -- 436: ask-anything rides need the agreed (locked) fare and closed
  -- shopping before the trip can start.
  IF r.is_ask_anything
     AND (NOT r.courier_quote_locked OR NOT r.courier_shopping_finished) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'shopping_not_finished');
  END IF;
  IF NOT public._verify_delivery_handoff(p_ride_id,'pickup',p_otp) THEN
    RETURN jsonb_build_object('success',false,'reason','INVALID_OR_LOCKED_PICKUP_CODE');
  END IF;
  UPDATE rides SET status = 'inTrip', started_at = NOW(), picked_up_at = NOW()
    WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'picked_up', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'inTrip');
END;
$function$
;

-- ── cancel_ride_lifecycle ask-anything handling (B1/B2a) ───────────────

CREATE OR REPLACE FUNCTION public.cancel_ride_lifecycle(p_ride_id uuid, p_by text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_is_rider BOOLEAN;
  v_is_driver BOOLEAN;
  v_driver_id uuid;
  v_dispatch jsonb;
  v_offered boolean;
  v_cancel jsonb;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  v_is_rider := (r.rider_id = auth.uid());
  SELECT id INTO v_driver_id FROM drivers WHERE user_id = auth.uid() AND id = r.driver_id;
  v_is_driver := (v_driver_id IS NOT NULL);
  IF auth.uid() IS NULL OR NOT (COALESCE(v_is_rider,false) OR COALESCE(v_is_driver,false)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF r.status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  -- Goods are physically with the driver: a plain cancellation would erase
  -- custody. This is an incident, not a cancel.
  IF r.status = 'inTrip' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'in_custody');
  END IF;

  -- 436: ask-anything rides with goods already bought (any approved
  -- item) or shopping closed cannot be plain-cancelled by either side:
  -- the driver paid for goods with no purchaser on record. This is an
  -- incident (report_delivery_incident), not a cancel (B2a).
  IF r.is_ask_anything
     AND (r.courier_shopping_finished
          OR EXISTS (SELECT 1 FROM public.courier_invoice_items
                      WHERE ride_id = p_ride_id AND status = 'approved')) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'ask_anything_goods_in_progress');
  END IF;

  -- Driver backs out before pickup: keep the customer's delivery alive and
  -- re-offer it to other drivers automatically.
  IF v_is_driver AND r.status IN ('matched','arrived') THEN
    -- 436: the next driver must inherit no money state from the first
    -- (B2a): pending quotes supersede, open invoice items cancel, the
    -- locked fare and every ask-anything flag reset.
    IF r.is_ask_anything THEN
      UPDATE public.courier_quotes
         SET status = 'superseded', decided_at = now()
       WHERE ride_id = p_ride_id AND status = 'pending';
      UPDATE public.courier_invoice_items
         SET status = 'cancelled', cancelled_at = now()
       WHERE ride_id = p_ride_id AND status IN ('pending', 'rejected');
      UPDATE rides SET fare = NULL, courier_quote_locked = false,
        courier_goods_total = 0, courier_shopping_finished = false
        WHERE id = p_ride_id;
    END IF;
    UPDATE ride_requests SET status = 'cancelled', responded_at = NOW()
      WHERE ride_id = p_ride_id AND driver_id = v_driver_id AND status = 'accepted';
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND status = 'offered';
    UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;
    UPDATE rides SET status = 'searching', driver_id = NULL,
      cancellation_reason = p_reason, cancelled_by = 'driver'
      WHERE id = p_ride_id;
    INSERT INTO trip_events (ride_id, event_type, actor)
      VALUES (p_ride_id, 'driver_cancelled_redispatch', 'driver');

    v_dispatch := public._dispatch_delivery_internal(p_ride_id, 25.0, 15);
    v_offered := COALESCE((v_dispatch->>'success')::boolean, false);

    UPDATE public.orders
       SET driver_id = NULL,
           dispatch_status = CASE WHEN v_offered THEN 'OFFERED' ELSE 'PENDING_DISPATCH' END,
           updated_at = now()
     WHERE id = r.order_id
       AND status NOT IN ('cancelled','delivered');

    RETURN jsonb_build_object('success', true, 'status', 'redispatching',
      'offered', v_offered,
      'dispatch_reason', v_dispatch->>'reason');
  END IF;

  -- 194: a customer (rider) cancel with a linked order goes through
  -- cancel_order so the monthly ladder, finalization and notifications all
  -- fire exactly as on the orders screen. cancel_order's finalizer also
  -- cancels this ride (same order_id), so only the peripheral cleanup stays.
  IF v_is_rider AND r.order_id IS NOT NULL THEN
    v_cancel := public.cancel_order(r.order_id, p_reason);
    IF NOT COALESCE((v_cancel->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('success', false,
        'reason', lower(coalesce(v_cancel->>'code', 'cancel_failed')),
        'detail', v_cancel);
    END IF;
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND status = 'offered';
    UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;
    INSERT INTO trip_events (ride_id, event_type, actor)
      VALUES (p_ride_id, 'cancelled', 'rider');
    RETURN jsonb_build_object('success', true, 'status', 'cancelled');
  END IF;

  -- 436: a full cancel also clears ask-anything money state so reports
  -- never see a locked fare or goods total on a dead ride (B2a).
  IF r.is_ask_anything THEN
    UPDATE public.courier_quotes
       SET status = 'superseded', decided_at = now()
     WHERE ride_id = p_ride_id AND status = 'pending';
    UPDATE public.courier_invoice_items
       SET status = 'cancelled', cancelled_at = now()
     WHERE ride_id = p_ride_id AND status IN ('pending', 'rejected');
    UPDATE rides SET fare = NULL, courier_quote_locked = false,
      courier_goods_total = 0, courier_shopping_finished = false
      WHERE id = p_ride_id;
  END IF;

  UPDATE rides SET status = 'cancelled', cancelled_at = NOW(),
    cancellation_reason = p_reason,
    cancelled_by = CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND status = 'offered';
  UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;

  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (p_ride_id, 'cancelled', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END);
  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$function$;


-- ── resolve_delivery_incident: order-less courier rides (security a) ──
-- Exact live body + two marked 436 blocks. An ask-anything ride has no
-- order, so (1) the region lock falls back to the rider's region and
-- (2) a cancelling resolution closes the RIDE directly instead of
-- calling _finalize_order_cancel(NULL). The goods money state (invoice
-- items, courier_goods_total) stays recorded for the ops settlement
-- that follows the incident.

CREATE OR REPLACE FUNCTION public.resolve_delivery_incident(p_incident_id uuid, p_resolution text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  i public.delivery_incidents%rowtype;
  v_region uuid;
  -- 436: order-less courier rides (ask-anything) resolve below.
  v_ride public.rides%rowtype;
begin
  if not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  if p_resolution not in ('redelivered','returned_to_merchant','cancelled','dismissed') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_resolution');
  end if;
  select * into i from public.delivery_incidents where id = p_incident_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if i.status = 'resolved' then
    return jsonb_build_object('ok', false, 'reason', 'already_resolved');
  end if;

  -- Region lock (194): the incident's order customer's region governs.
  select u.region_id into v_region
    from public.orders o join public.users u on u.id = o.user_id
   where o.id = i.order_id;
  -- 436: an order-less courier ride (ask-anything) has no order
  -- customer; the rider's region governs instead.
  if v_region is null and i.order_id is null then
    select u.region_id into v_region
      from public.rides ri join public.users u on u.id = ri.rider_id
     where ri.id = i.ride_id;
  end if;
  if not public._admin_scope_allows(v_region) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden_region');
  end if;

  -- Returned goods end the ride and the order; a plain cancel of the order
  -- closes it out. Redelivery keeps the ride alive for the driver to finish.
  -- 194: incident-cancels do NOT restock (goods may be unsellable) but DO
  -- refund and release the coupon, and clear the driver + ride.
  if p_resolution in ('returned_to_merchant','cancelled') then
    -- 436: an order-less courier ride (ask-anything) has no order to
    -- finalize; cancel the ride directly. The goods money state
    -- (invoice items, courier_goods_total) stays recorded for the ops
    -- settlement that follows the incident.
    if i.order_id is null then
      update public.rides
         set status = 'cancelled', cancelled_at = now(),
             cancellation_reason = 'incident: ' || p_resolution,
             cancelled_by = 'system'
       where id = i.ride_id
         and status not in ('completed', 'cancelled');
      update public.ride_requests set status = 'expired', responded_at = now()
       where ride_id = i.ride_id and status = 'offered';
      update public.driver_locations set ride_id = null
       where ride_id = i.ride_id;
    else
      perform public._finalize_order_cancel(
        i.order_id, 'incident', 'incident: ' || p_resolution,
        false, true, true, 'system');
    end if;
  end if;

  update public.delivery_incidents
     set status = 'resolved', resolution = p_resolution,
         note = coalesce(nullif(btrim(p_note), ''), note),
         resolved_by = auth.uid(), resolved_at = now()
   where id = p_incident_id;
  insert into trip_events (ride_id, event_type, actor)
    values (i.ride_id, 'incident_resolved_' || p_resolution, 'support');
  return jsonb_build_object('ok', true, 'resolution', p_resolution);
end;
$function$
;


-- ── Earnings (B1: exact live 395 body + one marked narrow block; the ───
-- ── 188 delay waiver and the 395 credit netting stay byte-identical) ───

CREATE OR REPLACE FUNCTION public._record_delivery_earnings(p_ride_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.rides%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_merchant_model text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_driver_commission numeric;
  v_currency text;
  v_due_hours integer;
  v_goods numeric;
  v_goods_pre numeric;
  v_credit numeric := 0;
  v_is_cash boolean;
BEGIN
  SELECT * INTO r FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND OR r.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one earning/commission pair per ride.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE ride_id = p_ride_id) THEN
    RETURN;
  END IF;

  -- Idempotent across paths: when the order-scoped accrual (172 trigger on
  -- orders.status -> delivered) already ran for the linked order, skip.
  -- complete_delivery updates orders.status BEFORE calling this function,
  -- so without this check both paths accrue (regression found in E2E).
  IF r.order_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.driver_earnings WHERE order_id = r.order_id) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
  v_currency := COALESCE(NULLIF(r.currency, ''), 'EGP');
  v_is_cash := lower(COALESCE(r.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fare minus the driver-rate commission.
  v_gross := COALESCE(r.fare, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  -- 188: driver-delay waiver - the platform takes NO commission from the
  -- replacement driver on an order that was redispatched for a delay.
  if r.order_id is not null and exists (
    select 1 from public.driver_delay_events de where de.order_id = r.order_id
  ) then
    v_commission := 0;
  end if;
  v_driver_commission := v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (r.driver_id, p_ride_id, 'trip', v_gross - v_commission, v_currency,
          'Delivery fare ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'ride', p_ride_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal for merchant orders.
  IF r.order_id IS NOT NULL THEN
    SELECT * INTO v_order FROM public.orders WHERE id = r.order_id;
    IF FOUND AND v_order.merchant_id IS NOT NULL THEN
        -- 395: platform gift credit consumed at checkout (0 for most orders).
        v_credit := COALESCE(v_order.platform_credit_applied, 0);
      SELECT owner_user_id, type, settlement_model
        INTO v_merchant_uid, v_merchant_type, v_merchant_model
        FROM public.merchants WHERE id = v_order.merchant_id;
      IF v_merchant_uid IS NOT NULL THEN
        v_gross := COALESCE(v_order.subtotal, 0);
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
        v_commission := public.calculate_commission(v_gross, v_rate);
        INSERT INTO public.platform_commissions
          (member_id, reference_type, reference_id, gross_amount, commission_rate,
           commission_amount, net_amount, currency, status)
        VALUES (v_merchant_uid, 'order', v_order.id, v_gross, v_rate, v_commission,
                v_gross - v_commission, v_currency, 'computed')
        ON CONFLICT (reference_type, reference_id) DO NOTHING;

        IF v_is_cash THEN
          SELECT settlement_remittance_due_hours INTO v_due_hours
            FROM public._settlement_settings();
          v_due_hours := COALESCE(v_due_hours, 24);

          -- Goods money: order value minus the delivery fee (driver keeps the
          -- fare side). Owed to the platform (model A) or the merchant (B).
          -- 395 (owner decision 2026-11-23): the gift is netted INTO
          -- the remittance at settlement time. The driver owes
          -- pre-credit goods minus the gift (never below zero), so
          -- the escalation, overdue and dispatch cash-ceiling checks
          -- all read the net amount straight from the obligation.
          -- The platform_subsidies row records the split: remittance
          -- reduction, a payable to the driver when the gift eats
          -- into his fare, and (direct model) a payable to the
          -- merchant, who must still receive full goods.
          v_goods_pre := GREATEST(
            COALESCE(v_order.total_amount, 0) + COALESCE(v_order.platform_credit_applied, 0)
            - COALESCE(v_order.delivery_fee, 0), 0);
          v_goods := GREATEST(v_goods_pre - v_credit, 0);
          IF v_goods > 0 THEN
            INSERT INTO public.driver_obligations
              (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
               owed_to, due_at)
            VALUES
              (r.driver_id, p_ride_id, v_order.id, v_order.merchant_id, 'goods',
               v_goods, v_currency,
               CASE WHEN v_merchant_model = 'direct' THEN 'merchant' ELSE 'platform' END,
               now() + make_interval(hours => v_due_hours))
            ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;

            INSERT INTO public.notifications
              (user_id, title, body, type, data, send_push)
            SELECT v_driver_uid,
                   'تسوية كاش مستحقة',
                   CASE WHEN v_credit > 0 THEN
                       'التوريد ' || v_goods::text || ' ' || v_currency ||
                         ' مستحق خلال ' || v_due_hours::text || ' ساعة. المنصة بتغطي ' ||
                         trim(to_char(v_credit, 'FM999990.##')) ||
                         ' من قيمة البضاعة (هدية العميل مننا).'
                   ELSE
                       'قبضت ' || v_goods::text || ' ' || v_currency ||
                         ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.'
                   END,
                   'settlement',
                   jsonb_build_object('ride_id', p_ride_id, 'amount', v_goods),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND (n.data->>'ride_id' = p_ride_id::text
                      OR n.data->>'order_id' = v_order.id::text)
            );
          ELSIF v_credit > 0 THEN
            -- The gift covered every pound of goods: no remittance is due.
            INSERT INTO public.notifications
              (user_id, title, body, type, data, send_push)
            SELECT v_driver_uid,
                   'مفيش توريد على الطلب ده',
                   'المنصة بتغطي ' || trim(to_char(v_credit, 'FM999990.##')) || ' ' || v_currency ||
                     ' (هدية العميل مننا). مفيش توريد بضاعة مستحق عليك للطلب ده.',
                   'settlement',
                   jsonb_build_object('order_id', v_order.id, 'amount', 0),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND (n.data->>'ride_id' = p_ride_id::text OR n.data->>'order_id' = v_order.id::text)
            );
          END IF;

          -- Model A: platform owes the merchant goods minus its commission.
          IF v_merchant_model IS DISTINCT FROM 'direct' THEN
            INSERT INTO public.merchant_ledger
              (merchant_id, order_id, entry_type, amount, currency, description)
            VALUES
              (v_order.merchant_id, v_order.id, 'credit',
               v_gross - v_commission, v_currency,
               'Order goods ' || v_gross::text || ' less ' || v_rate::text || '% platform commission')
            ON CONFLICT (order_id, entry_type)
              WHERE order_id IS NOT NULL AND entry_type = 'credit'
              DO NOTHING;
          END IF;

          -- 395: netted platform subsidy ledger. The gift reduces the
          -- driver's goods remittance (recorded net above); this row is the
          -- accounting trail of who the platform still owes: the driver when
          -- the gift ate into his fare (driver_payable) and, in the direct
          -- model, the merchant who must receive full goods
          -- (merchant_payable). Inserted exactly once per order, in the same
          -- transaction as the obligation; admin reads it via service_role.
          IF v_credit > 0
             AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                              WHERE ps.order_id = v_order.id
                                AND ps.kind = 'delay_apology_credit') THEN
            INSERT INTO public.platform_subsidies
              (order_id, kind, amount, settlement_model, reimburses,
               remittance_reduction, driver_payable, merchant_payable, status)
            VALUES
              (v_order.id, 'delay_apology_credit', v_credit,
               CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
               'driver',
               LEAST(v_credit, v_goods_pre),
               GREATEST(v_credit - v_goods_pre, 0),
               CASE WHEN v_merchant_model = 'direct'
                    THEN LEAST(v_credit, v_goods_pre) ELSE 0 END,
               'netted');
            PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', v_order.id::text,
              jsonb_build_object('amount', v_credit,
                'remittance_reduction', LEAST(v_credit, v_goods_pre),
                'driver_payable', GREATEST(v_credit - v_goods_pre, 0),
                'settlement_model', CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END));
          END IF;

        END IF;

          -- 395: non-cash credited orders carry no remittance, so the gift
          -- costs the platform nothing extra here (it already holds the
          -- money); record the subsidy for complete accounting only.
          IF NOT v_is_cash AND v_credit > 0
             AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                              WHERE ps.order_id = v_order.id
                                AND ps.kind = 'delay_apology_credit') THEN
            INSERT INTO public.platform_subsidies
              (order_id, kind, amount, settlement_model, reimburses,
               remittance_reduction, driver_payable, merchant_payable, status)
            VALUES
              (v_order.id, 'delay_apology_credit', v_credit,
               CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
               'driver', 0, 0, 0, 'netted_noncash');
            PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', v_order.id::text,
              jsonb_build_object('amount', v_credit, 'status', 'netted_noncash'));
          END IF;
      END IF;
    END IF;
  END IF;

  -- 436 (ask-anything courier only): record the goods pass-through as a
  -- trip event so settlement reports separate goods money from fare
  -- money. The itemized invoice plus rides.courier_goods_total are the
  -- #152 goods-money ledger; no driver_obligation is booked for goods
  -- (under cash the driver fronts goods money at the shop and is
  -- reimbursed by the customer, so an obligation would double-charge
  -- him).
  IF r.is_ask_anything AND r.order_id IS NULL
     AND COALESCE(r.courier_goods_total, 0) > 0 THEN
    INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
    VALUES (p_ride_id, 'courier_goods_recorded', 'system',
            jsonb_build_object('goods_total', r.courier_goods_total,
                               'currency', v_currency,
                               'approved_items', (SELECT count(*)
                    FROM public.courier_invoice_items
                   WHERE ride_id = p_ride_id AND status = 'approved')));
  END IF;

  -- Cash rides of any kind: the platform's driver-side commission is debt
  -- until remitted (pure cash rides have no goods obligation).
  IF v_is_cash AND v_driver_commission > 0 THEN
    SELECT settlement_remittance_due_hours INTO v_due_hours
      FROM public._settlement_settings();
    INSERT INTO public.driver_obligations
      (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
       owed_to, due_at)
    VALUES
      (r.driver_id, p_ride_id, r.order_id, r.merchant_id, 'commission',
       v_driver_commission, v_currency, 'platform',
       now() + make_interval(hours => COALESCE(v_due_hours, 24)))
    ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;
  END IF;
END;
$function$
;

-- ── Grants ──────────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.request_courier_shopping(numeric, numeric, text, numeric, numeric, text, jsonb, integer, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_courier_shopping(numeric, numeric, text, numeric, numeric, text, jsonb, integer, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.propose_courier_quote(uuid, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.propose_courier_quote(uuid, numeric, text) TO authenticated;

REVOKE ALL ON FUNCTION public.respond_courier_quote(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.respond_courier_quote(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.add_courier_invoice_item(uuid, text, text, numeric, text, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_courier_invoice_item(uuid, text, text, numeric, text, numeric, text) TO authenticated;

REVOKE ALL ON FUNCTION public.decide_courier_invoice_item(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decide_courier_invoice_item(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_courier_invoice_item(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_courier_invoice_item(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.finish_courier_shopping(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finish_courier_shopping(uuid) TO authenticated;

-- start_trip, cancel_ride_lifecycle, resolve_delivery_incident and
-- _record_delivery_earnings keep their existing grants (CREATE OR
-- REPLACE preserves ACLs).

-- ── ACL postchecks (430 pattern: PUBLIC via aclexplode grantee 0) ───────

DO $$
DECLARE
  v_sigs regprocedure[] := ARRAY[
    'public.request_courier_shopping(numeric,numeric,text,numeric,numeric,text,jsonb,integer,text,text)'::regprocedure,
    'public.propose_courier_quote(uuid,numeric,text)'::regprocedure,
    'public.respond_courier_quote(uuid,text)'::regprocedure,
    'public.add_courier_invoice_item(uuid,text,text,numeric,text,numeric,text)'::regprocedure,
    'public.decide_courier_invoice_item(uuid,text)'::regprocedure,
    'public.cancel_courier_invoice_item(uuid)'::regprocedure,
    'public.finish_courier_shopping(uuid)'::regprocedure
  ];
  v_sig regprocedure;
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    IF EXISTS (
      SELECT 1 FROM pg_proc p,
           aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = v_sig::oid
        AND a.grantee = 0
        AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION '436: % executable by PUBLIC', v_sig;
    END IF;
    IF has_function_privilege('anon', v_sig, 'EXECUTE') THEN
      RAISE EXCEPTION '436: % executable by anon', v_sig;
    END IF;
    IF NOT has_function_privilege('authenticated', v_sig, 'EXECUTE') THEN
      RAISE EXCEPTION '436: authenticated lost EXECUTE on %', v_sig;
    END IF;
  END LOOP;

  -- Replaced globals: _record_delivery_earnings stays internal
  -- (postgres + service_role only); start_trip and cancel_ride_lifecycle
  -- keep authenticated EXECUTE and nothing wider.
  IF has_function_privilege('anon',
       'public._record_delivery_earnings(uuid)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('authenticated',
       'public._record_delivery_earnings(uuid)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION '436: _record_delivery_earnings leaked EXECUTE';
  END IF;
  IF has_function_privilege('anon',
       'public.start_trip(uuid,uuid,text)'::regprocedure, 'EXECUTE')
     OR NOT has_function_privilege('authenticated',
       'public.start_trip(uuid,uuid,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION '436: start_trip ACL drifted';
  END IF;
  IF has_function_privilege('anon',
       'public.cancel_ride_lifecycle(uuid,text,text)'::regprocedure, 'EXECUTE')
     OR NOT has_function_privilege('authenticated',
       'public.cancel_ride_lifecycle(uuid,text,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION '436: cancel_ride_lifecycle ACL drifted';
  END IF;
  IF has_function_privilege('anon',
       'public.resolve_delivery_incident(uuid,text,text)'::regprocedure, 'EXECUTE')
     OR NOT has_function_privilege('authenticated',
       'public.resolve_delivery_incident(uuid,text,text)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION '436: resolve_delivery_incident ACL drifted';
  END IF;

  -- Post-replacement property asserts (#210): every replaced global
  -- keeps SECURITY DEFINER, its search_path, the rides owner and its
  -- exact effective EXECUTE set.
  IF EXISTS (
    SELECT 1 FROM pg_proc p
     WHERE p.oid IN (
       'public._record_delivery_earnings(uuid)'::regprocedure,
       'public.start_trip(uuid,uuid,text)'::regprocedure,
       'public.cancel_ride_lifecycle(uuid,text,text)'::regprocedure,
       'public.resolve_delivery_incident(uuid,text,text)'::regprocedure)
       AND (NOT p.prosecdef
            OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']::text[]
            OR pg_get_userbyid(p.proowner) IS DISTINCT FROM
               (SELECT pg_get_userbyid(t.relowner) FROM pg_class t
                 WHERE t.relname = 'rides' AND t.relnamespace = 'public'::regnamespace))
  ) THEN
    RAISE EXCEPTION '436: a replaced global lost secdef/search_path/owner';
  END IF;

  -- Added-column shape checks (#210): every rides column this migration
  -- adds, with type, nullability, default and (for the numeric one)
  -- precision and scale.
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('is_ask_anything', 'boolean', 'NO', 'false', NULL::int, NULL::int),
      ('courier_shop_count', 'integer', 'NO', '1', NULL, NULL),
      ('courier_quote_locked', 'boolean', 'NO', 'false', NULL, NULL),
      ('courier_goods_total', 'numeric', 'NO', '0'::text, 10, 2),
      ('courier_shopping_finished', 'boolean', 'NO', 'false', NULL, NULL)
    ) AS want(col, typ, nullable, dflt, prec, scale)
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
       WHERE c.table_schema = 'public' AND c.table_name = 'rides'
         AND c.column_name = want.col AND c.data_type = want.typ
         AND c.is_nullable = want.nullable
         AND c.column_default::text LIKE want.dflt || '%'
         AND (want.prec IS NULL
              OR (c.numeric_precision = want.prec AND c.numeric_scale = want.scale))
    )
  ) THEN
    RAISE EXCEPTION '436: added rides column shape mismatch';
  END IF;
END $$;

COMMIT;
