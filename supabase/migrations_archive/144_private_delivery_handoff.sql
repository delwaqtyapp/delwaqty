-- Handoff codes are private server-owned challenges, never readable ride fields.
BEGIN;
CREATE TABLE public.delivery_handoff_challenges (
 ride_id uuid NOT NULL REFERENCES public.rides(id) ON DELETE CASCADE,
 stage text NOT NULL CHECK(stage IN ('pickup','dropoff')),
 code text NOT NULL,
 attempts integer NOT NULL DEFAULT 0,
 locked_until timestamptz,
 expires_at timestamptz NOT NULL DEFAULT now()+interval '24 hours',
 verified_at timestamptz,
 PRIMARY KEY(ride_id,stage)
);
ALTER TABLE public.delivery_handoff_challenges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.delivery_handoff_challenges FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public._new_delivery_handoff_code() RETURNS text LANGUAGE sql VOLATILE SET search_path=public,extensions,pg_temp AS $$
 SELECT lpad(((get_byte(b,0)::bigint*16777216+get_byte(b,1)::bigint*65536+get_byte(b,2)::bigint*256+get_byte(b,3)::bigint)%1000000)::text,6,'0') FROM (SELECT extensions.gen_random_bytes(4) b) q;
$$;
REVOKE ALL ON FUNCTION public._new_delivery_handoff_code() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public._redact_delivery_handoff() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 NEW.pickup_otp:=NULL;
 IF NEW.driver_id IS NOT NULL THEN NEW.otp_required:=true; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER redact_delivery_handoff BEFORE INSERT OR UPDATE OF driver_id,pickup_otp,otp_required ON public.rides FOR EACH ROW EXECUTE FUNCTION public._redact_delivery_handoff();
CREATE FUNCTION public._issue_delivery_handoff() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.driver_id IS NOT NULL AND (TG_OP='INSERT' OR OLD.driver_id IS DISTINCT FROM NEW.driver_id) THEN
  INSERT INTO public.delivery_handoff_challenges(ride_id,stage,code)
   VALUES(NEW.id,'pickup',public._new_delivery_handoff_code()),(NEW.id,'dropoff',public._new_delivery_handoff_code())
   ON CONFLICT(ride_id,stage) DO UPDATE SET code=EXCLUDED.code,attempts=0,locked_until=NULL,verified_at=NULL,expires_at=now()+interval '24 hours';
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER issue_delivery_handoff AFTER INSERT OR UPDATE OF driver_id ON public.rides FOR EACH ROW EXECUTE FUNCTION public._issue_delivery_handoff();
UPDATE public.rides SET pickup_otp=NULL WHERE pickup_otp IS NOT NULL;
INSERT INTO public.delivery_handoff_challenges(ride_id,stage,code)
 SELECT r.id,s.stage,public._new_delivery_handoff_code() FROM rides r CROSS JOIN (VALUES('pickup'),('dropoff')) s(stage)
 WHERE r.driver_id IS NOT NULL AND r.status IN ('matched','arrived','inTrip');
UPDATE public.delivery_handoff_challenges c SET verified_at=now() FROM rides r WHERE c.ride_id=r.id AND c.stage='pickup' AND r.status='inTrip';
CREATE FUNCTION public.delivery_handoff_code(p_stage text,p_ride_id uuid DEFAULT NULL,p_order_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE r rides%ROWTYPE; c delivery_handoff_challenges%ROWTYPE;
BEGIN
 SELECT * INTO r FROM rides WHERE (p_ride_id IS NOT NULL AND id=p_ride_id) OR (p_order_id IS NOT NULL AND order_id=p_order_id) ORDER BY created_at DESC LIMIT 1;
 IF NOT FOUND OR auth.uid() IS NULL OR p_stage NOT IN ('pickup','dropoff') THEN RETURN jsonb_build_object('ok',false,'reason','HANDOFF_UNAVAILABLE'); END IF;
 -- Merchant hands goods over at pickup; the customer/recipient controls dropoff.
 IF (p_stage='pickup' AND NOT ((r.merchant_id IS NOT NULL AND is_merchant_owner(r.merchant_id)) OR (r.merchant_id IS NULL AND r.rider_id=auth.uid())))
    OR (p_stage='dropoff' AND r.rider_id IS DISTINCT FROM auth.uid())
    OR EXISTS(SELECT 1 FROM drivers WHERE id=r.driver_id AND user_id=auth.uid()) THEN
   RETURN jsonb_build_object('ok',false,'reason','FORBIDDEN');
 END IF;
 IF r.status NOT IN ('matched','arrived','inTrip') THEN RETURN jsonb_build_object('ok',false,'reason','HANDOFF_UNAVAILABLE'); END IF;
 SELECT * INTO c FROM delivery_handoff_challenges WHERE ride_id=r.id AND stage=p_stage FOR UPDATE;
 IF NOT FOUND OR c.verified_at IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'reason','HANDOFF_UNAVAILABLE'); END IF;
 IF c.expires_at<=now() THEN
  UPDATE delivery_handoff_challenges SET code=public._new_delivery_handoff_code(),expires_at=now()+interval '24 hours',attempts=0,locked_until=NULL WHERE ride_id=r.id AND stage=p_stage RETURNING * INTO c;
 END IF;
 RETURN jsonb_build_object('ok',true,'code',c.code,'stage',p_stage,'locked_until',c.locked_until);
END; $$;
REVOKE ALL ON FUNCTION public.delivery_handoff_code(text,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.delivery_handoff_code(text,uuid,uuid) TO authenticated;
CREATE FUNCTION public._verify_delivery_handoff(p_ride_id uuid,p_stage text,p_code text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c delivery_handoff_challenges%ROWTYPE;
BEGIN
 SELECT * INTO c FROM delivery_handoff_challenges WHERE ride_id=p_ride_id AND stage=p_stage FOR UPDATE;
 IF NOT FOUND OR c.verified_at IS NOT NULL OR c.expires_at<=now() OR c.locked_until>now() THEN RETURN false; END IF;
 IF c.code IS DISTINCT FROM btrim(COALESCE(p_code,'')) THEN
  UPDATE delivery_handoff_challenges SET attempts=attempts+1,
   locked_until=CASE WHEN attempts+1>=5 THEN now()+interval '10 minutes' ELSE NULL END
   WHERE ride_id=p_ride_id AND stage=p_stage;
  RETURN false;
 END IF;
 UPDATE delivery_handoff_challenges SET verified_at=now() WHERE ride_id=p_ride_id AND stage=p_stage;
 RETURN true;
END; $$;
REVOKE ALL ON FUNCTION public._verify_delivery_handoff(uuid,text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.start_trip(p_ride_id uuid, p_driver_id uuid, p_otp text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_owner UUID;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF r.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_your_ride');
  END IF;
  IF r.status <> 'arrived' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;
  IF NOT public._verify_delivery_handoff(p_ride_id,'pickup',p_otp) THEN
    RETURN jsonb_build_object('success',false,'reason','INVALID_OR_LOCKED_PICKUP_CODE');
  END IF;
  UPDATE rides SET status = 'inTrip', started_at = NOW(), picked_up_at = NOW()
    WHERE id = p_ride_id;
  INSERT INTO trip_events (ride_id, event_type, actor) VALUES (p_ride_id, 'picked_up', 'driver');
  RETURN jsonb_build_object('success', true, 'status', 'inTrip');
END;
$function$
;
CREATE OR REPLACE FUNCTION public.complete_delivery(p_ride_id uuid, p_driver_id uuid, p_proof_url text DEFAULT NULL::text, p_final_distance numeric DEFAULT NULL::numeric, p_recipient_otp text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.rides%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM public.drivers WHERE id=p_driver_id AND user_id=auth.uid()) THEN
   RETURN jsonb_build_object('success',false,'reason','forbidden');
 END IF;
 SELECT * INTO r FROM public.rides WHERE id=p_ride_id FOR UPDATE;
 IF NOT FOUND OR r.driver_id IS DISTINCT FROM p_driver_id THEN
   RETURN jsonb_build_object('success',false,'reason','not_your_delivery');
 END IF;
 IF r.service_type='ride' OR r.status IS DISTINCT FROM 'inTrip' THEN
   RETURN jsonb_build_object('success',false,'reason','invalid_transition');
 END IF;
 IF NOT public._verify_delivery_handoff(p_ride_id,'dropoff',p_recipient_otp) THEN
   RETURN jsonb_build_object('success',false,'reason','INVALID_OR_LOCKED_RECIPIENT_CODE');
 END IF;
 UPDATE public.rides SET status='completed',completed_at=now(),delivered_at=now(),
   delivery_proof_url=COALESCE(p_proof_url,delivery_proof_url) WHERE id=p_ride_id;
 UPDATE public.driver_locations SET ride_id=NULL WHERE driver_id=p_driver_id AND ride_id=p_ride_id;
 INSERT INTO public.trip_events(ride_id,event_type,actor) VALUES(p_ride_id,'delivered','driver');
 RETURN jsonb_build_object('success',true,'ride_id',p_ride_id,'fare',r.fare);
END; $function$
;

CREATE OR REPLACE FUNCTION public.complete_delivery(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$


DECLARE
  v_uid     uuid := auth.uid();
  v_order   orders%ROWTYPE;
  v_is_driver boolean;
  v_driver_uid uuid;
  v_rate      numeric;
  v_commission numeric;
  v_net       numeric;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL OR v_order.driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_ASSIGNED');
  END IF;
  IF v_order.status = 'delivered' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'ALREADY_DONE');
  END IF;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;

  v_is_driver := EXISTS (
    SELECT 1 FROM public.drivers d
     WHERE d.user_id = v_uid AND d.id = v_order.driver_id
  );

  IF NOT v_is_driver AND NOT public._is_owner_uid(v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'FORBIDDEN');
  END IF;

  IF EXISTS(SELECT 1 FROM public.rides WHERE order_id=p_order_id) THEN
    RETURN jsonb_build_object('ok',false,'reason','USE_ASSIGNED_DELIVERY_FLOW');
  END IF;
  -- Canonical identity mapping: driver_earnings.driver_id -> drivers.id;
  -- platform_commissions.member_id -> users.id (drivers.user_id).
  SELECT user_id INTO v_driver_uid
    FROM public.drivers WHERE id = v_order.driver_id;

  -- Commission is charged to the driver who performs the delivery, so the
  -- account type is 'driver' (7% by rule), not 'delivery'. 'delivery' is a
  -- service_type rule and matched no account_type rule at all, which made
  -- this lookup return NULL and every delivery record a 0% commission while
  -- the driver kept 100% of the order total. The third argument is the
  -- driver's user id so an admin per-account override applies here exactly as
  -- it does in platform_commission_for_reference ('ride' branch).
  SELECT COALESCE(public.get_commission_rate('driver'::text, NULL::text, v_driver_uid), 0)
    INTO v_rate;
  v_rate := COALESCE(v_rate, 0);
  v_commission := (COALESCE(v_order.total_amount, 0) * v_rate / 100.0);
  v_net := COALESCE(v_order.total_amount, 0) - v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (v_order.driver_id, NULL, 'trip', v_net, 'EGP', 'Order ' || p_order_id::text || ' delivery earning');

  INSERT INTO public.platform_commissions (member_id, reference_type, reference_id, gross_amount, commission_rate, commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'order', p_order_id, v_order.total_amount, v_rate, v_commission, v_net, 'EGP', 'computed');

  UPDATE public.orders SET status = 'delivered', dispatch_status = 'ACCEPTED'
    WHERE id = p_order_id;

  PERFORM public.log_admin_action('DELIVERY_COMPLETE', 'order', p_order_id::text,
    NULL, jsonb_build_object('commission', v_commission, 'rate', v_rate), NULL, 'GLOBAL');
  RETURN jsonb_build_object('ok', true, 'commission', v_commission, 'rate', v_rate);
END;
$function$
;
NOTIFY pgrst,'reload schema';
COMMIT;
