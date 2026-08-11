-- 027: CONSOLIDATED APPLICATION of pending migrations (017, 023, 024, 025, 026)
-- Generated 2026-08-11 — applied + verified live 2026-08-11
-- Note: 023 admin policies use public.is_admin() (migration 018) — original referenced a nonexistent 'profiles' table.
-- Note: 024 products index uses products.category (live column) — original referenced products.category_id.
-- Note: 002_favorites_merchant_support.sql also applied separately (was never applied live; favorites.merchant_id required by app).

-- >>> 017 username <<<
-- ─────────────────────────────────────────────────────────────
-- 017: Add editable username to users profile
-- Applies to the users table created in 002_complete_schema.sql
-- ─────────────────────────────────────────────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx
  ON users (username)
  WHERE username IS NOT NULL;

-- >>> 023 home services <<<
-- Migration 023: Home Services booking system
-- Creates tables for service categories, providers, and bookings

-- Service categories (plumbing, electrical, carpentry, etc.)
CREATE TABLE IF NOT EXISTS service_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  type TEXT NOT NULL UNIQUE,
  description_ar TEXT,
  description_en TEXT,
  icon_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Service providers (individuals/companies offering services)
CREATE TABLE IF NOT EXISTS service_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category_type TEXT NOT NULL,
  description TEXT,
  profile_image_url TEXT,
  rating NUMERIC(3,2) DEFAULT 0.0,
  rating_count INTEGER DEFAULT 0,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  is_available BOOLEAN NOT NULL DEFAULT true,
  hourly_rate NUMERIC(10,2),
  fixed_price_min NUMERIC(10,2),
  fixed_price_max NUMERIC(10,2),
  city TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ
);

-- Service bookings
CREATE TABLE IF NOT EXISTS service_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES service_providers(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL,
  category_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  description TEXT,
  scheduled_date DATE NOT NULL,
  scheduled_time TEXT NOT NULL,
  address TEXT,
  address_latitude DOUBLE PRECISION,
  address_longitude DOUBLE PRECISION,
  estimated_price NUMERIC(10,2),
  final_price NUMERIC(10,2),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_service_providers_category ON service_providers(category_type);
CREATE INDEX IF NOT EXISTS idx_service_providers_city ON service_providers(city);
CREATE INDEX IF NOT EXISTS idx_service_providers_available ON service_providers(is_available);
CREATE INDEX IF NOT EXISTS idx_service_bookings_user ON service_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_provider ON service_bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_status ON service_bookings(status);
CREATE INDEX IF NOT EXISTS idx_service_bookings_date ON service_bookings(scheduled_date);

-- RLS policies
ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_bookings ENABLE ROW LEVEL SECURITY;

-- Anyone can read active service categories
CREATE POLICY "Public can view active categories"
  ON service_categories FOR SELECT
  USING (is_active = true);

-- Anyone can read available service providers
CREATE POLICY "Public can view available providers"
  ON service_providers FOR SELECT
  USING (is_available = true);

-- Users can read their own bookings
CREATE POLICY "Users can view own bookings"
  ON service_bookings FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own bookings
CREATE POLICY "Users can create own bookings"
  ON service_bookings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own bookings (cancel)
CREATE POLICY "Users can update own bookings"
  ON service_bookings FOR UPDATE
  USING (auth.uid() = user_id);

-- Admin can manage all tables (uses public.is_admin() from migration 018)
CREATE POLICY "Admins can manage categories"
  ON service_categories FOR ALL
  USING (public.is_admin());

CREATE POLICY "Admins can manage providers"
  ON service_providers FOR ALL
  USING (public.is_admin());

CREATE POLICY "Admins can manage bookings"
  ON service_bookings FOR ALL
  USING (public.is_admin());

-- Seed default categories
INSERT INTO service_categories (name_ar, name_en, type, description_ar, description_en) VALUES
  ('سباكة', 'Plumbing', 'plumbing', 'إصلاح التسريبات وتركيب السباكة', 'Fix leaks and install plumbing'),
  ('كهرباء', 'Electrical', 'electrical', 'إصلاح الكهرباء وتوصيل الأسلاك', 'Electrical repairs and wiring'),
  ('نجارة', 'Carpentry', 'carpentry', 'تركيب الأثاث والإصلاحات الخشبية', 'Furniture assembly and wood repairs'),
  ('صيانة تكييف', 'AC Maintenance', 'acMaintenance', 'تنظيف وصيانة وحدات التكييف', 'AC cleaning and maintenance'),
  ('دهان', 'Painting', 'painting', 'طلاء الجدران والأسقف', 'Wall and ceiling painting'),
  ('تنظيف', 'Cleaning', 'cleaning', 'تنظيف المنازل والمكاتب', 'Home and office cleaning'),
  ('مكافحة حشرات', 'Pest Control', 'pestControl', 'إبادة الحشرات والقوارض', 'Insect and pest extermination'),
  ('إصلاح أجهزة', 'Appliance Repair', 'applianceRepair', 'إصلاح الأجهزة المنزلية', 'Home appliance repair')
ON CONFLICT (type) DO NOTHING;

-- >>> 024 payment infrastructure <<<
-- Sprint 67: Payment infrastructure + database hardening indexes
-- Migration 024

-- 1. Add payment tracking columns to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) DEFAULT 'unpaid';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_id VARCHAR(255);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS transaction_id VARCHAR(255);

-- 2. Create payment_transactions table for audit trail
CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  provider VARCHAR(50) NOT NULL DEFAULT 'paymob',
  provider_order_id INTEGER,
  payment_key VARCHAR(255),
  amount_cents INTEGER NOT NULL,
  currency VARCHAR(10) NOT NULL DEFAULT 'EGP',
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  error_code VARCHAR(100),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Add indexes for orders table performance
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_merchant_id ON orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status);

-- 4. Add indexes for payment_transactions
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order_id ON payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);

-- 5. Add indexes for products (common queries)
CREATE INDEX IF NOT EXISTS idx_products_merchant_id ON products(merchant_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_available ON products(is_available);

-- 6. Add indexes for reviews
CREATE INDEX IF NOT EXISTS idx_reviews_merchant_id ON reviews(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);

-- 7. Add indexes for favorites
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_merchant_id ON favorites(merchant_id);

-- 8. RLS policies for payment_transactions
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

-- Users can read their own transactions
CREATE POLICY "Users can view own transactions"
  ON payment_transactions FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert/update (for webhook)
CREATE POLICY "Service role can manage transactions"
  ON payment_transactions FOR ALL
  USING (auth.role() = 'service_role');

-- 9. Index for service_bookings (already in migration 023 but ensuring)
CREATE INDEX IF NOT EXISTS idx_service_bookings_user_id ON service_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_provider_id ON service_bookings(provider_id);

-- 10. Updated_at trigger for payment_transactions
CREATE OR REPLACE FUNCTION update_payment_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_payment_transactions_updated_at ON payment_transactions;
CREATE TRIGGER update_payment_transactions_updated_at
  BEFORE UPDATE ON payment_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_payment_transactions_updated_at();

-- >>> 025 category management <<<
-- Sprint 68: Category management + Home UX improvements
-- Migration 025

-- 1. Add name_en column to categories
ALTER TABLE categories ADD COLUMN IF NOT EXISTS name_en TEXT;

-- 2. Update existing categories with English names
UPDATE categories SET name_en = 'Food' WHERE name_ar = 'طعام';
UPDATE categories SET name_en = 'Grocery' WHERE name_ar = 'بقالة';
UPDATE categories SET name_en = 'Pharmacy' WHERE name_ar = 'صيدلية';
UPDATE categories SET name_en = 'Electronics' WHERE name_ar = 'إلكترونيات';
UPDATE categories SET name_en = 'Furniture' WHERE name_ar = 'أثاث';
UPDATE categories SET name_en = 'Fashion' WHERE name_ar = 'أزياء';
UPDATE categories SET name_en = 'Flowers' WHERE name_ar = 'زهور';
UPDATE categories SET name_en = 'Bakery' WHERE name_ar = 'مخبوزات';

-- 3. Create storage bucket for category images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('category-images', 'category-images', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

-- 4. RLS policies for category images storage
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Category images public read'
    AND tablename = 'objects' AND schemaname = 'storage'
  ) THEN
    EXECUTE 'CREATE POLICY "Category images public read" ON storage.objects
      FOR SELECT USING (bucket_id = ''category-images'')';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Category images admin upload'
    AND tablename = 'objects' AND schemaname = 'storage'
  ) THEN
    EXECUTE 'CREATE POLICY "Category images admin upload" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = ''category-images'' AND auth.role() = ''service_role'')';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Category images admin delete'
    AND tablename = 'objects' AND schemaname = 'storage'
  ) THEN
    EXECUTE 'CREATE POLICY "Category images admin delete" ON storage.objects
      FOR DELETE USING (bucket_id = ''category-images'' AND auth.role() = ''service_role'')';
  END IF;
END $body$;

-- 5. Admin write policies for categories table
DO $body$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Admins can manage categories'
    AND tablename = 'categories'
  ) THEN
    EXECUTE 'CREATE POLICY "Admins can manage categories" ON categories
      FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = ''admin'')
      )';
  END IF;
END $body$;

-- >>> 026 production notifications <<<
-- Sprint 69: Production Notification System
-- Enhances notifications table + device tokens + idempotency

-- 1. Add missing columns to notifications
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deep_link TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Unique index for idempotency (only non-null keys enforced)
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency_key
  ON notifications(idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 2. Enhance notification_tokens for multi-device
ALTER TABLE notification_tokens
  ADD COLUMN IF NOT EXISTS device_id TEXT,
  ADD COLUMN IF NOT EXISTS app_version TEXT,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

-- Index for active token lookups (push sending)
CREATE INDEX IF NOT EXISTS idx_notification_tokens_active
  ON notification_tokens(user_id, is_active)
  WHERE is_active = true;

-- Index for stale token cleanup
CREATE INDEX IF NOT EXISTS idx_notification_tokens_last_seen
  ON notification_tokens(last_seen_at);

-- 3. Performance indexes
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read
  ON notifications(user_id, is_read, created_at DESC);

-- 4. RLS policies (extend existing)
-- Users can only update their own read state
DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
CREATE POLICY "Users update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own notifications
DROP POLICY IF EXISTS "Users delete own notifications" ON notifications;
CREATE POLICY "Users delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);

-- Users can read own notifications
DROP POLICY IF EXISTS "Users read own notifications" ON notifications;
CREATE POLICY "Users read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert (backend push)
DROP POLICY IF EXISTS "Service role insert notifications" ON notifications;
CREATE POLICY "Service role insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

-- Admins can read all notifications
DROP POLICY IF EXISTS "Admins read all notifications" ON notifications;
CREATE POLICY "Admins read all notifications"
  ON notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- 5. Device tokens RLS
DROP POLICY IF EXISTS "Users manage own tokens" ON notification_tokens;
CREATE POLICY "Users manage own tokens"
  ON notification_tokens FOR ALL
  USING (auth.uid() = user_id);

-- Admins can read all tokens
DROP POLICY IF EXISTS "Admins read all tokens" ON notification_tokens;
CREATE POLICY "Admins read all tokens"
  ON notification_tokens FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid() AND users.role = 'admin'
    )
  );

-- Service role full access to tokens
DROP POLICY IF EXISTS "Service role manage tokens" ON notification_tokens;
CREATE POLICY "Service role manage tokens"
  ON notification_tokens FOR ALL
  USING (true);

-- 6. Function to mark stale tokens inactive (called by edge function cron)
CREATE OR REPLACE FUNCTION deactivate_stale_tokens(stale_interval INTERVAL DEFAULT INTERVAL '30 days')
RETURNS INTEGER AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE notification_tokens
  SET is_active = false
  WHERE is_active = true
    AND last_seen_at < NOW() - stale_interval;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Function to increment unread count efficiently
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  cnt INTEGER;
BEGIN
  SELECT COUNT(*) INTO cnt
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;
  RETURN COALESCE(cnt, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
