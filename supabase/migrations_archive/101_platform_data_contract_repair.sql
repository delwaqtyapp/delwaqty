-- ============================================================
-- 101_platform_data_contract_repair.sql
-- Repairs the app<->database data contract so the core write
-- paths that are currently guaranteed to fail actually work.
--
-- VERIFIED LIVE against the production schema (PostgREST OpenAPI,
-- pg_constraint) on 2026-10-02. Every statement below fixes a
-- defect that makes a customer action impossible today:
--
--   1. orders.special_instructions missing  -> the customer's order
--      notes/special-instructions text could never be stored.
--   2. order_items.product_name / variant_name missing -> item
--      snapshots could never be persisted; the order-line history
--      had no readable product label.
--   3. products.is_featured missing -> merchant "featured product"
--      writes were rejected, the Popular rail could never populate.
--   4. products.tags missing -> tag-based search had no column.
--   5. reviews.user_name missing -> reviewer display name was
--      never resolvable.
--   6. catalog_categories legacy columns (name / description / icon /
--      image_url / is_visible / merchant_id) missing while the app
--      queries them -> merchant category chips/menus always failed.
--   7. drivers.is_active missing -> "suspend driver" had no column.
--   8. orders.payment_method CHECK rejected instapay / vodafone_cash
--      -> every non-cash checkout was rejected.
--   9. wallet_transactions had no user_id (queries filtered on it)
--      and its CHECK rejected the app's 'topup'/'payment' kinds.
--
-- Design notes:
--   * All new columns are nullable/backfilled so existing rows stay
--     valid and no rewrite lock is taken on large tables.
--   * Product-name snapshots are backfilled from the live product
--     rows so historic order_items become readable immediately.
--   * The payment-method CHECK is widened (never narrowed) and the
--     wallet type CHECK is widened to cover the app's own kinds
--     while keeping the legacy credit/debit vocabulary working.
-- ============================================================

-- ─── 1 & 2 & 3 & 4: orders / order_items / products ───────────

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS special_instructions TEXT;

-- `merchant_name` exists on the live database but was declared in NO
-- migration, so a database rebuilt from the migration set would be
-- missing the column the checkout inserts into (PGRST204 on every order).
-- Backfilled from the merchant record so historic orders are readable.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS merchant_name TEXT;

UPDATE public.orders o
   SET merchant_name = m.name
  FROM public.merchants m
 WHERE o.merchant_id = m.id
   AND (o.merchant_name IS NULL OR o.merchant_name = '');

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS product_name TEXT,
  ADD COLUMN IF NOT EXISTS variant_name TEXT;

-- Backfill the item snapshots from the current product catalogue so
-- historical order lines gain a readable label (best effort).
UPDATE public.order_items oi
   SET product_name = p.name
  FROM public.products p
 WHERE oi.product_id = p.id
   AND (oi.product_name IS NULL OR oi.product_name = '');

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tags TEXT[];

-- ─── 5: reviews.user_name ──────────────────────────────────────

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS user_name TEXT;

-- ─── 6: catalog_categories legacy columns ──────────────────────
-- VERIFIED LIVE 2026-10-02: migration 056 (the localized catalog
-- model with name_en/name_ar + merchant_type + is_active) is NOT
-- applied on the live project - catalog_categories is still the
-- original single-name shape (id, name, description, icon,
-- image_url, is_visible, sort_order, merchant_id). The app queries
-- the 056 shape, so every merchant category chip / restaurant menu
-- tab failed. Rather than assume a model that is not deployed, add
-- the 056 columns alongside the existing ones (additive only), and
-- have the data layer resolve name from whichever is populated.

ALTER TABLE public.catalog_categories
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_en TEXT,
  ADD COLUMN IF NOT EXISTS icon_name TEXT,
  ADD COLUMN IF NOT EXISTS color_code TEXT,
  ADD COLUMN IF NOT EXISTS merchant_type TEXT,
  ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.catalog_categories(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Backfill the localized columns from the legacy single-name column
-- so existing rows remain readable through either projection.
UPDATE public.catalog_categories
   SET name_ar = name
 WHERE name_ar IS NULL OR name_ar = '';

UPDATE public.catalog_categories
   SET name_en = name
 WHERE name_en IS NULL OR name_en = '';

-- ─── 7: drivers.is_active ──────────────────────────────────────

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Keep the legacy status vocabulary consistent with the new flag.
UPDATE public.drivers
   SET is_active = false
 WHERE status IN ('suspended', 'banned', 'inactive');

-- ─── 8: widen orders.payment_method CHECK ──────────────────────

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_payment_method_check
  CHECK (payment_method IN ('cash','card','wallet','instapay','vodafone_cash'));

-- ─── 9: wallet_transactions.user_id + widen type CHECK ─────────

ALTER TABLE public.wallet_transactions
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

-- Backfill owner from the linked wallet.
UPDATE public.wallet_transactions wt
   SET user_id = w.user_id
  FROM public.wallets w
 WHERE wt.wallet_id = w.id
   AND wt.user_id IS NULL;

CREATE INDEX IF NOT EXISTS wallet_transactions_user_id_idx
  ON public.wallet_transactions (user_id, created_at DESC);

ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_type_check
  CHECK (type IN ('credit','debit','topup','payment','refund','transfer','withdrawal'));

-- ─── wallets: RLS must allow the app to CREATE its own wallet row
--     and MOVE its own balance; today only a SELECT policy exists,
--     so a wallet can never be created or debited from the app. ──

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname='public' AND tablename='wallets' AND policyname='wallets_insert_own'
  ) THEN
    CREATE POLICY wallets_insert_own ON public.wallets
      FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname='public' AND tablename='wallets' AND policyname='wallets_update_own'
  ) THEN
    CREATE POLICY wallets_update_own ON public.wallets
      FOR UPDATE TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname='public' AND tablename='wallet_transactions'
       AND policyname='wallet_transactions_select_own'
  ) THEN
    CREATE POLICY wallet_transactions_select_own ON public.wallet_transactions
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;