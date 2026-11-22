-- 384: product_inventory foreign keys (owner defect D: provider inventory page broken)
-- The provider inventory screen embeds products(...) in its product_inventory
-- select. PostgREST needs a real FK to resolve that embed; product_inventory had
-- NO foreign keys, so every query failed with PGRST200 and the page sat on a
-- spinner/error. This migration cleans legacy orphan rows (inventory rows whose
-- product or merchant was deleted; unreachable by any UI) and adds the FKs with
-- ON DELETE CASCADE so future deletes stay consistent.
DELETE FROM public.product_inventory pi
WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.id = pi.product_id);

DELETE FROM public.product_inventory pi
WHERE NOT EXISTS (SELECT 1 FROM public.merchants m WHERE m.id = pi.merchant_id);

ALTER TABLE public.product_inventory
  ADD CONSTRAINT product_inventory_product_id_fkey
  FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.product_inventory
  ADD CONSTRAINT product_inventory_merchant_id_fkey
  FOREIGN KEY (merchant_id) REFERENCES public.merchants(id) ON DELETE CASCADE;
