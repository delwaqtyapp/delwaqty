-- =============================================================
-- Delwaqty Platform - Seed Data for Testing
-- Run AFTER 002_complete_schema.sql
-- =============================================================

-- ─── Sample Merchants ────────────────────────────────────────

INSERT INTO merchants (id, name, type, status, description, logo_url, cover_url, phone, address, latitude, longitude, rating, total_reviews, delivery_fee, min_order, delivery_time_min, is_featured) VALUES

-- Food
('a1b2c3d4-0001-0001-0001-000000000001', 'برجر كينج', 'food', 'active',
 'برجر الذوق الأصيل — وجبات شهية في دقائق', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/Burger_King_2020.svg/800px-Burger_King_2020.svg.png', NULL,
 '+966500000001', 'طريق الملك عبدالعزيز، الرياض', 24.7136, 46.6753, 4.50, 312, 5.00, 25.00, 25, true),

('a1b2c3d4-0002-0002-0002-000000000002', 'كنتاكي KFC', 'food', 'active',
 'دجاج مقرمش بوصفة سرية منذ 1952', 'https://upload.wikimedia.org/wikipedia/en/thumb/b/bf/KFC_logo.svg/800px-KFC_logo.svg.png', NULL,
 '+966500000002', 'طريق الأمير محمد بن عبدالعزيز، الرياض', 24.7200, 46.6900, 4.30, 225, 4.00, 20.00, 20, true),

('a1b2c3d4-0003-0003-0003-000000000003', 'مطعم البيك', 'food', 'active',
 'الفراخ المقرمشة الأشهر في السعودية', 'https://upload.wikimedia.org/wikipedia/ar/thumb/d/d8/Al-Baik_Logo.svg/800px-Al-Baik_Logo.svg.png', NULL,
 '+966500000003', 'شارع التحلية، جدة', 21.5433, 39.1728, 4.80, 589, 0.00, 15.00, 15, true),

('a1b2c3d4-0004-0004-0004-000000000004', 'بيتزا هت', 'food', 'active',
 'بيتزا إيطالية أصيلة تُسلَّم ساخنة', NULL, NULL,
 '+966500000004', 'طريق الملك فهد، الرياض', 24.6877, 46.7219, 4.20, 178, 6.00, 30.00, 30, false),

('a1b2c3d4-0005-0005-0005-000000000005', 'ماكدونالدز', 'food', 'active',
 'من أكثر سلاسل الوجبات السريعة انتشاراً في العالم', NULL, NULL,
 '+966500000005', 'مول الرياض، الرياض', 24.6980, 46.6750, 4.00, 410, 3.00, 15.00, 20, false),

-- Grocery
('a1b2c3d4-0006-0006-0006-000000000006', 'بنده للتسوق', 'grocery', 'active',
 'كل احتياجاتك المنزلية بأسعار تنافسية', NULL, NULL,
 '+966500000006', 'العليا، الرياض', 24.7150, 46.6830, 4.10, 98, 8.00, 50.00, 45, false),

('a1b2c3d4-0007-0007-0007-000000000007', 'كارفور', 'grocery', 'active',
 'تسوق ذكي، توفير حقيقي', NULL, NULL,
 '+966500000007', 'طريق الملك عبدالله، الرياض', 24.7300, 46.7100, 4.30, 145, 10.00, 75.00, 60, true),

-- Pharmacy
('a1b2c3d4-0008-0008-0008-000000000008', 'صيدلية النهدي', 'pharmacy', 'active',
 'صحتك أولويتنا — أدوية وصحة وجمال', NULL, NULL,
 '+966500000008', 'طريق الملك عبدالعزيز، الرياض', 24.7050, 46.6950, 4.60, 220, 0.00, 10.00, 30, true),

-- Bakery
('a1b2c3d4-0009-0009-0009-000000000009', 'برنس للمخبوزات', 'bakery', 'active',
 'خبز طازج وحلويات شرقية يومياً من الفرن مباشرة', NULL, NULL,
 '+966500000009', 'حي النخيل، الرياض', 24.7400, 46.7300, 4.70, 67, 5.00, 20.00, 25, false)

ON CONFLICT (id) DO NOTHING;

-- ─── Sample Products for البيك ───────────────────────────────

INSERT INTO products (merchant_id, name, name_ar, description, price, category, image_url, is_available, stock_quantity) VALUES

('a1b2c3d4-0003-0003-0003-000000000003', 'Broasted Meal', 'وجبة بروستد', 'قطعتا دجاج بروستد مع بطاطس وعصير', 25.00, 'meals', NULL, true, 999),
('a1b2c3d4-0003-0003-0003-000000000003', 'Jumbo Shrimp', 'جمبو روبيان', 'روبيان مقرمش كبير الحجم مع صلصة خاصة', 35.00, 'seafood', NULL, true, 999),
('a1b2c3d4-0003-0003-0003-000000000003', 'Chicken Sandwich', 'ساندويتش دجاج', 'صدر دجاج مقرمش مع خس وطماطم', 18.00, 'sandwiches', NULL, true, 999),
('a1b2c3d4-0003-0003-0003-000000000003', 'Family Box', 'صندوق العائلة', '8 قطع دجاج + بطاطس كبيرة + 4 عصائر', 85.00, 'family', NULL, true, 999),
('a1b2c3d4-0003-0003-0003-000000000003', 'Pepsi Can', 'بيبسي علبة', 'مشروب غازي بارد 330ml', 5.00, 'drinks', NULL, true, 999)

ON CONFLICT DO NOTHING;

-- Products for برجر كينج
INSERT INTO products (merchant_id, name, name_ar, description, price, category, image_url, is_available, stock_quantity) VALUES

('a1b2c3d4-0001-0001-0001-000000000001', 'Whopper', 'وابر', 'برجر لحم بقري كبير مع خضروات طازجة', 27.00, 'burgers', NULL, true, 999),
('a1b2c3d4-0001-0001-0001-000000000001', 'Crispy Chicken', 'كرسبي تشيكن', 'صدر دجاج مقرمش مع صلصة خاصة', 22.00, 'burgers', NULL, true, 999),
('a1b2c3d4-0001-0001-0001-000000000001', 'Onion Rings', 'حلقات البصل', 'حلقات بصل مقرمشة مع صلصة', 12.00, 'sides', NULL, true, 999),
('a1b2c3d4-0001-0001-0001-000000000001', 'King Meal', 'وجبة الكينج', 'وابر + بطاطس وسط + مشروب', 38.00, 'meals', NULL, true, 999)

ON CONFLICT DO NOTHING;

-- Products for KFC
INSERT INTO products (merchant_id, name, name_ar, description, price, category, image_url, is_available, stock_quantity) VALUES

('a1b2c3d4-0002-0002-0002-000000000002', 'Zinger Burger', 'زنجر برجر', 'صدر دجاج حار مع مايونيز وخس', 24.00, 'burgers', NULL, true, 999),
('a1b2c3d4-0002-0002-0002-000000000002', 'Bucket 8 Pieces', 'دلو 8 قطع', '8 قطع دجاج مقرمش متنوعة', 65.00, 'buckets', NULL, true, 999),
('a1b2c3d4-0002-0002-0002-000000000002', 'Mashed Potato', 'بطاطس مهروسة', 'بطاطس مهروسة بالجريفي الشهير', 8.00, 'sides', NULL, true, 999),
('a1b2c3d4-0002-0002-0002-000000000002', 'Coleslaw', 'كول سلو', 'سلطة كول سلو بالمايونيز', 7.00, 'sides', NULL, true, 999)

ON CONFLICT DO NOTHING;

-- Products for صيدلية النهدي
INSERT INTO products (merchant_id, name, name_ar, description, price, category, image_url, is_available, stock_quantity) VALUES

('a1b2c3d4-0008-0008-0008-000000000008', 'Panadol Extra', 'بنادول إكسترا', 'مسكن للألم والحرارة', 15.00, 'painkillers', NULL, true, 50),
('a1b2c3d4-0008-0008-0008-000000000008', 'Vitamin C 1000mg', 'فيتامين سي 1000', 'فيتامين سي لتقوية المناعة 30 قرص', 35.00, 'vitamins', NULL, true, 30),
('a1b2c3d4-0008-0008-0008-000000000008', 'Hand Sanitizer', 'معقم اليدين', 'معقم يدين 500ml بالكحول 70%', 18.00, 'hygiene', NULL, true, 100)

ON CONFLICT DO NOTHING;

-- Products for كارفور
INSERT INTO products (merchant_id, name, name_ar, description, price, category, image_url, is_available, stock_quantity) VALUES

('a1b2c3d4-0007-0007-0007-000000000007', 'Milk 1L Full Fat', 'حليب كامل الدسم 1 لتر', 'حليب طازج بالدسم الكامل', 6.50, 'dairy', NULL, true, 200),
('a1b2c3d4-0007-0007-0007-000000000007', 'Eggs 30 pcs', 'بيض 30 حبة', 'بيض بلدي طازج', 25.00, 'dairy', NULL, true, 150),
('a1b2c3d4-0007-0007-0007-000000000007', 'Rice Basmati 5kg', 'أرز بسمتي 5 كيلو', 'أرز بسمتي طويل الحبة', 42.00, 'grains', NULL, true, 80),
('a1b2c3d4-0007-0007-0007-000000000007', 'Bread Whole Wheat', 'خبز قمح كامل', 'خبز توست من القمح الكامل', 9.00, 'bakery', NULL, true, 60)

ON CONFLICT DO NOTHING;

-- ─── Done ────────────────────────────────────────────────────
SELECT 
  (SELECT COUNT(*) FROM merchants) AS merchants_count,
  (SELECT COUNT(*) FROM products) AS products_count,
  (SELECT COUNT(*) FROM categories) AS categories_count;
