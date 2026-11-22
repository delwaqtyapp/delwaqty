-- 400 (owner GO 2026-11-23): one barcode per store for the in-app cashier.
-- Scan-to-add and typed-barcode lookup in the provider POS assume a barcode
-- identifies at most one product of a merchant. The product form and the POS
-- quick-add dialog check client-side for a friendly Arabic error; this
-- partial unique index is the enforcement of last resort against racing
-- tills. NULL and blank barcodes are exempt so stores that do not use
-- barcodes are unaffected. pharmacy_import_drug already dedupes on barcode
-- per store, so the existing import path stays compatible.
CREATE UNIQUE INDEX IF NOT EXISTS products_merchant_barcode_uq
  ON public.products (merchant_id, barcode)
  WHERE barcode IS NOT NULL AND btrim(barcode) <> '';
