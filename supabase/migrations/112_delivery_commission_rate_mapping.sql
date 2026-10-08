-- 112: complete_delivery recorded a 0% commission on every delivery
--
-- FOUND WHILE FIXING 111 (the SQLSTATE 42725 ambiguity). Migration 111 removed
-- the ambiguity that made complete_delivery throw; with the throw gone, the next
-- line executed and revealed the defect underneath it:
--
--   SELECT COALESCE(public.get_commission_rate('delivery', NULL), 0) INTO v_rate;
--
-- 'delivery' is not an account type. The seeded account_type rules are admin,
-- customer, driver (7%), merchant (3%) and provider (7%); 'delivery' exists only
-- as a service_type rule. The lookup therefore returned NULL, COALESCE turned it
-- into 0, and the function then:
--   - paid the driver the FULL order total as a delivery earning, and
--   - wrote a platform_commissions row with commission_rate = 0.
-- The platform earned nothing on every delivery while the books showed a
-- commission was computed. Fixing the ambiguity alone would have converted a loud
-- failure into silent zero revenue, so the mapping is corrected here.
--
-- The authoritative mapping is platform_commission_for_reference, which for a
-- completed ride selects account_type 'driver' with no service category and
-- passes the driver's user id for the per-account override. complete_delivery now
-- uses the same inputs, so the snapshot function and the settlement path cannot
-- disagree.
--
-- Verified live before this change:
--   SELECT public.get_commission_rate('delivery', NULL);  -- NULL  (no rule)
--   SELECT public.get_commission_rate('driver',  NULL);  -- 7.00 (rule exists)

CREATE OR REPLACE FUNCTION public.complete_delivery(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $fn$


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
$fn$;

-- Guard: the driver commission rule must exist. Without it this function would
-- again record 0% and this migration would still succeed.
DO $$
BEGIN
  IF public.get_commission_rate('driver', NULL, NULL) IS NULL THEN
    RAISE EXCEPTION
      'no active account_type=driver commission rule - deliveries would be recorded with no commission';
  END IF;
  RAISE NOTICE 'driver commission rule present: %',
    (SELECT public.get_commission_rate('driver', NULL, NULL)::text);
END $$;
