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
