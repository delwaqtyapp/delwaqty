-- Keep driver-only member verification aligned with reviewed driver documents.
-- No backfill, no account-status/role changes, existing invitation trigger dedupes.
CREATE OR REPLACE FUNCTION public.review_driver_application(p_driver_id uuid, p_approve boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.drivers%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 SELECT * INTO d FROM public.drivers WHERE id=p_driver_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'reason','DRIVER_NOT_FOUND'); END IF;
 IF NOT public._admin_write_scope(public._ops_scope_region(public._member_region_id(d.user_id))) THEN
  RETURN jsonb_build_object('success',false,'reason','FORBIDDEN');
 END IF;
 IF p_approve IS NULL THEN RETURN jsonb_build_object('success',false,'reason','INVALID_DECISION'); END IF;
 IF p_approve THEN
  IF NOT public.driver_application_documents_ready(p_driver_id) THEN
   RETURN jsonb_build_object('success',false,'reason','REQUIRED_DOCUMENTS_MISSING');
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.vehicles WHERE driver_id=p_driver_id AND is_active) THEN
   RETURN jsonb_build_object('success',false,'reason','ACTIVE_VEHICLE_REQUIRED');
  END IF;
 ELSE
  IF btrim(COALESCE(p_reason,''))='' THEN RETURN jsonb_build_object('success',false,'reason','REASON_REQUIRED'); END IF;
 END IF;
 IF p_approve THEN
  UPDATE public.driver_documents SET status='verified',
    reviewed_at=now(), rejection_reason=NULL
    WHERE driver_id=p_driver_id AND status='pending';
 ELSE
  UPDATE public.driver_documents SET status='rejected',
    reviewed_at=now(), rejection_reason=p_reason
    WHERE driver_id=p_driver_id AND status='pending'
      AND doc_type IN ('driving_license','vehicle_registration');
 END IF;
 UPDATE public.drivers SET is_verified=p_approve,
   verification_status=CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,updated_at=now()
   WHERE id=p_driver_id;
 -- A driver-only member's approval follows the reviewed driver application.
 -- Do not approve unrelated roles or clear any account suspension.
 UPDATE public.users
    SET verification_status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
        updated_at=now()
  WHERE id=d.user_id
    AND role IN ('driver','delivery') AND user_type IN ('driver','delivery');
 IF p_approve THEN UPDATE public.vehicles SET is_verified=true WHERE driver_id=p_driver_id AND is_active; END IF;
 INSERT INTO public.notifications(user_id,title,body,type,data,deep_link,send_push)
 VALUES(d.user_id,CASE WHEN p_approve THEN 'تمت مراجعة حساب السائق' ELSE 'مستندات السائق محتاجة مراجعة' END,
 CASE WHEN p_approve THEN 'تم قبول المستندات وتفعيل حساب السائق' ELSE p_reason END,
 'verification',jsonb_build_object('driver_id',p_driver_id,'approved',p_approve),'/driver/documents',true);
 RETURN jsonb_build_object('success',true);
END; $function$
;
