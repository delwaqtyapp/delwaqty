-- P1 provider-profile: make backend provisioning recognise every real
-- service category (service_categories.type), not only the original subset.
-- Before this, approving a teacher / nurse / barber / pipe-change... profile
-- fell through to the merchant branch and tried merchants.type = 'teacher'.
-- Same signature, no data changes, no grants changed.
CREATE OR REPLACE FUNCTION public._is_home_service_category(p_cat text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT lower(btrim(COALESCE(p_cat, ''))) IN (
    'service', 'home_services', 'homeservices', 'plumbing', 'electrical',
    'cleaning', 'handyman', 'carpentry', 'ac_maintenance', 'acmaintenance',
    'painting', 'pest_control', 'pestcontrol', 'appliance_repair',
    'appliancerepair', 'doctor', 'clinic',
    -- added in 399
    'teacher', 'teachers', 'tutor', 'nurse', 'barber', 'other',
    'pipe_change', 'pipechange', 'plastering',
    'carpet_cleaning', 'carpetcleaning', 'dish_repair', 'dishrepair'
  );
$function$;
