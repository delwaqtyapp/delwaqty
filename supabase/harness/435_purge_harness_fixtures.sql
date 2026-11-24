-- Synthetic pharmacy pre-state for the 435 harness. Runs BEFORE 431.
-- Idempotent on a fresh DB; 435_purge_harness_reset.sql rebuilds it.
BEGIN;
INSERT INTO public.merchants (id, name, type, status, is_open)
VALUES ('43500000-0000-4000-8000-0000000000f1', 'harness pharmacy', 'pharmacy', 'active', true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.catalog_categories (id, name, merchant_type, is_active)
VALUES ('43500000-0000-4000-8000-0000000000f2', 'harness cat', 'pharmacy', true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.offers (id, merchant_id, title, discount_value, is_active)
VALUES ('43500000-0000-4000-8000-0000000000f3', '43500000-0000-4000-8000-0000000000f1', 'harness offer', 10, true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.delivery_pricing (service_type, base_fee, per_km, minimum_fee, is_active)
VALUES ('pharmacy_delivery', 10, 2, 12, true)
ON CONFLICT (service_type) DO NOTHING;
COMMIT;
