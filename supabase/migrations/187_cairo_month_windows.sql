-- 187: Monthly allowance windows run on Africa/Cairo calendar months
-- (Egypt-only app; owner-call via main 2026-11-21). Only the month boundary
-- expression changes vs 185/186: date_trunc('month', now()) ->
-- date_trunc('month', now() at time zone 'Africa/Cairo') at time zone
-- 'Africa/Cairo' (Cairo-local month start, returned as timestamptz).

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

  -- Customer self-cancel policy (owner-confirmed 2026-11-21, mig 185):
  -- no solo-cancel once the order is out for delivery, and a MONTHLY
  -- allowance of 2 customer cancels (calendar month, UTC; further cancels
  -- go through merchant/support).
  if v_uid = v_order.user_id and not public.is_admin() then
    if v_order.status = 'delivering' then
      return jsonb_build_object('ok', false, 'code', 'OUT_FOR_DELIVERY', 'status', v_order.status);
    end if;
    if (select count(*) from public.orders
         where user_id = v_uid and cancelled_by = 'customer'
           and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 2 then
      return jsonb_build_object('ok', false, 'code', 'CANCEL_ALLOWANCE_EXHAUSTED');
    end if;
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
    perform public._wallet_credit(
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
         cancelled_by = case when v_uid = v_order.user_id then 'customer' else 'admin' end,
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

create or replace function public.add_order_items(p_order_id uuid, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_added numeric := 0;
  v_lines jsonb := '[]'::jsonb;
  v_stock_touched boolean := false;
  v_coupon public.coupons%rowtype;
  v_new_subtotal numeric;
  v_discount numeric := 0;
  v_total numeric;
  v_merchant_uid uuid;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.user_id is distinct from v_uid and not public.is_admin() then
    raise exception 'FORBIDDEN';
  end if;
  if v_order.status not in ('pending','confirmed','preparing') then
    raise exception 'ORDER_NOT_EDITABLE %', v_order.status;
  end if;
  if v_order.payment_status = 'paid' then
    raise exception 'ORDER_ALREADY_PAID';
  end if;
  -- Monthly edit allowance (mig 185): 3 edits per calendar month (UTC).
  if v_uid = v_order.user_id and not public.is_admin() then
    if (select count(*) from public.order_edit_events
         where user_id = v_uid
           and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 3 then
      raise exception 'EDIT_ALLOWANCE_EXHAUSTED';
    end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_ITEMS';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty < 1 or v_qty > 50 then
      raise exception 'INVALID_QUANTITY';
    end if;
    select * into v_product from public.products
     where id = (v_item->>'product_id')::uuid and merchant_id = v_order.merchant_id;
    if not found then
      raise exception 'PRODUCT_NOT_FOUND %', v_item->>'product_id';
    end if;
    if v_product.is_available is not true then
      raise exception 'PRODUCT_UNAVAILABLE %', coalesce(v_product.name_ar, v_product.name);
    end if;
    if v_product.stock_quantity is not null then
      update public.products set stock_quantity = stock_quantity - v_qty
       where id = v_product.id and stock_quantity >= v_qty;
      if not found then
        raise exception 'INSUFFICIENT_STOCK %', coalesce(v_product.name_ar, v_product.name);
      end if;
      v_stock_touched := true;
    end if;
    v_added := v_added + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'product_name', coalesce(v_product.name_ar, v_product.name),
      'quantity', v_qty,
      'unit_price', v_product.price,
      'total_price', v_product.price * v_qty);
  end loop;

  v_new_subtotal := v_order.subtotal + v_added;

  if v_order.coupon_id is not null then
    select * into v_coupon from public.coupons where id = v_order.coupon_id;
    if found then
      if v_coupon.discount_type = 'percentage' then
        v_discount := round(v_new_subtotal * v_coupon.discount_value / 100.0, 2);
      else
        v_discount := v_coupon.discount_value;
      end if;
      if v_coupon.maximum_discount is not null then
        v_discount := least(v_discount, v_coupon.maximum_discount);
      end if;
      v_discount := least(v_discount, v_new_subtotal);
    else
      v_discount := v_order.discount;
    end if;
  else
    v_discount := coalesce(v_order.discount, 0);
  end if;

  v_total := greatest(v_new_subtotal + coalesce(v_order.delivery_fee,0) - v_discount, 0);

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
  select p_order_id, (l->>'product_id')::uuid, l->>'product_name',
         (l->>'quantity')::int, (l->>'unit_price')::numeric, (l->>'total_price')::numeric
    from jsonb_array_elements(v_lines) l;

  update public.orders
     set subtotal = v_new_subtotal,
         discount = v_discount,
         total_amount = v_total,
         items = coalesce(items, '[]'::jsonb) || v_lines,
         stock_decremented = stock_decremented or v_stock_touched,
         updated_at = now()
   where id = p_order_id;

  insert into public.order_edit_events (order_id, user_id, added_subtotal)
  values (p_order_id, v_order.user_id, v_added);

  select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
  if v_merchant_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_merchant_uid,
            'تعديل على طلب قيد التجهيز',
            'أضاف العميل منتجات إلى الطلب رقم ' || right(p_order_id::text, 6) ||
              '. الإجمالي الجديد: ' || v_total::text || ' جنيه.',
            'order',
            jsonb_build_object('order_id', p_order_id, 'event', 'items_added',
                               'added_subtotal', v_added, 'total_amount', v_total),
            true);
  end if;

  return jsonb_build_object(
    'ok', true, 'order_id', p_order_id,
    'added_subtotal', v_added,
    'subtotal', v_new_subtotal,
    'discount', v_discount,
    'total_amount', v_total);
end;
$$;
grant execute on function public.add_order_items(uuid, jsonb) to authenticated;

create or replace function public.report_delivery_refusal(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_driver public.drivers%rowtype;
  v_count int;
  v_merchant_uid uuid;
  v_short text;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  select * into v_driver from public.drivers where id = v_order.driver_id;
  if v_driver.user_id is distinct from v_uid and not public.is_admin() then
    raise exception 'FORBIDDEN';
  end if;
  if v_order.status <> 'delivering' then
    raise exception 'NOT_OUT_FOR_DELIVERY %', v_order.status;
  end if;

  -- Lifetime stat kept for records; the policy window is MONTHLY (mig 185).
  update public.users set refusal_count = refusal_count + 1
   where id = v_order.user_id;
  select count(*) + 1 into v_count
    from public.orders
   where user_id = v_order.user_id
     and cancelled_by = 'customer_refusal'
     and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';

  if v_order.stock_decremented then
    update public.products p
       set stock_quantity = p.stock_quantity + oi.quantity
      from public.order_items oi
     where oi.order_id = v_order.id
       and p.id = oi.product_id
       and p.stock_quantity is not null;
  end if;

  if v_order.payment_status = 'paid' then
    perform public._wallet_credit(
      p_user_id := v_order.user_id,
      p_amount := v_order.total_amount,
      p_description := 'Delivery refusal refund for order ' || p_order_id::text,
      p_reference_type := 'refund',
      p_reference_id := p_order_id
    );
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_reason = coalesce(p_reason, 'رفض الاستلام'),
         cancelled_by = 'customer_refusal',
         cancelled_at = now(),
         payment_status = case when payment_status = 'paid' then 'refunded' else payment_status end,
         stock_decremented = false,
         driver_id = null,
         updated_at = now()
   where id = v_order.id;

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = 'system',
         cancellation_reason = coalesce(p_reason, 'Customer refused delivery')
   where order_id = v_order.id
     and status not in ('completed', 'cancelled');

  v_short := right(v_order.id::text, 6);
  select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
  if v_merchant_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_merchant_uid,
            'العميل رفض استلام الطلب',
            'تم إلغاء الطلب رقم ' || v_short || ' بسبب رفض العميل الاستلام.',
            'order',
            jsonb_build_object('order_id', v_order.id, 'status', 'cancelled',
                               'reason', 'customer_refusal'),
            true);
  end if;

  if v_count >= 3 then
    update public.users set account_status = 'suspended'
     where id = v_order.user_id and account_status = 'active';
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك',
            'تم إيقاف حسابك بسبب تكرار رفض استلام الطلبات هذا الشهر (' || v_count || ' مرات). تواصل مع الدعم لمراجعة الحساب.',
            'account',
            jsonb_build_object('event', 'refusal_suspension', 'refusal_count', v_count),
            true);
    return jsonb_build_object('ok', true, 'action', 'account_suspended', 'refusal_count', v_count);
  else
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تحذير ' || v_count || ' من 2 هذا الشهر: رفض استلام الطلب',
            'تم تسجيل رفضك استلام الطلب رقم ' || v_short || '. رفض الاستلام مرة أخرى بعد تحذيرين يؤدي إلى إيقاف الحساب.',
            'account',
            jsonb_build_object('event', 'refusal_warning', 'refusal_count', v_count),
            true);
    return jsonb_build_object('ok', true, 'action', 'warning', 'refusal_count', v_count);
  end if;
end;
$$;
grant execute on function public.report_delivery_refusal(uuid, text) to authenticated;

create or replace function public._driver_delay_redispatch(
  p_ride_id uuid,
  p_reason text,
  p_reported_by text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_ride public.rides%rowtype;
  v_driver_id uuid;
  v_driver_uid uuid;
  v_count int;
  v_within boolean;
  v_cfg public.platform_settings%rowtype;
  v_allowance int;
  v_apology numeric;
  v_dispatch jsonb;
  v_offered boolean;
  v_customer uuid;
  v_merchant_uid uuid;
  v_short text;
  v_prior_apologies int;
  v_reason text;
begin
  select * into v_ride from public.rides where id = p_ride_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'RIDE_NOT_FOUND');
  end if;
  -- Goods already picked up: custody path (report_delivery_incident), not delay.
  if v_ride.status not in ('matched', 'arrived') then
    return jsonb_build_object('ok', false, 'code', 'INVALID_STATE', 'status', v_ride.status);
  end if;
  if v_ride.driver_id is null then
    return jsonb_build_object('ok', false, 'code', 'NO_DRIVER');
  end if;
  v_driver_id := v_ride.driver_id;
  select user_id into v_driver_uid from public.drivers where id = v_driver_id;
  v_reason := coalesce(nullif(trim(p_reason), ''), 'عطل فني');
  v_short := right(coalesce(v_ride.order_id::text, p_ride_id::text), 6);

  select * into v_cfg from public._settlement_settings();
  v_allowance := greatest(coalesce(v_cfg.driver_delay_monthly_allowance, 3), 0);
  v_apology := greatest(coalesce(v_cfg.delay_apology_discount_egp, 5), 0);

  -- Monthly allowance (calendar month, UTC).
  select count(*) + 1 into v_count
    from public.driver_delay_events
   where driver_id = v_driver_id
     and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';
  v_within := v_count <= v_allowance;

  -- Release the driver and re-offer (mirrors the 146 driver-cancel redispatch).
  update public.ride_requests set status = 'cancelled', responded_at = now()
   where ride_id = p_ride_id and driver_id = v_driver_id and status = 'accepted';
  update public.ride_requests set status = 'expired', responded_at = now()
   where ride_id = p_ride_id and status = 'offered';
  update public.driver_locations set ride_id = null where ride_id = p_ride_id;
  update public.rides
     set status = 'searching', driver_id = null,
         cancellation_reason = 'driver_delay: ' || v_reason,
         cancelled_by = 'driver'
   where id = p_ride_id;
  insert into public.trip_events (ride_id, event_type, actor)
  values (p_ride_id, 'driver_delay_redispatch', 'driver');

  v_dispatch := public._dispatch_delivery_internal(p_ride_id, 25.0, 15);
  v_offered := coalesce((v_dispatch->>'success')::boolean, false);

  update public.orders
     set driver_id = null,
         dispatch_status = case when v_offered then 'OFFERED' else 'PENDING_DISPATCH' end,
         updated_at = now()
   where id = v_ride.order_id
     and status not in ('cancelled', 'delivered');

  -- One apology credit per order, even across repeated delay events.
  select count(*) into v_prior_apologies
    from public.driver_delay_events
   where order_id is not null
     and order_id = v_ride.order_id
     and apology_amount > 0;

  insert into public.driver_delay_events
    (ride_id, order_id, driver_id, reported_by, reason,
     within_allowance, monthly_count, apology_amount)
  values
    (p_ride_id, v_ride.order_id, v_driver_id, p_reported_by, v_reason,
     v_within, v_count,
     case when v_prior_apologies = 0 then v_apology else 0 end);

  -- Customer apology: wallet credit funded from the platform ops share of
  -- the order (see header) + Egyptian-Arabic apology naming the breakdown.
  if v_ride.order_id is not null and v_prior_apologies = 0 then
    select user_id into v_customer from public.orders where id = v_ride.order_id;
    if v_customer is not null then
      if v_apology > 0 then
        perform public._wallet_credit(
          p_user_id := v_customer,
          p_amount := v_apology,
          p_description := 'Delay apology credit for order ' || v_ride.order_id::text,
          p_reference_type := 'delay_apology',
          p_reference_id := v_ride.order_id
        );
      end if;
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_customer,
              'نعتذر عن التأخير 🙏',
              'طلبك رقم ' || v_short || ' اتأخر بسبب عطل فني عند الكابتن السابق. المطعم ملوش أي ذنب، والموضوع مش مقصود مننا. كابتن تاني في الطريق لطلبك دلوقتي' ||
                case when v_apology > 0
                     then '، وأضفنا ' || trim(to_char(v_apology, 'FM999990.##')) || ' جنيه اعتذار في محفظتك.'
                     else '.' end,
              'order',
              jsonb_build_object('order_id', v_ride.order_id, 'event', 'driver_delay_apology',
                                 'apology_amount', v_apology),
              true);
    end if;
  end if;

  -- The late driver is excused: no deduction either way. Beyond the monthly
  -- allowance the event is flagged for ops (no automatic penalty - owner to
  -- decide the consequence).
  if v_driver_uid is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_driver_uid,
            'تم إعفاؤك من الطلب',
            'سجلنا تأخيرك عن استلام الطلب رقم ' || v_short || ' (' || v_reason || '). تم إعفاؤك من الطلب بدون أي خصم' ||
              case when v_within
                   then ' - سماحية رقم ' || v_count || ' من ' || v_allowance || ' هذا الشهر.'
                   else '، لكن ده تأخيرك رقم ' || v_count || ' هذا الشهر وفوق السماحية (' || v_allowance || ')، وهيتراجع من فريق العمليات.' end,
            'order',
            jsonb_build_object('ride_id', p_ride_id, 'event', 'driver_delay_excused',
                               'within_allowance', v_within, 'monthly_count', v_count),
            true);
  end if;

  if not v_within then
    insert into public.complaints
      (order_id, ride_id, complainant_id, respondent_id, reporter_id,
       complaint_type, category, subject, description, status, priority)
    values
      (v_ride.order_id, p_ride_id, v_driver_uid, v_driver_uid, v_driver_uid,
       'driver', 'delay_allowance_exceeded',
       'تجاوز سماحية التأخير الشهرية',
       'الكابتن تجاوز سماحية التأخير الشهرية (' || v_count || ' من ' || v_allowance ||
         ') على الطلب رقم ' || v_short || '. السبب المسجل: ' || v_reason || '.',
       'pending', 'high');
  end if;

  -- Merchant heads-up: the order is moving to another captain.
  if v_ride.merchant_id is not null then
    select owner_user_id into v_merchant_uid from public.merchants where id = v_ride.merchant_id;
    if v_merchant_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'إعادة توزيع الطلب على كابتن آخر',
              'الكابتن السابق اتأخر عن استلام الطلب رقم ' || v_short || ' (' || v_reason || ') وتم إعفاؤه. الطلب معروض دلوقتي على كباتن آخرين.',
              'order',
              jsonb_build_object('order_id', v_ride.order_id, 'event', 'driver_delay_redispatch'),
              true);
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'redispatching',
    'offered', v_offered,
    'within_allowance', v_within,
    'monthly_count', v_count,
    'apology_amount', case when v_prior_apologies = 0 then v_apology else 0 end);
end;
$func$;
revoke all on function public._driver_delay_redispatch(uuid, text, text) from public, anon, authenticated;
