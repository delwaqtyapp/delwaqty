-- 083_car_marketplace.sql
-- "متجر السيارات": سائق مسجل بسيارته = منتج سياره معروض للحركة/المشاوير.
-- السعر يحدده السائق (وليس جوجل). المنصه تاخد عموله 7% على كل طلب.

CREATE TABLE IF NOT EXISTS car_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- مالك السيارة (سائق/مزود)
  driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
  merchant_id UUID REFERENCES merchants(id) ON DELETE SET NULL,
  category TEXT NOT NULL DEFAULT 'car' CHECK (category IN ('car','van','pickup','microbus','tuk_tuk')),
  make TEXT,
  model TEXT,
  year INT,
  color TEXT,
  seats INT NOT NULL DEFAULT 4,
  photo_url TEXT,
  city TEXT NOT NULL,
  region_id UUID REFERENCES regions(id) ON DELETE SET NULL,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,  -- سعر السائق
  description TEXT,
  is_available BOOLEAN NOT NULL DEFAULT true,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_car_products_city ON car_products(city);
CREATE INDEX IF NOT EXISTS idx_car_products_category ON car_products(category);
CREATE INDEX IF NOT EXISTS idx_car_products_available ON car_products(is_available);

ALTER TABLE car_products ENABLE ROW LEVEL SECURITY;

-- قراءة عامة للمنتجات المتاحه
CREATE POLICY "Anyone reads available car products" ON car_products
  FOR SELECT USING (is_available = true OR auth.uid() = seller_id OR public.is_admin());

-- البائع (او الادمن) يضيف/يحدث منتجه
CREATE POLICY "Seller inserts own car product" ON car_products
  FOR INSERT WITH CHECK (auth.uid() = seller_id OR public.is_admin());

CREATE POLICY "Seller updates own car product" ON car_products
  FOR UPDATE USING (auth.uid() = seller_id OR public.is_admin());

-- ربط طلب السيارة بمنتج المتجر: عمود جديد في delivery_car_requests
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS car_product_id UUID REFERENCES car_products(id) ON DELETE SET NULL;
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS driver_price NUMERIC(10,2);
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS commission_percent NUMERIC(5,2) NOT NULL DEFAULT 7.00;
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10,2);
ALTER TABLE delivery_car_requests ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10,2);

-- بيانات تجريبيه: 6 سيارات في مدن مصرية (صور picsum عامه)
INSERT INTO car_products (seller_id, category, make, model, year, color, seats, photo_url, city, price, description, is_available, is_verified) VALUES
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'car', 'Toyota', 'Corolla', 2020, 'فضي', 4, 'https://picsum.photos/seed/car1/600/400', 'القاهرة', 250, 'سيارة مريحة للمشاوير داخل المدينة', true, true),
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'van', 'Hyundai', 'H1', 2019, 'أبيض', 7, 'https://picsum.photos/seed/van1/600/400', 'الجيزة', 350, 'فان عائلي يتسع 7 ركاب', true, true),
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'pickup', 'Isuzu', 'D-Max', 2018, 'أسود', 3, 'https://picsum.photos/seed/pickup1/600/400', 'الإسكندرية', 300, 'بيك أب لنقل الأغراض والمشاوير', true, true),
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'microbus', 'Toyota', 'Hiace', 2017, 'أزرق', 12, 'https://picsum.photos/seed/bus1/600/400', 'المنصورة', 400, 'ميكروباص للجماعات والمشاوير الكبيرة', true, false),
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'car', 'Kia', 'Cerato', 2021, 'أحمر', 4, 'https://picsum.photos/seed/car2/600/400', 'طنطا', 220, 'سيارة صغيرة اقتصادية', true, true),
  ( (SELECT id FROM users WHERE role='owner' LIMIT 1), 'tuk_tuk', 'Bajaj', 'RE', 2020, 'أخضر', 3, 'https://picsum.photos/seed/tuk1/600/400', 'أسيوط', 80, 'توك توك للمشاوير القصيرة', true, true)
ON CONFLICT DO NOTHING;