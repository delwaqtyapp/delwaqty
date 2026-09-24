-- 085_reviews_universal_seeds.sql
-- (a) Make per-PROVIDER reviews possible: unique per (user, category, provider).
-- (b) Seed real merchant reviews (restaurants & co.) into the commerce `reviews`
--     table so restaurant/market pages are no longer empty.
-- (c) Seed per-provider service reviews so every provider card has live ratings.

-- (a) scoped uniqueness -------------------------------------------------------
DROP INDEX IF EXISTS uq_service_reviews_category_user;
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_reviews_user
  ON service_reviews (user_id, category_type, provider_id);

-- (b) merchant reviews (commerce) ----------------------------------------------
INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 5, 'أكل رائع والتوصيل في موعده'
FROM merchants WHERE type = 'restaurant' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 4, 'مطعم نظيف وأسعار مناسبة'
FROM merchants WHERE type = 'restaurant' ORDER BY id LIMIT 1 OFFSET 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 5, 'لحوم طازجة والتعامل راقي'
FROM merchants WHERE type = 'butcher' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 4, 'خضار وفاكهة نظيفة كل يوم'
FROM merchants WHERE type = 'vegetables' LIMIT 1
ON CONFLICT DO NOTHING;

-- (c) per-provider service reviews --------------------------------------------
-- doctor
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'doctor', id, 'محمود فتحي', 5, 'دكتور متابع معايا بجد وشرحلي كل حاجة'
FROM service_providers WHERE category_type = 'doctor' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'doctor', id, 'هالة سمير', 4, 'ملتزم بالمواعيد ومحترف'
FROM service_providers WHERE category_type = 'doctor' ORDER BY id LIMIT 1 OFFSET 1
ON CONFLICT DO NOTHING;

-- teacher
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'teacher', id, 'إيهاب رشاد', 5, 'أسلوب شرح سهل وكويس جداً للمراجعات'
FROM service_providers WHERE category_type = 'teacher' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- barber
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'barber', id, 'كريم عاطف', 5, 'حلاق محترم وشغل نضيف'
FROM service_providers WHERE category_type = 'barber' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- nurse
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'nurse', id, 'منى عبد الله', 4, 'تمريض بيتي جيد ومتابعة مستمرة'
FROM service_providers WHERE category_type = 'nurse' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- plumbing
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'plumbing', id, 'سامح عزت', 5, 'سباك محترف وأسعار مناسبة'
FROM service_providers WHERE category_type = 'plumbing' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- electrical
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'electrical', id, 'وليد سامي', 4, 'كهربائي دقيق وشغله متقن'
FROM service_providers WHERE category_type = 'electrical' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- cleaning
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'cleaning', id, 'نورهان أحمد', 5, 'تنظيف ممتاز وبأدواتهم كل حاجة'
FROM service_providers WHERE category_type = 'cleaning' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;

-- carpentry
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
SELECT NULL, 'carpentry', id, 'جابر مرسي', 4, 'نجار فنان وشغل خامة ممتازة'
FROM service_providers WHERE category_type = 'carpentry' ORDER BY id LIMIT 1
ON CONFLICT DO NOTHING;