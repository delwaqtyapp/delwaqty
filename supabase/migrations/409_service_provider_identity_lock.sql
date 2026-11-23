BEGIN;
CREATE OR REPLACE FUNCTION public.service_providers_guard_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.category_type IS DISTINCT FROM OLD.category_type THEN
      RAISE EXCEPTION 'provider identity is managed by the approval lifecycle' USING ERRCODE='42501';
    END IF;
  END IF;
  IF current_user IN ('authenticated', 'anon') AND NOT public.is_admin() THEN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'user_id is immutable';
    END IF;
    IF NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
      RAISE EXCEPTION 'is_verified is managed by the admin verification RPCs';
    END IF;
    IF NEW.rating IS DISTINCT FROM OLD.rating THEN
      RAISE EXCEPTION 'rating is managed by the rating engine';
    END IF;
    IF NEW.rating_count IS DISTINCT FROM OLD.rating_count THEN
      RAISE EXCEPTION 'rating_count is managed by the rating engine';
    END IF;
    IF NEW.hourly_rate IS DISTINCT FROM OLD.hourly_rate THEN
      RAISE EXCEPTION 'hourly_rate is managed by the admin RPCs';
    END IF;
    IF NEW.fixed_price_min IS DISTINCT FROM OLD.fixed_price_min THEN
      RAISE EXCEPTION 'fixed_price_min is managed by the admin RPCs';
    END IF;
    IF NEW.fixed_price_max IS DISTINCT FROM OLD.fixed_price_max THEN
      RAISE EXCEPTION 'fixed_price_max is managed by the admin RPCs';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;
COMMIT;
