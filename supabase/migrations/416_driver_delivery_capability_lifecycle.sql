-- Delivery-only capability initialization. Dispatch currently matches 'food';
-- grocery/pharmacy/parcel are delivery taxonomy, never passenger ride types.
-- No per-vehicle category exclusion exists in the current dispatcher: vehicle,
-- distance and weight constraints are retained separately. No is_verified change.
BEGIN;
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
   service_types=CASE WHEN coalesce(cardinality(service_types),0)=0 THEN ARRAY['food','grocery','pharmacy','parcel']::text[] ELSE service_types END,
   accepts_deliveries=true,
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
COMMIT;
