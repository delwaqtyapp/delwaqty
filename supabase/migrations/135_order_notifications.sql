-- 135_order_notifications.sql
-- Mechanism audit: nothing in the order lifecycle ever inserted into
-- notifications, so the push chain (wired + verified separately) had no
-- order events to deliver. Follows the exact pattern of
-- notify_complaint_notifications: idempotent inserts with deep links.
--
--   orders INSERT        -> merchant owner: new order
--   orders status change -> customer: confirmed/preparing/ready/delivering/
--                           delivered/cancelled

CREATE OR REPLACE FUNCTION public.notify_order_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title text;
  v_body text;
  v_merchant_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT name INTO v_merchant_name FROM public.merchants WHERE id = NEW.merchant_id;
    INSERT INTO public.notifications
      (user_id, title, body, type, data, deep_link, idempotency_key, sender_id, priority, send_push)
    SELECT
      m.owner_user_id,
      'طلب جديد 🛎️',
      'عندك طلب جديد بقيمة ' || COALESCE(NEW.total_amount::text, '?') || ' جنيه',
      'order',
      jsonb_build_object('entity_type', 'order', 'entity_id', NEW.id::text, 'action', 'new'),
      '/merchant-dashboard/orders',
      'order-new-' || NEW.id::text,
      NEW.user_id, 'high', true
    FROM public.merchants m
    WHERE m.id = NEW.merchant_id
      AND m.owner_user_id IS NOT NULL
    ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    RETURN NULL;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    v_title := CASE NEW.status
      WHEN 'confirmed' THEN 'تم تأكيد طلبك ✅'
      WHEN 'preparing' THEN 'طلبك بيتحضر 👨‍🍳'
      WHEN 'ready' THEN 'طلبك جاهز 📦'
      WHEN 'delivering' THEN 'طلبك في الطريق 🛵'
      WHEN 'delivered' THEN 'تم توصيل طلبك 🎉'
      WHEN 'cancelled' THEN 'تم إلغاء الطلب ❌'
      ELSE NULL
    END;
    v_body := CASE NEW.status
      WHEN 'confirmed' THEN 'المتجر أكد طلبك وهيبدأ يجهزه'
      WHEN 'preparing' THEN 'المتجر بيحضر طلبك دلوقتي'
      WHEN 'ready' THEN 'طلبك جاهز ومستني التوصيل'
      WHEN 'delivering' THEN 'الطيار في الطريق إليك بطلبك'
      WHEN 'delivered' THEN 'طلبك وصل، بالهنا والشفا 🌹'
      WHEN 'cancelled' THEN COALESCE(NULLIF(NEW.cancelled_reason, ''), 'اتأسفنا، الطلب اتلغى')
      ELSE NULL
    END;

    IF v_title IS NOT NULL THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, data, deep_link, idempotency_key, sender_id, priority, send_push)
      VALUES
        (NEW.user_id, v_title, v_body, 'order',
         jsonb_build_object('entity_type', 'order', 'entity_id', NEW.id::text, 'action', NEW.status),
         '/orders/' || NEW.id::text || '/tracking',
         'order-' || NEW.id::text || '-' || NEW.status,
         NEW.merchant_id, 'normal', true)
      ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS notify_order_events ON public.orders;
CREATE TRIGGER notify_order_events
  AFTER INSERT OR UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_order_events();
