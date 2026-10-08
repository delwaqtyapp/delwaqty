-- ============================================================
-- 105_order_cancelled_at_column.sql
-- `cancelOrder` writes and `_fromRow` reads `orders.cancelled_at`,
-- but the column was never created in any migration, so every
-- cancellation UPDATE failed with PGRST204 and no order could ever
-- be cancelled from the customer app.
--
-- Backfilled from `updated_at` for rows that are already cancelled so
-- existing orders get a meaningful timestamp immediately.
-- ============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

UPDATE public.orders
   SET cancelled_at = updated_at
 WHERE status = 'cancelled'
   AND cancelled_at IS NULL;

CREATE INDEX IF NOT EXISTS orders_cancelled_at_idx
  ON public.orders (cancelled_at DESC)
  WHERE cancelled_at IS NOT NULL;