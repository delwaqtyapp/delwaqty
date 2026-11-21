-- 080_new_service_categories.sql
-- Expands the platform catalog with the commerce categories and booking
-- services requested for the customer launch (2026-09-17).
--
-- Commerce categories (read by the customer home / all-services page via the
-- free-form `categories` table): guarded by name NOT EXISTS because the table
-- has no unique constraint on name.
-- Booking services (`service_categories`, type UNIQUE): ON CONFLICT DO NOTHING
-- so re-running is idempotent.

-- ─── Commerce categories (متاجر) ────────────────────────────────────────
INSERT INTO categories (name, name_ar, icon, sort_order, is_active)
SELECT v.name, v.name_ar, v.icon, v.sort_order, true
FROM (VALUES
  ('عطور', 'عطور', '🌸', 15),
  ('عطارة', 'عطارة', '🧂', 16),
  ('البان', 'البان', '🥛', 17),
  ('إكسسوارات حريمي', 'إكسسوارات حريمي', '👜', 18),
  ('جزارة', 'جزارة', '🍖', 19),
  ('خضراوات وفواكة', 'خضراوات وفواكة', '🥕', 6)
) AS v(name, name_ar, icon, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.name = v.name);

-- ─── Booking services (خدمات وحجز) ─────────────────────────────────────
INSERT INTO service_categories (name_ar, name_en, type, description_ar, description_en) VALUES
  ('تغيير أنبوبة', 'Pipe Change', 'pipeChange', 'إصلاح وتغيير الأنابيب والوصلات المنزلية', 'Home pipe repair and replacement'),
  ('نقاشة', 'Plastering', 'plastering', 'نقاشة ومحارب الجدران والأسقف', 'Wall and ceiling plastering'),
  ('غسيل السجاد', 'Carpet Cleaning', 'carpetCleaning', 'غسيل وتنظيف السجاد والمفروشات مع الاستلام والتسليم', 'Carpet and upholstery cleaning with pickup and delivery'),
  ('إصلاح الدش', 'Dish Repair', 'dishRepair', 'تركيب وإصلاح أطباق الستلايت والرسيفر', 'Satellite dish installation and receiver repair'),
  ('مدرسين', 'Tutoring', 'teacher', 'دروس خصوصية لجميع المواد والمراحل الدراسية', 'Private tutoring for all subjects and grades'),
  ('حجز دكتور', 'Doctor Booking', 'doctor', 'حجز مواعيد عيادات الأطباء والاستشارات', 'Doctor clinic appointments and consultations'),
  ('ممرض', 'Nursing', 'nurse', 'رعاية تمريضية منزلية وحقن وضمادات', 'Home nursing care, injections and dressings'),
  ('حجز حلاق', 'Barber', 'barber', 'حجز مواعيد صالونات الحلاقة والحلاقين المتنقلين', 'Barber shop appointments and mobile barbers')
ON CONFLICT (type) DO NOTHING;