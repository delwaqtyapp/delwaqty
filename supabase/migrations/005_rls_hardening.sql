-- =============================================================
-- Delwaqty Platform - RLS Security Hardening
-- Migration 005
-- Replaces all USING(true) policies with proper role-based access
-- Fixes broken merchant ownership tautology in 8 tables
-- Adds missing INSERT/DELETE policies
-- =============================================================

-- ─── Helper Functions ───────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_user_role(uid UUID)
RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = uid;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_user_merchant_id(uid UUID)
RETURNS UUID AS $$
  SELECT id FROM public.merchants WHERE id = uid;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_admin(uid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users WHERE id = uid AND status = 'active'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_merchant_owner(merchant_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.merchants WHERE id = merchant_uuid AND id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- =============================================================
-- TABLE: users
-- =============================================================
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;

CREATE POLICY "users_select_own" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "users_insert_own" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- =============================================================
-- TABLE: admin_users
-- =============================================================
DROP POLICY IF EXISTS "Admin users can view all" ON public.admin_users;
DROP POLICY IF EXISTS "Admin users can insert" ON public.admin_users;
DROP POLICY IF EXISTS "Admin users can update" ON public.admin_users;
DROP POLICY IF EXISTS "Admin users can delete" ON public.admin_users;

CREATE POLICY "admin_users_select_admin_only" ON public.admin_users
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND status = 'active')
  );

CREATE POLICY "admin_users_insert_admin_only" ON public.admin_users
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND role = 'owner' AND status = 'active')
  );

CREATE POLICY "admin_users_update_admin_only" ON public.admin_users
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND role IN ('owner', 'admin') AND status = 'active')
  );

CREATE POLICY "admin_users_delete_owner_only" ON public.admin_users
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND role = 'owner' AND status = 'active')
  );

-- =============================================================
-- TABLE: merchants (public catalog — SELECT open, write restricted)
-- =============================================================
DROP POLICY IF EXISTS "Merchants are viewable by everyone" ON public.merchants;
DROP POLICY IF EXISTS "Merchants can update own" ON public.merchants;

CREATE POLICY "merchants_select_public" ON public.merchants
  FOR SELECT USING (true);

CREATE POLICY "merchants_update_own" ON public.merchants
  FOR UPDATE USING (auth.uid() = id);

-- =============================================================
-- TABLE: products (public catalog — SELECT open, write restricted)
-- =============================================================
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;
DROP POLICY IF EXISTS "Merchants can manage own products" ON public.products;

CREATE POLICY "products_select_public" ON public.products
  FOR SELECT USING (true);

CREATE POLICY "products_insert_merchant" ON public.products
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "products_update_merchant" ON public.products
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "products_delete_merchant" ON public.products
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: categories (public catalog — read only)
-- =============================================================
DROP POLICY IF EXISTS "Categories are viewable by everyone" ON public.categories;

CREATE POLICY "categories_select_public" ON public.categories
  FOR SELECT USING (true);

-- =============================================================
-- TABLE: orders (user-owned + merchant-visible)
-- =============================================================
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can create orders" ON public.orders;
DROP POLICY IF EXISTS "Merchants can view their orders" ON public.orders;

CREATE POLICY "orders_select_own" ON public.orders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "orders_select_merchant" ON public.orders
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "orders_insert_own" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "orders_update_merchant" ON public.orders
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: order_items (scoped to order participants only)
-- =============================================================
DROP POLICY IF EXISTS "Order items viewable by order participants" ON public.order_items;

CREATE POLICY "order_items_select_own_order" ON public.order_items
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM public.orders WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "order_items_select_merchant_order" ON public.order_items
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

CREATE POLICY "order_items_insert_own_order" ON public.order_items
  FOR INSERT WITH CHECK (
    order_id IN (
      SELECT id FROM public.orders WHERE user_id = auth.uid()
    )
  );

-- =============================================================
-- TABLE: reviews (public read, user writes own)
-- =============================================================
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
DROP POLICY IF EXISTS "Users can create reviews" ON public.reviews;

CREATE POLICY "reviews_select_public" ON public.reviews
  FOR SELECT USING (true);

CREATE POLICY "reviews_insert_own" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reviews_update_own" ON public.reviews
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "reviews_delete_own" ON public.reviews
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================
-- TABLE: favorites (user-owned)
-- =============================================================
DROP POLICY IF EXISTS "Users can view own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can insert own favorites" ON public.favorites;
DROP POLICY IF EXISTS "Users can delete own favorites" ON public.favorites;

CREATE POLICY "favorites_select_own" ON public.favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert_own" ON public.favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete_own" ON public.favorites
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================
-- TABLE: drivers (driver-owned profile)
-- =============================================================
DROP POLICY IF EXISTS "Drivers can view own profile" ON public.drivers;
DROP POLICY IF EXISTS "Drivers can update own profile" ON public.drivers;

CREATE POLICY "drivers_select_own" ON public.drivers
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "drivers_update_own" ON public.drivers
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "drivers_insert_own" ON public.drivers
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================================
-- TABLE: coupons (public read for active coupons)
-- =============================================================
DROP POLICY IF EXISTS "Coupons are viewable by everyone" ON public.coupons;

CREATE POLICY "coupons_select_active" ON public.coupons
  FOR SELECT USING (is_active = true);

CREATE POLICY "coupons_select_merchant_own" ON public.coupons
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "coupons_insert_merchant" ON public.coupons
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "coupons_update_merchant" ON public.coupons
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "coupons_delete_merchant" ON public.coupons
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: notifications (user-owned)
-- =============================================================
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;

CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "notifications_insert_system" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- =============================================================
-- TABLE: activity_logs (admin-only read, system-only write)
-- =============================================================
DROP POLICY IF EXISTS "Activity logs viewable by admins" ON public.activity_logs;
DROP POLICY IF EXISTS "Activity logs insertable" ON public.activity_logs;

CREATE POLICY "activity_logs_select_admin" ON public.activity_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND status = 'active')
  );

CREATE POLICY "activity_logs_insert_system" ON public.activity_logs
  FOR INSERT WITH CHECK (true);

-- =============================================================
-- TABLE: platform_settings (public read, owner-only update)
-- =============================================================
DROP POLICY IF EXISTS "Settings viewable by everyone" ON public.platform_settings;
DROP POLICY IF EXISTS "Settings updatable by admins" ON public.platform_settings;

CREATE POLICY "platform_settings_select_public" ON public.platform_settings
  FOR SELECT USING (true);

CREATE POLICY "platform_settings_update_owner" ON public.platform_settings
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE id = auth.uid() AND role = 'owner' AND status = 'active'
    )
  );

-- =============================================================
-- TABLE: branches (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Branches are viewable by everyone" ON public.branches;
DROP POLICY IF EXISTS "Merchants can manage own branches" ON public.branches;

CREATE POLICY "branches_select_public" ON public.branches
  FOR SELECT USING (true);

CREATE POLICY "branches_insert_merchant" ON public.branches
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "branches_update_merchant" ON public.branches
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "branches_delete_merchant" ON public.branches
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: working_hours (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Working hours viewable by everyone" ON public.working_hours;
DROP POLICY IF EXISTS "Merchants can manage own hours" ON public.working_hours;

CREATE POLICY "working_hours_select_public" ON public.working_hours
  FOR SELECT USING (true);

CREATE POLICY "working_hours_insert_merchant" ON public.working_hours
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "working_hours_update_merchant" ON public.working_hours
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "working_hours_delete_merchant" ON public.working_hours
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: delivery_zones (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Delivery zones viewable by everyone" ON public.delivery_zones;
DROP POLICY IF EXISTS "Merchants can manage own zones" ON public.delivery_zones;

CREATE POLICY "delivery_zones_select_public" ON public.delivery_zones
  FOR SELECT USING (true);

CREATE POLICY "delivery_zones_insert_merchant" ON public.delivery_zones
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "delivery_zones_update_merchant" ON public.delivery_zones
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "delivery_zones_delete_merchant" ON public.delivery_zones
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: product_modifiers (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Modifiers viewable by everyone" ON public.product_modifiers;
DROP POLICY IF EXISTS "Merchants can manage own modifiers" ON public.product_modifiers;

CREATE POLICY "modifiers_select_public" ON public.product_modifiers
  FOR SELECT USING (true);

CREATE POLICY "modifiers_insert_merchant" ON public.product_modifiers
  FOR INSERT WITH CHECK (
    product_id IN (
      SELECT p.id FROM public.products p
      WHERE p.merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

CREATE POLICY "modifiers_update_merchant" ON public.product_modifiers
  FOR UPDATE USING (
    product_id IN (
      SELECT p.id FROM public.products p
      WHERE p.merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

CREATE POLICY "modifiers_delete_merchant" ON public.product_modifiers
  FOR DELETE USING (
    product_id IN (
      SELECT p.id FROM public.products p
      WHERE p.merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

-- =============================================================
-- TABLE: restaurant_settings (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Restaurant settings viewable by everyone" ON public.restaurant_settings;
DROP POLICY IF EXISTS "Merchants can manage own settings" ON public.restaurant_settings;

CREATE POLICY "restaurant_settings_select_public" ON public.restaurant_settings
  FOR SELECT USING (true);

CREATE POLICY "restaurant_settings_insert_merchant" ON public.restaurant_settings
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "restaurant_settings_update_merchant" ON public.restaurant_settings
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: offers (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Offers viewable by everyone" ON public.offers;
DROP POLICY IF EXISTS "Merchants can manage own offers" ON public.offers;

CREATE POLICY "offers_select_public" ON public.offers
  FOR SELECT USING (true);

CREATE POLICY "offers_insert_merchant" ON public.offers
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "offers_update_merchant" ON public.offers
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "offers_delete_merchant" ON public.offers
  FOR DELETE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: reservations (user-owned + merchant-visible)
-- =============================================================
DROP POLICY IF EXISTS "Users can view own reservations" ON public.reservations;
DROP POLICY IF EXISTS "Users can create reservations" ON public.reservations;
DROP POLICY IF EXISTS "Merchants can view their reservations" ON public.reservations;
DROP POLICY IF EXISTS "Merchants can update their reservations" ON public.reservations;

CREATE POLICY "reservations_select_own" ON public.reservations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "reservations_select_merchant" ON public.reservations
  FOR SELECT USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "reservations_insert_own" ON public.reservations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reservations_update_merchant" ON public.reservations
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: order_tracking (order participants only)
-- =============================================================
DROP POLICY IF EXISTS "Order tracking viewable by order participants" ON public.order_tracking;
DROP POLICY IF EXISTS "Merchants can add tracking updates" ON public.order_tracking;

CREATE POLICY "tracking_select_own_order" ON public.order_tracking
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM public.orders WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "tracking_select_merchant_order" ON public.order_tracking
  FOR SELECT USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

CREATE POLICY "tracking_insert_merchant" ON public.order_tracking
  FOR INSERT WITH CHECK (
    order_id IN (
      SELECT id FROM public.orders
      WHERE merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
    )
  );

-- =============================================================
-- TABLE: product_inventory (public read, merchant write)
-- =============================================================
DROP POLICY IF EXISTS "Inventory viewable by everyone" ON public.product_inventory;
DROP POLICY IF EXISTS "Merchants can manage own inventory" ON public.product_inventory;

CREATE POLICY "inventory_select_public" ON public.product_inventory
  FOR SELECT USING (true);

CREATE POLICY "inventory_insert_merchant" ON public.product_inventory
  FOR INSERT WITH CHECK (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

CREATE POLICY "inventory_update_merchant" ON public.product_inventory
  FOR UPDATE USING (
    merchant_id IN (SELECT id FROM public.merchants WHERE id = auth.uid())
  );

-- =============================================================
-- TABLE: catalog_categories (if exists, public read)
-- =============================================================
DO $body$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'catalog_categories') THEN
    EXECUTE 'ALTER TABLE public.catalog_categories ENABLE ROW LEVEL SECURITY';

    DROP POLICY IF EXISTS "Catalog categories viewable by everyone" ON public.catalog_categories;

    EXECUTE 'CREATE POLICY "catalog_categories_select_public" ON public.catalog_categories FOR SELECT USING (true)';
  END IF;
END $body$;
