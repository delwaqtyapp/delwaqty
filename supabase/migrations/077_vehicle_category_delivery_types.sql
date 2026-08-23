-- 077_vehicle_category_delivery_types.sql
-- Fix the vehicles.category CHECK constraint mismatch that caused
-- PostgrestException code 23514 ("violates check constraint
-- vehicles_category_check") when the Delivery app submitted a modern
-- delivery vehicle type such as 'motorcycle'.
--
-- The previous constraint only accepted legacy passenger/taxi classes
-- ('economy','comfort','premium','xl','motorbike','taxi').
--
-- This migration is ADDITIVE and NON-DESTRUCTIVE:
--   * existing rows (legacy passenger vehicles) remain valid and untouched,
--   * the new constraint additionally accepts the canonical Delivery types,
--   * the column default is changed to a valid Delivery type.
-- No historical records are deleted or rewritten.

ALTER TABLE public.vehicles
  DROP CONSTRAINT IF EXISTS vehicles_category_check;

ALTER TABLE public.vehicles
  ADD CONSTRAINT vehicles_category_check
  CHECK (
    category IN (
      -- legacy values retained for historical record compatibility
      'economy',
      'comfort',
      'premium',
      'xl',
      'motorbike',
      'taxi',
      -- canonical Delivery vehicle types
      'motorcycle',
      'tuk_tuk',
      'tricycle',
      'electric_scooter',
      'scooter',
      'mini_scooter',
      'bicycle',
      'car',
      'van',
      'pickup',
      'light_transport'
    )
  );

ALTER TABLE public.vehicles
  ALTER COLUMN category SET DEFAULT 'motorcycle';
