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
