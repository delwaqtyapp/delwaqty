-- Delivery-only capability initialization. Dispatch currently matches 'food';
-- grocery/pharmacy/parcel are delivery taxonomy, never passenger ride types.
-- No per-vehicle category exclusion exists in the current dispatcher: vehicle,
-- distance and weight constraints are retained separately. No is_verified change.
BEGIN;
-- Explicit reviewed legacy cleanup, no verification/availability/opt-in change.
UPDATE public.drivers SET service_types=ARRAY[]::text[],updated_at=now()
 WHERE id='5d4e38b7-c629-4a42-b893-c8cd82a67ba4' AND service_types=ARRAY['ride']::text[] AND accepts_deliveries=false;
UPDATE public.drivers SET service_types=ARRAY['food','grocery','pharmacy','parcel']::text[],updated_at=now()
 WHERE id IN ('4f6294aa-8651-4d1f-88b4-bf5ed5963e6e','59327517-66e4-434b-a8c1-c56a4cbb6db7','18c439e9-20fa-4cab-b74a-7b0d882cbc5a')
 AND service_types=ARRAY['food','grocery','pharmacy','package']::text[];
DO $$ DECLARE bad text; BEGIN
 SELECT string_agg(id::text,',') INTO bad FROM public.drivers WHERE
 (service_types IS NOT NULL AND cardinality(service_types)>0 AND NOT service_types <@ ARRAY['food','grocery','pharmacy','parcel']::text[])
 OR accepts_deliveries IS NULL OR max_delivery_distance_km IS NULL OR max_delivery_distance_km<=0 OR max_delivery_distance_km>200
 OR max_weight_kg IS NULL OR max_weight_kg<=0 OR max_weight_kg>1000;
 IF bad IS NOT NULL THEN RAISE EXCEPTION 'INVALID_EXISTING_CAPABILITIES: %',bad; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.complete_driver_onboarding(p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF auth.uid() IS NULL OR d.user_id IS DISTINCT FROM auth.uid() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 IF NOT public.driver_application_documents_ready(p_driver_id) THEN
  RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active=true) THEN
  RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
 END IF;
 UPDATE public.drivers SET onboarding_completed=true,onboarding_step=5,
   service_types=CASE WHEN NOT coalesce(d.onboarding_completed,false) AND coalesce(cardinality(service_types),0)=0 THEN ARRAY['food','grocery','pharmacy','parcel']::text[] ELSE service_types END,
   accepts_deliveries=CASE WHEN NOT coalesce(d.onboarding_completed,false) THEN true ELSE accepts_deliveries END,
   verification_status=CASE WHEN is_verified THEN verification_status ELSE 'pending' END,
   updated_at=now() WHERE id=p_driver_id;
 RETURN jsonb_build_object('success',true);
END; $function$
;
CREATE OR REPLACE FUNCTION public.update_driver_capabilities(p_driver_id uuid, p_service_types text[], p_accepts_deliveries boolean, p_max_delivery_distance numeric, p_max_weight numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'FORBIDDEN');
  END IF;
  IF p_service_types IS NULL OR NOT p_service_types <@ ARRAY['food','grocery','pharmacy','parcel']::text[]
     OR (p_accepts_deliveries AND cardinality(p_service_types)=0)
     OR p_accepts_deliveries IS NULL
     OR p_max_delivery_distance IS NULL OR p_max_delivery_distance<=0 OR p_max_delivery_distance>200
     OR p_max_weight IS NULL OR p_max_weight<=0 OR p_max_weight>1000 THEN
    RETURN jsonb_build_object('success',false,'reason','INVALID_CAPABILITIES');
  END IF;
  UPDATE drivers SET
    service_types = p_service_types,
    accepts_deliveries = p_accepts_deliveries,
    max_delivery_distance_km = p_max_delivery_distance,
    max_weight_kg = p_max_weight,
    updated_at = NOW()
  WHERE id = p_driver_id;
  RETURN jsonb_build_object('success', true);
END;
$function$
;
UPDATE public.drivers SET service_types=ARRAY['food','grocery','pharmacy','parcel']::text[],updated_at=now() WHERE coalesce(cardinality(service_types),0)=0;
CREATE OR REPLACE FUNCTION public.driver_capability_bounds_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO public,pg_temp AS $$
BEGIN
 IF NEW.accepts_deliveries IS NULL OR NEW.service_types IS NULL OR NOT NEW.service_types <@ ARRAY['food','grocery','pharmacy','parcel']::text[]
    OR (NEW.accepts_deliveries AND cardinality(NEW.service_types)=0)
    OR NEW.max_delivery_distance_km IS NULL OR NEW.max_delivery_distance_km<=0 OR NEW.max_delivery_distance_km>200
    OR NEW.max_weight_kg IS NULL OR NEW.max_weight_kg<=0 OR NEW.max_weight_kg>1000 THEN
   RAISE EXCEPTION 'INVALID_CAPABILITIES' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.driver_capability_bounds_guard() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS driver_capability_bounds ON public.drivers;
CREATE TRIGGER driver_capability_bounds BEFORE INSERT OR UPDATE OF service_types,accepts_deliveries,max_delivery_distance_km,max_weight_kg ON public.drivers FOR EACH ROW EXECUTE FUNCTION public.driver_capability_bounds_guard();
COMMIT;
