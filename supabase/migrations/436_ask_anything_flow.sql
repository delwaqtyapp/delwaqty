-- 436: ask-anything courier flow (owner decision 2026-11-24, issue #28).
--
-- The owner's product decision for the ask-anything button (kept as is):
-- the customer picks a unit (kilo / half / quarter) or an EGP amount and
-- writes the product; the delivery price is set by the driver (starting
-- from the 15 EGP first shop + 5 EGP per extra shop baseline, rising with
-- distance) and the customer accepts, rejects or negotiates - never
-- forced; the driver buys at the shops and records each item with its
-- shop name and real price (typed, or a receipt photo); the customer sees
-- a live itemized invoice and approves each item before it is bought;
-- rejected items are cancelled by the driver while still at the shop.
-- Final charge = locked agreed delivery price + approved items total.
-- Goods are paid separately from the fare; the platform takes commission
-- on the fare only. No pharmacy items.
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

BEGIN;

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
  quantity numeric(10,3) CHECK (quantity IS NULL OR quantity > 0),
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

-- Live itemized invoice: all three tables stream over realtime.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'n') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                    WHERE pubname = 'n' AND schemaname = 'public'
                      AND tablename = 'courier_request_items') THEN
      ALTER PUBLICATION n ADD TABLE public.courier_request_items;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                    WHERE pubname = 'n' AND schemaname = 'public'
                      AND tablename = 'courier_quotes') THEN
      ALTER PUBLICATION n ADD TABLE public.courier_quotes;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                    WHERE pubname = 'n' AND schemaname = 'public'
                      AND tablename = 'courier_invoice_items') THEN
      ALTER PUBLICATION n ADD TABLE public.courier_invoice_items;
    END IF;
  END IF;
END $$;

-- ── Ride columns ────────────────────────────────────────────────────────

ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS is_ask_anything boolean NOT NULL DEFAULT false;
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_shop_count integer NOT NULL DEFAULT 1
  CHECK (courier_shop_count BETWEEN 1 AND 20);
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_quote_locked boolean NOT NULL DEFAULT false;
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_goods_total numeric(10,2) NOT NULL DEFAULT 0
  CHECK (courier_goods_total >= 0);
ALTER TABLE public.rides ADD COLUMN IF NOT EXISTS courier_shopping_finished boolean NOT NULL DEFAULT false;

-- ── Request RPC ─────────────────────────────────────────────────────────

-- Ask-anything request: the 430 courier creation with structured items.
-- fare/payment/order_id/merchant_id stay server-controlled exactly as in
-- request_courier_delivery; the fare is locked later by quote acceptance.
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

  -- Validate every item before touching anything.
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
      IF v_amount IS NULL OR v_amount <= 0 OR v_amount > 100000 THEN
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
    fare, order_id, merchant_id,
    is_ask_anything, courier_shop_count
  ) VALUES (
    v_uid,
    p_pickup_latitude, p_pickup_longitude, p_pickup_address,
    p_dropoff_latitude, p_dropoff_longitude, p_dropoff_address,
    'motorcycle', 'courier', 'searching',
    left(v_summary, 500), p_dropoff_notes, COALESCE(p_priority, 'standard'),
    NULL, NULL, NULL,
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

-- The driver proposes the delivery price (starting from the 15+5/shop
-- baseline, rising with distance); the rider answers with
-- respond_courier_quote. The rider's counters also go through this RPC:
-- the caller's role is derived from the ride, never from the caller.
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
  v_driver_uid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_amount IS NULL OR p_amount < 15 OR p_amount > 50000 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_AMOUNT');
  END IF;
  IF p_note IS NOT NULL AND length(p_note) > 300 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND OR NOT r.is_ask_anything THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;
  IF r.courier_quote_locked THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_ALREADY_LOCKED');
  END IF;
  IF r.status NOT IN ('matched', 'arrived') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
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

  UPDATE public.courier_quotes
     SET status = 'superseded', decided_at = now()
   WHERE ride_id = p_ride_id AND status = 'pending';

  v_baseline := 15 + 5 * (r.courier_shop_count - 1);

  INSERT INTO public.courier_quotes
    (ride_id, proposed_by_role, proposed_by, amount, note)
  VALUES (p_ride_id, v_role, v_uid, p_amount, p_note)
  RETURNING id INTO v_quote_id;

  INSERT INTO public.trip_events (ride_id, event_type, actor, metadata)
  VALUES (p_ride_id, 'courier_quote_proposed', v_role,
          jsonb_build_object('quote_id', v_quote_id, 'amount', p_amount));

  -- Notify the counterparty.
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

-- Accept or reject the open quote. Only the counterparty of whoever
-- proposed it may answer. Accept LOCKS rides.fare to the agreed amount;
-- after the lock no further quotes are possible.
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
  v_driver_id uuid;
  v_driver_uid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_action NOT IN ('accept', 'reject') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT * INTO q FROM public.courier_quotes WHERE id = p_quote_id FOR UPDATE;
  IF NOT FOUND OR q.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'QUOTE_NOT_PENDING');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = q.ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  SELECT id, user_id INTO v_driver_id, v_driver_uid
    FROM public.drivers WHERE id = r.driver_id;

  -- Only the counterparty answers.
  IF q.proposed_by_role = 'driver' THEN
    IF r.rider_id IS DISTINCT FROM v_uid THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
    END IF;
  ELSE
    IF v_driver_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
    END IF;
    SELECT user_id INTO v_driver_uid FROM public.drivers WHERE user_id = v_uid AND id = r.driver_id;
    IF v_driver_uid IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
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
    -- The proposer learns the offer was refused so they can re-propose.
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

  -- accept
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
-- customer approves each one before it is bought.
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_shop_name IS NULL OR btrim(p_shop_name) = '' OR length(p_shop_name) > 200
     OR p_product_name IS NULL OR btrim(p_product_name) = '' OR length(p_product_name) > 200
     OR p_price IS NULL OR p_price < 0 OR p_price > 100000
     OR (p_unit IS NOT NULL AND p_unit NOT IN ('kilo', 'half', 'quarter', 'piece', 'amount'))
     OR (p_quantity IS NOT NULL AND p_quantity <= 0)
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
  -- Shopping happens after the price is agreed and before the trip starts.
  IF NOT r.courier_quote_locked OR r.status NOT IN ('matched', 'arrived')
     OR r.courier_shopping_finished THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
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
  v_driver_uid uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_action NOT IN ('approve', 'reject') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_INPUT');
  END IF;

  SELECT * INTO it FROM public.courier_invoice_items WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND OR it.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ITEM_NOT_PENDING');
  END IF;

  SELECT * INTO r FROM public.rides WHERE id = it.ride_id;
  IF r.rider_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  SELECT * INTO it FROM public.courier_invoice_items WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND OR it.status NOT IN ('pending', 'rejected') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rides r
                  JOIN public.drivers d ON d.id = r.driver_id
                  WHERE r.id = it.ride_id AND d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
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

-- The driver ends shopping: every invoice item must be decided, then the
-- goods total (approved items only) is locked onto the ride. start_trip
-- refuses ask-anything rides before this point.
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

  SELECT count(*) INTO v_pending
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id AND status = 'pending';
  IF v_pending > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ITEMS_PENDING',
                            'pending_items', v_pending);
  END IF;

  SELECT COALESCE(sum(price), 0), count(DISTINCT lower(btrim(shop_name)))
    INTO v_goods, v_shops
    FROM public.courier_invoice_items
   WHERE ride_id = p_ride_id AND status = 'approved';

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

-- ── start_trip guard ────────────────────────────────────────────────────

-- Ask-anything rides may not start the trip before the price is agreed,
-- every invoice item is decided and shopping is closed (144 base text).
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
$function$;

-- ── Earnings: ask-anything goods ledger note ────────────────────────────

-- 180's function, unchanged except the marked block: on completed
-- ask-anything rides the goods pass-through is recorded as a trip event
-- so settlement reports can separate goods money from fare money. No
-- driver_obligation is booked for goods: under cash the driver fronts
-- goods money at the shop and is reimbursed by the customer, so an
-- obligation would double-charge him. The itemized invoice (approved
-- courier_invoice_items) plus rides.courier_goods_total are the ledger.
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
          v_goods := GREATEST(
            COALESCE(v_order.total_amount, 0) - COALESCE(v_order.delivery_fee, 0), 0);
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
                   'قبضت ' || v_goods::text || ' ' || v_currency ||
                     ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.',
                   'settlement',
                   jsonb_build_object('ride_id', p_ride_id, 'amount', v_goods),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND n.data->>'ride_id' = p_ride_id::text
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
        END IF;
      END IF;
    END IF;
  END IF;

  -- Ask-anything courier (436): record the goods pass-through as a trip
  -- event so settlement reports separate goods money from fare money.
  -- The itemized invoice plus rides.courier_goods_total are the #152
  -- goods-money ledger; no driver_obligation is booked for goods (under
  -- cash the driver fronts goods money at the shop and is reimbursed by
  -- the customer, so an obligation would double-charge him).
  IF r.is_ask_anything AND COALESCE(r.courier_goods_total, 0) > 0 THEN
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
$function$;

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

-- start_trip and _record_delivery_earnings keep their existing grants.

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
END $$;

COMMIT;
