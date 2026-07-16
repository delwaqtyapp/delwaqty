-- Restaurant Plugin - Database Schema
-- Adds restaurant-specific tables to the existing commerce schema

-- ─── Branches ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  address TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Branches are viewable by everyone" ON branches
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own branches" ON branches
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Working Hours ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS working_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  open_time TIME NOT NULL,
  close_time TIME NOT NULL,
  is_closed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE working_hours ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Working hours viewable by everyone" ON working_hours
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own hours" ON working_hours
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

CREATE UNIQUE INDEX idx_working_hours_merchant_day ON working_hours(merchant_id, day_of_week);
CREATE UNIQUE INDEX idx_working_hours_branch_day ON working_hours(branch_id, day_of_week) WHERE branch_id IS NOT NULL;

-- ─── Delivery Zones ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS delivery_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  radius_km DECIMAL(5,2) NOT NULL,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  minimum_order DECIMAL(10,2) DEFAULT 0,
  estimated_minutes INTEGER DEFAULT 30,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Delivery zones viewable by everyone" ON delivery_zones
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own zones" ON delivery_zones
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Menu Categories (per merchant) ──────────────────────
-- Using existing catalog_categories table for this

-- ─── Product Modifiers ────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price_adjustment DECIMAL(10,2) DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE product_modifiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Modifiers viewable by everyone" ON product_modifiers
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own modifiers" ON product_modifiers
  FOR ALL USING (product_id IN (
    SELECT id FROM products WHERE merchant_id IN (
      SELECT id FROM merchants WHERE id = merchant_id
    )
  ));

-- ─── Product Dietary Info ─────────────────────────────────
ALTER TABLE products ADD COLUMN IF NOT EXISTS dietary_info JSONB DEFAULT '[]';
ALTER TABLE products ADD COLUMN IF NOT EXISTS prep_time_minutes INTEGER DEFAULT 15;
ALTER TABLE products ADD COLUMN IF NOT EXISTS calories INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS spice_level INTEGER CHECK (spice_level >= 0 AND spice_level <= 5);

-- ─── Restaurant Settings ──────────────────────────────────
CREATE TABLE IF NOT EXISTS restaurant_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE UNIQUE,
  accepts_reservations BOOLEAN DEFAULT false,
  has_dine_in BOOLEAN DEFAULT true,
  has_takeaway BOOLEAN DEFAULT true,
  has_delivery BOOLEAN DEFAULT true,
  average_prep_time INTEGER DEFAULT 15,
  max_orders_per_hour INTEGER DEFAULT 20,
  auto_accept_orders BOOLEAN DEFAULT false,
  printer_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE restaurant_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Restaurant settings viewable by everyone" ON restaurant_settings
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own settings" ON restaurant_settings
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Offers ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL DEFAULT 'percentage',
  discount_value DECIMAL(10,2) NOT NULL,
  minimum_order DECIMAL(10,2) DEFAULT 0,
  maximum_discount DECIMAL(10,2),
  product_ids JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Offers viewable by everyone" ON offers
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own offers" ON offers
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Reservations ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  merchant_id UUID REFERENCES merchants(id),
  branch_id UUID REFERENCES branches(id),
  party_size INTEGER NOT NULL,
  reservation_time TIMESTAMPTZ NOT NULL,
  special_requests TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reservations" ON reservations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create reservations" ON reservations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Merchants can view their reservations" ON reservations
  FOR SELECT USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

CREATE POLICY "Merchants can update their reservations" ON reservations
  FOR UPDATE USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Order Tracking ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  estimated_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order tracking viewable by order participants" ON order_tracking
  FOR SELECT USING (true);

CREATE POLICY "Merchants can add tracking updates" ON order_tracking
  FOR INSERT WITH CHECK (true);
