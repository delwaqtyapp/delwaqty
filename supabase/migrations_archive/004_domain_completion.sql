-- Restaurant Domain Completion - Schema Enhancements
-- Adds inventory, enhances offers/reservations/coupons for complete domain

-- ─── Offers: Branch & Category Support ──────────────────────
ALTER TABLE offers ADD COLUMN IF NOT EXISTS branch_id UUID REFERENCES branches(id);
ALTER TABLE offers ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES catalog_categories(id);

-- ─── Offers: Automatic Flag ──────────────────────────────────
ALTER TABLE offers ADD COLUMN IF NOT EXISTS is_automatic BOOLEAN DEFAULT false;

-- ─── Reservations: Table & Duration ────────────────────────
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS table_number TEXT;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 120;

-- ─── Coupons: Branch, Product, Category Scoping ─────────────
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS branch_id UUID REFERENCES branches(id);
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);
ALTER TABLE coupons ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES catalog_categories(id);

-- ─── Reviews: Image URLs Support ────────────────────────────
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]';
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

-- ─── Product Inventory ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  low_stock_threshold INTEGER DEFAULT 10,
  is_in_stock BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE product_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Inventory viewable by everyone" ON product_inventory
  FOR SELECT USING (true);

CREATE POLICY "Merchants can manage own inventory" ON product_inventory
  FOR ALL USING (merchant_id IN (
    SELECT id FROM merchants WHERE id = merchant_id
  ));

CREATE INDEX IF NOT EXISTS idx_product_inventory_merchant ON product_inventory(merchant_id);
CREATE INDEX IF NOT EXISTS idx_product_inventory_product ON product_inventory(product_id);

-- ─── Indexes for new columns ────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_offers_branch ON offers(branch_id);
CREATE INDEX IF NOT EXISTS idx_offers_category ON offers(category_id);
CREATE INDEX IF NOT EXISTS idx_coupons_branch ON coupons(branch_id);
CREATE INDEX IF NOT EXISTS idx_coupons_product ON coupons(product_id);
CREATE INDEX IF NOT EXISTS idx_coupons_category ON coupons(category_id);
CREATE INDEX IF NOT EXISTS idx_reservations_merchant ON reservations(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reservations_branch ON reservations(branch_id);
