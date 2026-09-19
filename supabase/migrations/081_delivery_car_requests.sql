-- 081_delivery_car_requests.sql
-- "طلب سيارة توصيل" (delivery car request): a customer requests a delivery
-- car; the request goes to the region's admin (region scope) and appears to
-- the owner for tracking (pending → reviewing → approved/rejected → completed).

CREATE TABLE IF NOT EXISTS delivery_car_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  region_id UUID REFERENCES regions(id) ON DELETE SET NULL,
  pickup_address TEXT NOT NULL,
  dropoff_address TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  phone TEXT NOT NULL,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','reviewing','approved','rejected','completed','cancelled')),
  admin_note TEXT,
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_car_req_user ON delivery_car_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_delivery_car_req_region ON delivery_car_requests(region_id);
CREATE INDEX IF NOT EXISTS idx_delivery_car_req_status ON delivery_car_requests(status);

ALTER TABLE delivery_car_requests ENABLE ROW LEVEL SECURITY;

-- Customers can create their own requests
CREATE POLICY "Users create own delivery car requests"
  ON delivery_car_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Customers can view their own requests
CREATE POLICY "Users view own delivery car requests"
  ON delivery_car_requests FOR SELECT
  USING (auth.uid() = user_id);

-- Customers can cancel their own pending requests
CREATE POLICY "Users cancel own delivery car requests"
  ON delivery_car_requests FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND status = 'cancelled');

-- Admins/owners can view + manage requests (region scoped handled in-app)
CREATE POLICY "Admins manage delivery car requests"
  ON delivery_car_requests FOR ALL
  USING (public.is_admin());

-- The delivery car request appears in the home-services list.
INSERT INTO service_categories (name_ar, name_en, type, description_ar, description_en) VALUES
  ('طلب سيارة توصيل', 'Delivery Car', 'deliveryCar', 'اطلب سيارة توصيل لطلباتك ومشاويرك — يصل الطلب لإدارة منطقتك للمراجعة', 'Request a delivery car for your orders and errands — sent to your region admin for review')
ON CONFLICT (type) DO NOTHING;