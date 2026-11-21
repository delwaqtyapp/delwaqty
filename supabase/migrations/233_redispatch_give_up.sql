-- 233 (reviewer #23): the redispatch sweep re-offered stuck rides forever.
-- A ride still 'searching' after 45 minutes with no live offer now gives
-- up: the linked order is cancelled through the shared finalizer (restock,
-- coupon release, paid-wallet refund, ride cancellation) and BOTH the
-- customer and the merchant are notified. Fresh stuck rides keep the
-- 2-minute redispatch behavior.
CREATE OR REPLACE FUNCTION public.redispatch_stuck_searching_rides()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ride record;
  v_order record;
  v_merchant_uid uuid;
  v_n integer := 0;
BEGIN
  -- Give-up pass (reviewer #23): searching > 45 min, no live offer.
  FOR v_ride IN
    SELECT r.id, r.order_id
      FROM public.rides r
     WHERE r.status = 'searching'
       AND r.created_at < now() - interval '45 minutes'
       AND NOT EXISTS (
         SELECT 1 FROM public.ride_requests rr
          WHERE rr.ride_id = r.id
            AND rr.status = 'offered'
            AND rr.expires_at > now()
       )
     ORDER BY r.created_at
     LIMIT 50
  LOOP
    IF v_ride.order_id IS NOT NULL THEN
      SELECT o.id, o.user_id, o.merchant_id INTO v_order
        FROM public.orders o
       WHERE o.id = v_ride.order_id
         AND o.status NOT IN ('delivered', 'cancelled');
      IF v_order.id IS NOT NULL THEN
        -- Finalizer owns restock, coupon release, wallet refund and the
        -- order+ride cancellation itself.
        PERFORM public._finalize_order_cancel(
          v_ride.order_id, 'system',
          'No driver accepted within 45 minutes',
          true, true, true, 'system');

        INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
        VALUES (v_order.user_id,
                'نعتذر، تم إلغاء طلبك',
                'لم نتمكن من إيجاد كابتن متاح خلال 45 دقيقة. إن كان طلبك مدفوعاً فسيعود المبلغ لمحفظتك.',
                'order',
                jsonb_build_object('order_id', v_ride.order_id, 'status', 'cancelled',
                                   'reason', 'no_driver_timeout'),
                true);

        SELECT owner_user_id INTO v_merchant_uid
          FROM public.merchants WHERE id = v_order.merchant_id;
        IF v_merchant_uid IS NOT NULL THEN
          INSERT INTO public.notifications (user_id, title, body, type, data, send_push)
          VALUES (v_merchant_uid,
                  'تم إلغاء طلب: لا يوجد كابتن',
                  'أُلغي الطلب بعد 45 دقيقة دون قبول أي كابتن. أُعيدت الكمية للمخزون.',
                  'order',
                  jsonb_build_object('order_id', v_ride.order_id, 'status', 'cancelled',
                                     'reason', 'no_driver_timeout'),
                  true);
        END IF;
        v_n := v_n + 1;
        CONTINUE;
      END IF;
    END IF;
    -- Order already closed or missing: stop the orphaned ride searching.
    UPDATE public.rides
       SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'system'
     WHERE id = v_ride.id AND status = 'searching';
  END LOOP;

  -- Redispatch pass (222): searching > 2 min, no live offer, still young.
  FOR v_ride IN
    SELECT r.id
      FROM public.rides r
     WHERE r.status = 'searching'
       AND r.created_at < now() - interval '2 minutes'
       AND r.created_at >= now() - interval '45 minutes'
       AND NOT EXISTS (
         SELECT 1 FROM public.ride_requests rr
          WHERE rr.ride_id = r.id
            AND rr.status = 'offered'
            AND rr.expires_at > now()
       )
     ORDER BY r.created_at
     LIMIT 50
  LOOP
    PERFORM public._dispatch_delivery_internal(v_ride.id, 25.0, 15);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;

-- Cron-only entry point: never client-callable.
REVOKE EXECUTE ON FUNCTION public.redispatch_stuck_searching_rides() FROM public, anon, authenticated;
