-- 091: Remove the delivery-car service (owner decision, sprint 189)
-- The company only operates motorbike/bike courier deliveries; the Uber-style
-- car-delivery marketplace (customer home-services "سيارة توصيل" + admin
-- delivery-car-requests) is being retired permanently.
--
-- Drop order matters: delivery_car_requests.car_product_id references
-- car_products(id) ON DELETE SET NULL, so drop the child table first.
DROP TABLE IF EXISTS public.delivery_car_requests;
DROP TABLE IF EXISTS public.car_products;

-- Remove the 'deliveryCar' home-services category seed row.
DELETE FROM public.service_categories
WHERE type = 'deliveryCar';

-- New driver accounts no longer default to the passenger-`ride` capability;
-- courier delivery service types remain the default flow.
ALTER TABLE public.drivers
  ALTER COLUMN service_types SET DEFAULT ARRAY[]::TEXT[];