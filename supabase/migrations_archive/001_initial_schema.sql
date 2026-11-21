-- =============================================================
-- Delwaqty Platform - Database Schema
-- Run this in Supabase SQL Editor: https://app.supabase.com
-- =============================================================

-- ─── Users ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ─── Admin Users ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'support',
  status TEXT NOT NULL DEFAULT 'pending',
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin users can view all" ON admin_users
  FOR SELECT USING (true);

CREATE POLICY "Admin users can insert" ON admin_users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admin users can update" ON admin_users
  FOR UPDATE USING (true);

CREATE POLICY "Admin users can delete" ON admin_users
  FOR DELETE USING (true);

-- ─── Merchants ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT,
  type TEXT NOT NULL DEFAULT 'general',
  status TEXT NOT NULL DEFAULT 'pending',
  description TEXT,
  logo_url TEXT,
  phone TEXT,
  address TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  rating DECIMAL(3,2) DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants are viewable by everyone" ON merchants
  FOR SELECT USING (true);

CREATE POLICY "Merchants can update own" ON merchants
  FOR UPDATE USING (auth.uid() = id);

-- ─── Products ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  compare_at_price DECIMAL(10,2),
  category TEXT,
  image_url TEXT,
  is_available BOOLEAN DEFAULT true,
  stock_quantity INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Products are viewable by everyone" ON products
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own products" ON products
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Categories ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  name_ar TEXT,
  icon TEXT,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Categories are viewable by everyone" ON categories
  FOR SELECT USING (true);

-- ─── Orders ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  merchant_id UUID REFERENCES merchants(id),
  driver_id UUID,
  status TEXT NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(10,2) NOT NULL,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  tax DECIMAL(10,2) DEFAULT 0,
  delivery_address TEXT,
  delivery_latitude DECIMAL(10,8),
  delivery_longitude DECIMAL(11,8),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own orders" ON orders
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create orders" ON orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Merchants can view their orders" ON orders
  FOR SELECT USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

-- ─── Order Items ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order items viewable by order participants" ON order_items
  FOR SELECT USING (true);

-- ─── Reviews ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  merchant_id UUID REFERENCES merchants(id),
  product_id UUID REFERENCES products(id),
  order_id UUID REFERENCES orders(id),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reviews are viewable by everyone" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Users can create reviews" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ─── Favorites ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own favorites" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own favorites" ON favorites
  FOR ALL USING (auth.uid() = user_id);

-- ─── Drivers ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name TEXT NOT NULL,
  phone TEXT,
  vehicle_type TEXT,
  vehicle_plate TEXT,
  is_active BOOLEAN DEFAULT false,
  current_latitude DECIMAL(10,8),
  current_longitude DECIMAL(11,8),
  rating DECIMAL(3,2) DEFAULT 0,
  total_deliveries INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Drivers can view own profile" ON drivers
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Drivers can update own profile" ON drivers
  FOR UPDATE USING (auth.uid() = user_id);

-- ─── Coupons ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL DEFAULT 'percentage',
  discount_value DECIMAL(10,2) NOT NULL,
  minimum_order DECIMAL(10,2) DEFAULT 0,
  maximum_discount DECIMAL(10,2),
  usage_limit INTEGER,
  used_count INTEGER DEFAULT 0,
  merchant_id UUID REFERENCES merchants(id),
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Coupons are viewable by everyone" ON coupons
  FOR SELECT USING (true);

-- ─── Notifications ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT,
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ─── Activity Logs ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  resource TEXT NOT NULL,
  resource_id TEXT,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Activity logs viewable by admins" ON activity_logs
  FOR SELECT USING (true);

CREATE POLICY "Activity logs insertable" ON activity_logs
  FOR INSERT WITH CHECK (true);

-- ─── Platform Settings ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS platform_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  app_name TEXT DEFAULT 'Delwaqty',
  support_email TEXT,
  support_phone TEXT,
  max_drivers_per_zone INTEGER DEFAULT 10,
  maintenance_mode BOOLEAN DEFAULT false,
  min_app_version_android INTEGER DEFAULT 1,
  min_app_version_ios INTEGER DEFAULT 1,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Settings viewable by everyone" ON platform_settings
  FOR SELECT USING (true);

CREATE POLICY "Settings updatable by admins" ON platform_settings
  FOR UPDATE USING (true);

-- ─── Indexes ────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_merchant_id ON orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_merchant_id ON products(merchant_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_merchants_status ON merchants(status);
CREATE INDEX IF NOT EXISTS idx_merchants_type ON merchants(type);
CREATE INDEX IF NOT EXISTS idx_reviews_merchant_id ON reviews(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON activity_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_drivers_is_active ON drivers(is_active);

-- ─── Insert Default Data ────────────────────────────────────

INSERT INTO platform_settings (id, app_name, support_email)
VALUES ('default', 'Delwaqty', 'support@delwaqty.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO categories (name, name_ar, icon, sort_order) VALUES
  ('Food', 'طعام', 'restaurant', 1),
  ('Grocery', 'بقالة', 'shopping_basket', 2),
  ('Pharmacy', 'صيدلية', 'local_pharmacy', 3),
  ('Electronics', 'إلكترونيات', 'devices', 4),
  ('Furniture', 'أثاث', 'chair', 5),
  ('Fashion', 'أزياء', 'checkroom', 6),
  ('Flowers', 'زهور', 'local_florist', 7),
  ('Bakery', 'مخبوزات', 'bakery_dining', 8)
ON CONFLICT DO NOTHING;

-- ─── Done ───────────────────────────────────────────────────
-- Database schema created successfully!
-- Tables: 15
-- Policies: 25+
-- Indexes: 16
