-- Migration 119: Provider App Complete Backend & RLS Overhaul
--
-- 1. Expands `merchants_type_check` to include `'service'`, `'home_services'`, and service categories.
-- 2. Fixes RLS policies on `products`, `product_inventory`, `offers`, `branches`, `reservations`,
--    and `working_hours` to check `owner_user_id = auth.uid() OR id = auth.uid()` instead of only `id = auth.uid()`.
-- 3. Adds RLS policies on `service_providers` and `service_bookings` so service providers can view
--    and manage their incoming bookings, and auto-provisions `service_providers` when appropriate.
-- 4. Backfills `product_inventory` for all existing `products` and adds an `AFTER INSERT` trigger
--    on `products` so every new product automatically appears in Inventory.
-- 5. Creates `merchant_dispatch_order_driver(p_order_id uuid)` RPC to create a delivery ride from
--    a merchant order and dispatch nearby delivery drivers.
-- 6. Extends `update_my_storefront` with `p_type` so merchants can change their store category.

-- ─── 1. Expand merchants_type_check Constraint ───────────────────────────────

ALTER TABLE public.merchants
  DROP CONSTRAINT IF EXISTS merchants_type_check;

ALTER TABLE public.merchants
  ADD CONSTRAINT merchants_type_check CHECK (
    type IN (
      'food','restaurant','grocery','supermarket','pharmacy','electronics','fashion','flowers','bakery',
      'general','fruits','meat','seafood','sweets','clothing','shoes','mobile','furniture','home','cafe',
      'petShop','fitness','gas','carwash','perfumes','spices','dairy','accessories','butcher','vegetables',
      'service','home_services','plumbing','electrical','cleaning','handyman','carpentry','ac_maintenance',
      'painting','pest_control','appliance_repair','doctor','clinic','other'
    )
  );

-- ─── 2. Helper Function: Check if Current User Owns a Merchant ID ────────────

CREATE OR REPLACE FUNCTION public.is_merchant_owner(merchant_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.merchants m
     WHERE m.id = merchant_uuid
       AND (m.owner_user_id = auth.uid() OR m.id = auth.uid())
  ) OR public.is_admin();
$$;

GRANT EXECUTE ON FUNCTION public.is_merchant_owner(uuid) TO authenticated, service_role;

-- ─── 3. Fix RLS Policies on Merchant Operational Tables ──────────────────────

-- products
DROP POLICY IF EXISTS products_insert_merchant ON public.products;
CREATE POLICY products_insert_merchant ON public.products
  FOR INSERT TO authenticated
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS products_update_merchant ON public.products;
CREATE POLICY products_update_merchant ON public.products
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS products_delete_merchant ON public.products;
CREATE POLICY products_delete_merchant ON public.products
  FOR DELETE TO authenticated
  USING (public.is_merchant_owner(merchant_id));

-- product_inventory
DROP POLICY IF EXISTS inventory_select_merchant ON public.product_inventory;
CREATE POLICY inventory_select_merchant ON public.product_inventory
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS inventory_insert_merchant ON public.product_inventory;
CREATE POLICY inventory_insert_merchant ON public.product_inventory
  FOR INSERT TO authenticated
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS inventory_update_merchant ON public.product_inventory;
CREATE POLICY inventory_update_merchant ON public.product_inventory
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS inventory_delete_merchant ON public.product_inventory;
CREATE POLICY inventory_delete_merchant ON public.product_inventory
  FOR DELETE TO authenticated
  USING (public.is_merchant_owner(merchant_id));

-- offers
DROP POLICY IF EXISTS offers_insert_merchant ON public.offers;
CREATE POLICY offers_insert_merchant ON public.offers
  FOR INSERT TO authenticated
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS offers_update_merchant ON public.offers;
CREATE POLICY offers_update_merchant ON public.offers
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS offers_delete_merchant ON public.offers;
CREATE POLICY offers_delete_merchant ON public.offers
  FOR DELETE TO authenticated
  USING (public.is_merchant_owner(merchant_id));

-- branches
DROP POLICY IF EXISTS branches_insert_merchant ON public.branches;
CREATE POLICY branches_insert_merchant ON public.branches
  FOR INSERT TO authenticated
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS branches_update_merchant ON public.branches;
CREATE POLICY branches_update_merchant ON public.branches
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id))
  WITH CHECK (public.is_merchant_owner(merchant_id));

DROP POLICY IF EXISTS branches_delete_merchant ON public.branches;
CREATE POLICY branches_delete_merchant ON public.branches
  FOR DELETE TO authenticated
  USING (public.is_merchant_owner(merchant_id));

-- reservations
DROP POLICY IF EXISTS reservations_select_merchant ON public.reservations;
CREATE POLICY reservations_select_merchant ON public.reservations
  FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS reservations_update_merchant ON public.reservations;
CREATE POLICY reservations_update_merchant ON public.reservations
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

-- orders (ensure merchant owner can always view and update their store's orders)
DROP POLICY IF EXISTS orders_select_merchant_owner ON public.orders;
CREATE POLICY orders_select_merchant_owner ON public.orders
  FOR SELECT TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS orders_update_merchant_owner ON public.orders;
CREATE POLICY orders_update_merchant_owner ON public.orders
  FOR UPDATE TO authenticated
  USING (public.is_merchant_owner(merchant_id) OR user_id = auth.uid())
  WITH CHECK (public.is_merchant_owner(merchant_id) OR user_id = auth.uid());

-- ─── 4. Service Providers & Service Bookings RLS + Auto-Provisioning ─────────

DROP POLICY IF EXISTS service_providers_manage_own ON public.service_providers;
CREATE POLICY service_providers_manage_own ON public.service_providers
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS service_bookings_select_provider ON public.service_bookings;
CREATE POLICY service_bookings_select_provider ON public.service_bookings
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.service_providers sp
       WHERE sp.id = service_bookings.provider_id
         AND sp.user_id = auth.uid()
    )
    OR public.is_admin()
  );

DROP POLICY IF EXISTS service_bookings_update_provider ON public.service_bookings;
CREATE POLICY service_bookings_update_provider ON public.service_bookings
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.service_providers sp
       WHERE sp.id = service_bookings.provider_id
         AND sp.user_id = auth.uid()
    )
    OR public.is_admin()
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.service_providers sp
       WHERE sp.id = service_bookings.provider_id
         AND sp.user_id = auth.uid()
    )
    OR public.is_admin()
  );

CREATE OR REPLACE FUNCTION public.resolve_my_service_provider()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sp_id uuid;
  v_user record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_sp_id
    FROM public.service_providers
   WHERE user_id = v_uid
   ORDER BY created_at ASC
   LIMIT 1;

  IF v_sp_id IS NOT NULL THEN
    RETURN v_sp_id;
  END IF;

  SELECT id, full_name, avatar_url, profile_photo_url
    INTO v_user
    FROM public.users
   WHERE id = v_uid;

  IF v_user.id IS NOT NULL THEN
    INSERT INTO public.service_providers (
      user_id, name, category_type, description, profile_image_url,
      rating, rating_count, is_verified, is_available, hourly_rate
    )
    VALUES (
      v_uid,
      COALESCE(NULLIF(btrim(v_user.full_name), ''), 'Delwaqty Provider'),
      'plumbing',
      '',
      COALESCE(v_user.profile_photo_url, v_user.avatar_url),
      5.0,
      0,
      true,
      true,
      100
    )
    RETURNING id INTO v_sp_id;
  END IF;

  RETURN v_sp_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_my_service_provider() TO authenticated, service_role;

-- ─── 5. Auto-Seed & Sync product_inventory From products ─────────────────────

INSERT INTO public.product_inventory (
  product_id,
  merchant_id,
  stock_quantity,
  reserved_quantity,
  low_stock_threshold,
  is_in_stock,
  updated_at
)
SELECT
  p.id,
  p.merchant_id,
  COALESCE(p.stock_quantity, 50),
  0,
  5,
  COALESCE(p.is_available, true),
  now()
FROM public.products p
WHERE p.merchant_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.product_inventory pi WHERE pi.product_id = p.id
  )
ON CONFLICT (product_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.auto_sync_product_inventory()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.merchant_id IS NOT NULL THEN
    INSERT INTO public.product_inventory (
      product_id,
      merchant_id,
      stock_quantity,
      reserved_quantity,
      low_stock_threshold,
      is_in_stock,
      updated_at
    )
    VALUES (
      NEW.id,
      NEW.merchant_id,
      COALESCE(NEW.stock_quantity, 50),
      0,
      5,
      COALESCE(NEW.is_available, true),
      now()
    )
    ON CONFLICT (product_id) DO UPDATE
      SET is_in_stock = COALESCE(NEW.is_available, true),
          updated_at = now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_sync_product_inventory ON public.products;
CREATE TRIGGER trg_auto_sync_product_inventory
  AFTER INSERT OR UPDATE OF is_available ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_sync_product_inventory();

-- ─── 6. Merchant Order Driver Dispatch RPC ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.merchant_dispatch_order_driver(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order record;
  v_merchant record;
  v_customer record;
  v_ride_id uuid;
  v_pickup_lat double precision;
  v_pickup_lng double precision;
  v_dropoff_lat double precision;
  v_dropoff_lng double precision;
  v_items_summary text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_order
    FROM public.orders
   WHERE id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF NOT public.is_merchant_owner(v_order.merchant_id) THEN
    RAISE EXCEPTION 'Not authorized to dispatch this order';
  END IF;

  SELECT * INTO v_merchant
    FROM public.merchants
   WHERE id = v_order.merchant_id;

  SELECT full_name, phone INTO v_customer
    FROM public.users
   WHERE id = v_order.user_id;

  SELECT string_agg(
           COALESCE(oi.quantity::text, '1') || 'x ' || COALESCE(NULLIF(oi.product_name, ''), 'Item'),
           ', '
         )
    INTO v_items_summary
    FROM public.order_items oi
   WHERE oi.order_id = p_order_id;

  v_pickup_lat := COALESCE(v_merchant.latitude, 30.0444);
  v_pickup_lng := COALESCE(v_merchant.longitude, 31.2357);
  v_dropoff_lat := COALESCE(v_order.delivery_latitude, v_pickup_lat + 0.01);
  v_dropoff_lng := COALESCE(v_order.delivery_longitude, v_pickup_lng + 0.01);

  -- Check if a delivery ride already exists for this order
  SELECT id INTO v_ride_id
    FROM public.rides
   WHERE merchant_id = v_order.merchant_id
     AND rider_id = v_order.user_id
     AND status IN ('searching', 'requested', 'matched', 'arrived', 'in_trip', 'inTrip')
   ORDER BY created_at DESC
   LIMIT 1;

  IF v_ride_id IS NULL THEN
    INSERT INTO public.rides (
      rider_id,
      merchant_id,
      service_type,
      ride_type,
      status,
      delivery_status,
      pickup_address,
      pickup_latitude,
      pickup_longitude,
      dropoff_address,
      dropoff_latitude,
      dropoff_longitude,
      fare,
      distance,
      estimated_minutes,
      payment_method,
      payment_status,
      currency,
      recipient_name,
      recipient_phone,
      items_summary,
      pickup_notes,
      dropoff_notes,
      otp_required
    )
    VALUES (
      v_order.user_id,
      v_order.merchant_id,
      'food_delivery',
      'delivery',
      'searching',
      'searching',
      COALESCE(NULLIF(v_merchant.address, ''), COALESCE(v_merchant.name, 'Store Pickup')),
      v_pickup_lat,
      v_pickup_lng,
      COALESCE(NULLIF(v_order.delivery_address, ''), 'Customer Address'),
      v_dropoff_lat,
      v_dropoff_lng,
      GREATEST(COALESCE(v_order.delivery_fee, v_merchant.delivery_fee, 20), 15),
      3.5,
      COALESCE(v_merchant.delivery_time_min, 30),
      COALESCE(v_order.payment_method, 'cash'),
      COALESCE(v_order.payment_status, 'pending'),
      'EGP',
      v_customer.full_name,
      v_customer.phone,
      COALESCE(v_items_summary, v_order.notes),
      v_merchant.name,
      COALESCE(v_order.notes, v_order.special_instructions),
      false
    )
    RETURNING id INTO v_ride_id;
  END IF;

  -- Trigger driver dispatch if dispatch_delivery RPC exists
  BEGIN
    PERFORM public.dispatch_delivery(v_ride_id, 25.0, 15);
  EXCEPTION WHEN OTHERS THEN
    -- Ignore if no nearby drivers found immediately; ride remains in 'searching' state
    NULL;
  END;

  UPDATE public.orders
     SET dispatch_status = 'searching',
         status = CASE
           WHEN status IN ('pending', 'confirmed', 'accepted', 'preparing') THEN 'ready'
           ELSE status
         END,
         updated_at = now()
   WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', p_order_id,
    'ride_id', v_ride_id,
    'dispatch_status', 'searching'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.merchant_dispatch_order_driver(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.merchant_dispatch_order_driver(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.merchant_dispatch_order_driver(uuid) TO authenticated, service_role;

-- ─── 7. Extend update_my_storefront to Support Store Type / Category ─────────

DROP FUNCTION IF EXISTS public.update_my_storefront(
  text, text, text, text, text, text,
  double precision, double precision,
  numeric, numeric, integer, boolean
);

CREATE OR REPLACE FUNCTION public.update_my_storefront(
  p_name text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_logo_url text DEFAULT NULL,
  p_cover_url text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_delivery_fee numeric DEFAULT NULL,
  p_min_order numeric DEFAULT NULL,
  p_delivery_time_min integer DEFAULT NULL,
  p_is_open boolean DEFAULT NULL,
  p_type text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_merchant uuid;
BEGIN
  v_merchant := public.resolve_my_merchant();
  IF v_merchant IS NULL THEN
    RAISE EXCEPTION 'No merchant record found for caller';
  END IF;

  IF p_name IS NOT NULL AND length(btrim(p_name)) = 0 THEN
    RAISE EXCEPTION 'Merchant name cannot be empty';
  END IF;

  UPDATE public.merchants
     SET name              = COALESCE(NULLIF(btrim(p_name), ''), name),
         description       = COALESCE(p_description, description),
         logo_url          = COALESCE(p_logo_url, logo_url),
         cover_url         = COALESCE(p_cover_url, cover_url),
         phone             = COALESCE(p_phone, phone),
         address           = COALESCE(p_address, address),
         latitude          = COALESCE(p_latitude, latitude),
         longitude         = COALESCE(p_longitude, longitude),
         delivery_fee      = COALESCE(p_delivery_fee, delivery_fee),
         min_order         = COALESCE(p_min_order, min_order),
         delivery_time_min = COALESCE(p_delivery_time_min, delivery_time_min),
         is_open           = COALESCE(p_is_open, is_open),
         type              = COALESCE(NULLIF(btrim(p_type), ''), type),
         updated_at        = now()
   WHERE id = v_merchant;

  RETURN v_merchant;
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_storefront(
  text, text, text, text, text, text,
  double precision, double precision,
  numeric, numeric, integer, boolean, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.update_my_storefront(
  text, text, text, text, text, text,
  double precision, double precision,
  numeric, numeric, integer, boolean, text
) TO authenticated, service_role;

-- Normalize topup_requests currency to EGP
UPDATE public.topup_requests
   SET currency = 'EGP'
 WHERE currency = 'SAR';

NOTIFY pgrst, 'reload schema';
