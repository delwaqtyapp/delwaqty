-- Migration 056: catalog_categories table creation
-- This table was referenced in migrations 003/004/005 but never explicitly created

CREATE TABLE IF NOT EXISTS catalog_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  description_ar TEXT,
  description_en TEXT,
  parent_id UUID REFERENCES catalog_categories(id) ON DELETE SET NULL,
  merchant_type TEXT, -- e.g., 'supermarket', 'grocery', 'restaurant', etc.
  icon_name TEXT,
  color_code TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- Create index for parent category queries
CREATE INDEX idx_catalog_categories_parent_id ON catalog_categories(parent_id);
CREATE INDEX idx_catalog_categories_merchant_type ON catalog_categories(merchant_type);
CREATE INDEX idx_catalog_categories_is_active ON catalog_categories(is_active);
CREATE INDEX idx_catalog_categories_sort_order ON catalog_categories(sort_order);

-- Comment: This table stores platform-level catalog categories that merchants can use
-- to classify their products. Categories can have hierarchical structure via parent_id.