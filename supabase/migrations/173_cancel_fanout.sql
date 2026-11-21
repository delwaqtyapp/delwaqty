-- 173_cancel_fanout.sql
-- Bughunt F4 (prep): cancelling an order left the assigned driver heading to
-- pickup (no notification, order stayed in their queue) and the merchant
-- unaware. cancel_order now:
--   * unassigns the driver (orders.driver_id = NULL)
--   * cancels any still-active linked rides rows
--   * notifies the assigned driver and the merchant owner (Arabic, push)
-- The customer-cancel-after-driver-accept policy gate is NOT added here; it
-- is pending the owner's product decision and will be a small addition on
-- top of this function once confirmed.

CREATE OR REPLACE FUNCTION public.cancel_order(p_order_id uuid, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_refunded boolean := false;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_short text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;

  if v_order.user_id is distinct from v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;

  if v_order.status in ('delivered', 'cancelled') then
    return jsonb_build_object('ok', false, 'code', 'NOT_CANCELLABLE', 'status', v_order.status);
  end if;

  -- Restore stock exactly once (only orders that decremented)
  if v_order.stock_decremented then
    update public.products p
       set stock_quantity = p.stock_quantity + oi.quantity
      from public.order_items oi
     where oi.order_id = v_order.id
       and p.id = oi.product_id
       and p.stock_quantity is not null;
  end if;

  if v_order.payment_status = 'paid' then
    perform public.wallet_refund(
      p_user_id := v_order.user_id,
      p_amount := v_order.total_amount,
      p_description := 'Order cancellation refund for order ' || p_order_id::text,
      p_reference_type := 'refund',
      p_reference_id := p_order_id
    );
    v_refunded := true;
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_reason = coalesce(p_reason, v_order.cancelled_reason),
         cancelled_at = now(),
         payment_status = case when v_order.payment_status = 'paid' then 'refunded' else v_order.payment_status end,
         stock_decremented = false,
         driver_id = null,
         updated_at = now()
   where id = v_order.id;

  -- Cancel any still-active linked delivery rides so the driver's queue drops them.
  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = case when v_uid is distinct from v_order.user_id then 'system' else 'rider' end,
         cancellation_reason = coalesce(p_reason, 'Order cancelled')
   where order_id = v_order.id
     and status not in ('completed', 'cancelled');

  -- Notify the assigned driver: stop heading to pickup.
  if v_order.driver_id is not null then
    select user_id into v_driver_uid from public.drivers where id = v_order.driver_id;
    if v_driver_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_driver_uid,
              'تم إلغاء الطلب',
              'ألغى العميل الطلب. لا تتوجه للاستلام.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  -- Notify the merchant owner.
  if v_order.merchant_id is not null then
    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      v_short := right(v_order.id::text, 6);
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'تم إلغاء طلب',
              'ألغى العميل الطلب رقم ' || v_short || '.',
              'order',
              jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                                 'reason', p_reason),
              true);
    end if;
  end if;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;
$function$;
