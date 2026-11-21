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
