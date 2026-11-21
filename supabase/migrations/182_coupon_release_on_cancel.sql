-- 182: Coupon release on cancel (owner decision 2026-11-21, item 3)
-- When a customer cancels an order that used a coupon, the redemption is
-- reversed exactly once (redemption row deleted + coupons.used_count
-- decremented) so the coupon becomes usable again. Guarded by the
-- status transition in cancel_order (already-cancelled orders return
-- NOT_CANCELLABLE before reaching this block) and the row lock.

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
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


  -- Release the coupon exactly once so the customer can use it again.
  if v_order.coupon_id is not null then
    delete from public.coupon_redemptions
     where coupon_id = v_order.coupon_id
       and user_id = v_order.user_id;
    if found then
      update public.coupons
         set used_count = greatest(used_count - 1, 0)
       where id = v_order.coupon_id;
    end if;
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

$func$;
