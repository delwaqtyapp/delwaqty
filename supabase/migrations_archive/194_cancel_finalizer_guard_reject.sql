-- 194: cancellation finalizer + merchant reject + guard rebuild + incident region lock.
--
-- Ships together because the pieces interlock:
--   _finalize_order_cancel  (shared stock/coupon/refund/close-out)
--   cancel_order + report_delivery_refusal now route through it (no behavior change)
--   merchant_reject_order   (the dashboard Reject button's real backend)
--   resolve_delivery_incident / list_delivery_incidents (region lock + finalization)
--   orders_guard_sensitive  (strict allowlist + transition pairs)
--
-- Design decision (owner-blanket policy "customer never pays for driver or
-- platform failures"): incident-cancellations do NOT restock (goods may be
-- unsellable) but DO refund + release coupon; merchant rejects restock
-- (kitchen barely started) + refund + release coupon.

-- 1. Shared order-cancellation finalizer. Single owner of: aggregated stock
--    restore (opt), coupon release (opt), wallet refund (opt), order close-out
--    fields, and linked-ride cancellation. Idempotent on terminal orders.
--    Caller contexts: cancel_order (customer/admin: restock+refund+coupon),
--    report_delivery_refusal (restock+refund+coupon), merchant_reject_order
--    (restock+refund+coupon), resolve_delivery_incident (NO restock - goods in
--    an incident may not return to sellable stock; refund+coupon DO happen).
create or replace function public._finalize_order_cancel(
  p_order_id uuid, p_actor text, p_reason text,
  p_restock boolean default true, p_refund boolean default true,
  p_release_coupon boolean default true, p_ride_cancelled_by text default 'system'
) returns void
language plpgsql security definer set search_path = public
as $func$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.status in ('delivered','cancelled') then
    return; -- already closed: nothing to finalize
  end if;

  if p_restock and v_order.stock_decremented then
    update public.products p
       set stock_quantity = p.stock_quantity + s.qty
      from (select oi.product_id, sum(oi.quantity) as qty
              from public.order_items oi
             where oi.order_id = p_order_id
             group by oi.product_id) s
     where p.id = s.product_id
       and p.stock_quantity is not null;
  end if;

  if p_release_coupon and v_order.coupon_id is not null then
    delete from public.coupon_redemptions
     where coupon_id = v_order.coupon_id
       and user_id = v_order.user_id;
    if found then
      update public.coupons
         set used_count = greatest(used_count - 1, 0)
       where id = v_order.coupon_id;
    end if;
  end if;

  if p_refund and v_order.payment_status = 'paid' then
    perform public._wallet_credit(
      p_user_id := v_order.user_id,
      p_amount := v_order.total_amount,
      p_description := 'Refund for cancelled order ' || p_order_id::text,
      p_reference_type := 'refund',
      p_reference_id := p_order_id
    );
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_reason = p_reason,
         cancelled_by = p_actor,
         cancelled_at = now(),
         payment_status = case when p_refund and payment_status = 'paid' then 'refunded' else payment_status end,
         stock_decremented = false,
         driver_id = null,
         updated_at = now()
   where id = p_order_id;

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = p_ride_cancelled_by,
         cancellation_reason = p_reason
   where order_id = p_order_id
     and status not in ('completed', 'cancelled');
end;
$func$;
revoke all on function public._finalize_order_cancel(uuid, text, text, boolean, boolean, boolean, text) from public, anon, authenticated;

-- 2. Region-scope helper mirroring the 190 appeals model: owner + global
--    admins (no region rows) act everywhere; region admins only in covered
--    regions; NULL region falls back to owner/global only.
create or replace function public._admin_scope_allows(p_region_id uuid)
returns boolean
language plpgsql stable security definer set search_path = public, pg_temp
as $func$
declare
  v_role text;
begin
  if not public.is_admin() then
    return false;
  end if;
  select role into v_role from public.users where id = auth.uid();
  if v_role = 'owner' then
    return true;
  end if;
  if not exists (select 1 from public.admin_region_assignments a where a.admin_id = auth.uid()) then
    return true;
  end if;
  if p_region_id is null then
    return false;
  end if;
  return public._admin_covers_region(auth.uid(), p_region_id);
end;
$func$;
revoke all on function public._admin_scope_allows(uuid) from public, anon;
grant execute on function public._admin_scope_allows(uuid) to authenticated;

create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_suspend_after boolean := false;
  v_refunded boolean := false;
  v_actor uuid;
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
    -- 188: the 3rd monthly cancel EXECUTES and triggers a 5-day suspension
    -- (appealable); it is no longer blocked.
    if (select count(*) from public.orders
         where user_id = v_uid and cancelled_by = 'customer'
           and cancelled_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo') >= 2 then
      v_suspend_after := true;
    end if;
  end if;

  -- 194: shared finalizer owns stock/coupon/refund/order+ride cancellation.
  v_refunded := v_order.payment_status = 'paid';
  perform public._finalize_order_cancel(
    p_order_id,
    case when v_uid = v_order.user_id then 'customer' else 'admin' end,
    coalesce(p_reason, v_order.cancelled_reason, 'Order cancelled'),
    true, true, true,
    case when v_uid is distinct from v_order.user_id then 'system' else 'rider' end);

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

  -- 188: suspension after the 3rd monthly cancel (moderation engine owns
  -- account_status; appeal via submit_appeal routes to the region duty admin).
  if v_suspend_after then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'تجاوز سماحية الإلغاء الشهرية (إلغاء ثالث خلال شهر واحد)', 5);
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك 5 أيام',
            'تم تنفيذ إلغاء الطلب، لكن ده ثالث إلغاء ليك هذا الشهر (السماحية: 2). اتوقف حسابك 5 أيام. لو عندك ظرف، قدّم التماس من التطبيق والمسؤول عن منطقتك هيراجعه.',
            'account',
            jsonb_build_object('event', 'cancel_suspension', 'order_id', v_order.id,
                               'duration_days', 5),
            true);
    return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled',
                              'refunded', v_refunded, 'suspended', true,
                              'suspension_days', 5);
  end if;

  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled', 'refunded', v_refunded);
end;


$func$;

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
  v_actor uuid;
  v_ride_id uuid;
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

  -- One refusal report per order. The 3rd-refusal branch below intentionally
  -- leaves the order in 'delivering'; without this guard every retried report
  -- stacked another refusal_event and re-executed the 5-day suspension.
  if exists (select 1 from public.refusal_events where order_id = p_order_id) then
    return jsonb_build_object('ok', true, 'action', 'already_reported',
                              'order_id', p_order_id);
  end if;

  -- Lifetime stat kept for records; the policy window is MONTHLY (mig 185),
  -- counted from refusal_events (188) so that refused-but-uncancelled orders
  -- on the 3rd-refusal path still count.
  update public.users set refusal_count = refusal_count + 1
   where id = v_order.user_id;
  insert into public.refusal_events (user_id, order_id)
  values (v_order.user_id, v_order.id);
  select count(*) into v_count
    from public.refusal_events
   where user_id = v_order.user_id
     and created_at >= date_trunc('month', now() at time zone 'Africa/Cairo') at time zone 'Africa/Cairo';

  -- 188: the 3rd monthly refusal is NOT processed as a cancellation - the
  -- order must still be received. The 5-day suspension executes at the
  -- driver's report; ops resolves the in-flight order via the incident flow.
  if v_count >= 3 then
    v_actor := coalesce(
      (select id from public.users where role = 'owner' order by created_at limit 1),
      v_order.user_id);
    perform public._member_exec_sanction(
      v_actor, v_order.user_id, 'suspension',
      'رفض استلام الطلب للمرة الثالثة خلال شهر واحد', 5);

    select id into v_ride_id from public.rides
     where order_id = v_order.id and status not in ('completed', 'cancelled')
     order by created_at desc limit 1;
    if v_ride_id is not null then
      insert into public.delivery_incidents (ride_id, order_id, reporter_user_id, reporter_role, kind, note)
      values (v_ride_id, v_order.id, v_uid, 'driver', 'final_refusal_suspension',
              coalesce(p_reason, 'رفض الاستلام للمرة الثالثة - العميل موقوف 5 أيام والطلب يحتاج حسم'));
    end if;

    v_short := right(v_order.id::text, 6);
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_order.user_id,
            'تم إيقاف حسابك 5 أيام',
            'ده تالت رفض استلام منك هذا الشهر. اتوقف حسابك 5 أيام من لحظة بلاغ الكابتن. طلبك رقم ' || v_short || ' لازم يتسلم، والدعم هيحسم الموضوع معاك. تقدر تقدّم التماس من التطبيق والمسؤول عن منطقتك هيراجعه.',
            'account',
            jsonb_build_object('event', 'refusal_suspension', 'refusal_count', v_count,
                               'order_id', v_order.id, 'duration_days', 5),
            true);

    select owner_user_id into v_merchant_uid from public.merchants where id = v_order.merchant_id;
    if v_merchant_uid is not null then
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_merchant_uid,
              'العميل رفض الاستلام للمرة الثالثة',
              'الطلب رقم ' || v_short || ': تم إيقاف العميل 5 أيام، والدعم هيحسم الطلب (استلام إجباري أو إرجاع للمطعم).',
              'order',
              jsonb_build_object('order_id', v_order.id, 'event', 'final_refusal'),
              true);
    end if;

    return jsonb_build_object('ok', true, 'action', 'account_suspended',
                              'refusal_count', v_count, 'suspension_days', 5,
                              'order_cancelled', false);
  end if;

  -- 194: shared finalizer (coupon release included since 193's policy).
  perform public._finalize_order_cancel(
    p_order_id, 'customer_refusal', coalesce(p_reason, 'رفض الاستلام'),
    true, true, true, 'system');

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

  insert into public.notifications (user_id, title, body, type, data, send_push)
  values (v_order.user_id,
          'تحذير ' || v_count || ' من 2 هذا الشهر: رفض استلام الطلب',
          'تم تسجيل رفضك استلام الطلب رقم ' || v_short || '. رفض الاستلام مرة أخرى بعد تحذيرين يؤدي إلى إيقاف الحساب 5 أيام، وطلبك القادم لازم يتسلم.',
          'account',
          jsonb_build_object('event', 'refusal_warning', 'refusal_count', v_count),
          true);
  return jsonb_build_object('ok', true, 'action', 'warning', 'refusal_count', v_count);
end;
$$;

-- 4. merchant_reject_order: the merchant dashboard's Reject button. Pending
--    orders only, merchant owner of the store only, full cancel fanout via the
--    finalizer, cancelled_by='merchant' so the CUSTOMER's monthly cancellation
--    allowance is never touched (customer is innocent when the merchant rejects).
create or replace function public.merchant_reject_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
  v_order public.orders%rowtype;
  v_short text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;
  if not public.is_merchant_owner(v_order.merchant_id) then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  if v_order.status <> 'pending' then
    return jsonb_build_object('ok', false, 'code', 'NOT_PENDING', 'status', v_order.status);
  end if;

  perform public._finalize_order_cancel(
    p_order_id, 'merchant',
    coalesce(nullif(btrim(p_reason), ''), 'رفض المتجر الطلب'),
    true, true, true, 'system');

  v_short := right(p_order_id::text, 6);
  insert into public.notifications (user_id, title, body, type, data, send_push)
  values (v_order.user_id,
          'المتجر اعتذر عن طلبك',
          'المتجر اعتذر عن تنفيذ الطلب رقم ' || v_short || '.' ||
            case when v_order.payment_status = 'paid'
                 then ' رجّعنا فلوسك كاملة في محفظتك.' else '' end ||
            case when v_order.coupon_id is not null
                 then ' والكوبون اللي استخدمته رجعلك تاني.' else '' end,
          'order',
          jsonb_build_object('order_id', p_order_id, 'status', 'cancelled',
                             'reason', 'merchant_rejected'),
          true);
  return jsonb_build_object('ok', true, 'code', 'OK', 'status', 'cancelled');
end;
$func$;
grant execute on function public.merchant_reject_order(uuid, text) to authenticated;


-- 5. resolve_delivery_incident: region-scoped + real finalization.
create or replace function public.resolve_delivery_incident(p_incident_id uuid, p_resolution text, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp
as $function$
declare
  i public.delivery_incidents%rowtype;
  v_region uuid;
begin
  if not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'forbidden');
  end if;
  if p_resolution not in ('redelivered','returned_to_merchant','cancelled','dismissed') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_resolution');
  end if;
  select * into i from public.delivery_incidents where id = p_incident_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if i.status = 'resolved' then
    return jsonb_build_object('ok', false, 'reason', 'already_resolved');
  end if;

  -- Region lock (194): the incident's order customer's region governs.
  select u.region_id into v_region
    from public.orders o join public.users u on u.id = o.user_id
   where o.id = i.order_id;
  if not public._admin_scope_allows(v_region) then
    return jsonb_build_object('ok', false, 'reason', 'forbidden_region');
  end if;

  -- Returned goods end the ride and the order; a plain cancel of the order
  -- closes it out. Redelivery keeps the ride alive for the driver to finish.
  -- 194: incident-cancels do NOT restock (goods may be unsellable) but DO
  -- refund and release the coupon, and clear the driver + ride.
  if p_resolution in ('returned_to_merchant','cancelled') then
    perform public._finalize_order_cancel(
      i.order_id, 'incident', 'incident: ' || p_resolution,
      false, true, true, 'system');
  end if;

  update public.delivery_incidents
     set status = 'resolved', resolution = p_resolution,
         note = coalesce(nullif(btrim(p_note), ''), note),
         resolved_by = auth.uid(), resolved_at = now()
   where id = p_incident_id;
  insert into trip_events (ride_id, event_type, actor)
    values (i.ride_id, 'incident_resolved_' || p_resolution, 'support');
  return jsonb_build_object('ok', true, 'resolution', p_resolution);
end;
$function$;

create or replace function public.list_delivery_incidents(p_status text default 'open', p_limit integer default 100, p_offset integer default 0)
returns setof delivery_incidents
language plpgsql security definer set search_path = public, pg_temp
as $function$
begin
  if not public.is_admin() then
    raise exception 'forbidden';
  end if;
  return query
    select i.* from public.delivery_incidents i
    where (p_status is null or i.status = p_status)
      and public._admin_scope_allows(
            (select u.region_id from public.orders o
              join public.users u on u.id = o.user_id
             where o.id = i.order_id))
    order by i.created_at desc
    limit least(coalesce(p_limit, 100), 500) offset coalesce(p_offset, 0);
end;
$function$;


-- 7. orders_guard_sensitive rebuild: strict client allowlist (status +
--    updated_at only; every other column frozen for direct client writes,
--    including stock_decremented and cancelled_by which the old denylist
--    missed) + explicit forward-only kitchen transition pairs (no skips, no
--    resurrection from delivered/cancelled).
create or replace function public.orders_guard_sensitive()
 returns trigger
 language plpgsql
as $function$
declare
  v_merchant_owner boolean;
begin
  -- DEFINER RPCs and backend run as the table owner.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if public._is_active_admin_uid(auth.uid()) then
    return new;
  end if;

  -- Freeze everything except status + updated_at for ALL direct client writes.
  if (to_jsonb(new) - 'status' - 'updated_at') is distinct from
     (to_jsonb(old) - 'status' - 'updated_at') then
    raise exception 'order fields are managed by the order RPCs';
  end if;

  v_merchant_owner := public.is_merchant_owner(old.merchant_id);

  if new.status is distinct from old.status then
    if not v_merchant_owner then
      raise exception 'order status is managed by the order RPCs';
    end if;
    -- Forward-only kitchen pairs; delivered/cancelled are terminal here;
    -- completion via merchant_complete_order, cancellation via RPCs.
    if not (
      (old.status = 'pending'   and new.status = 'confirmed') or
      (old.status = 'confirmed' and new.status = 'preparing') or
      (old.status = 'preparing' and new.status = 'ready') or
      (old.status = 'ready'     and new.status = 'delivering')
    ) then
      raise exception 'unsupported order status transition: % -> %', old.status, new.status;
    end if;
  end if;

  return new;
end;
$function$;

-- 8. cancel_ride_lifecycle: rider (customer) cancels through the delivery
--    screen now run the FULL cancel_order finalization - ladder count +
--    suspension-after, stock, coupon, refund, cancelled_by='customer',
--    notifications - instead of the bare ride cancel whose
--    sync_linked_delivery_order trigger flipped the order with none of it.
--    Driver-before-pickup redispatch branch unchanged.
CREATE OR REPLACE FUNCTION public.cancel_ride_lifecycle(p_ride_id uuid, p_by text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  r rides%ROWTYPE;
  v_is_rider BOOLEAN;
  v_is_driver BOOLEAN;
  v_driver_id uuid;
  v_dispatch jsonb;
  v_offered boolean;
  v_cancel jsonb;
BEGIN
  SELECT * INTO r FROM rides WHERE id = p_ride_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  v_is_rider := (r.rider_id = auth.uid());
  SELECT id INTO v_driver_id FROM drivers WHERE user_id = auth.uid() AND id = r.driver_id;
  v_is_driver := (v_driver_id IS NOT NULL);
  IF auth.uid() IS NULL OR NOT (COALESCE(v_is_rider,false) OR COALESCE(v_is_driver,false)) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;
  IF r.status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_transition');
  END IF;

  -- Goods are physically with the driver: a plain cancellation would erase
  -- custody. This is an incident, not a cancel.
  IF r.status = 'inTrip' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'in_custody');
  END IF;

  -- Driver backs out before pickup: keep the customer's delivery alive and
  -- re-offer it to other drivers automatically.
  IF v_is_driver AND r.status IN ('matched','arrived') THEN
    UPDATE ride_requests SET status = 'cancelled', responded_at = NOW()
      WHERE ride_id = p_ride_id AND driver_id = v_driver_id AND status = 'accepted';
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND status = 'offered';
    UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;
    UPDATE rides SET status = 'searching', driver_id = NULL,
      cancellation_reason = p_reason, cancelled_by = 'driver'
      WHERE id = p_ride_id;
    INSERT INTO trip_events (ride_id, event_type, actor)
      VALUES (p_ride_id, 'driver_cancelled_redispatch', 'driver');

    v_dispatch := public._dispatch_delivery_internal(p_ride_id, 25.0, 15);
    v_offered := COALESCE((v_dispatch->>'success')::boolean, false);

    UPDATE public.orders
       SET driver_id = NULL,
           dispatch_status = CASE WHEN v_offered THEN 'OFFERED' ELSE 'PENDING_DISPATCH' END,
           updated_at = now()
     WHERE id = r.order_id
       AND status NOT IN ('cancelled','delivered');

    RETURN jsonb_build_object('success', true, 'status', 'redispatching',
      'offered', v_offered,
      'dispatch_reason', v_dispatch->>'reason');
  END IF;

  -- 194: a customer (rider) cancel with a linked order goes through
  -- cancel_order so the monthly ladder, finalization and notifications all
  -- fire exactly as on the orders screen. cancel_order's finalizer also
  -- cancels this ride (same order_id), so only the peripheral cleanup stays.
  IF v_is_rider AND r.order_id IS NOT NULL THEN
    v_cancel := public.cancel_order(r.order_id, p_reason);
    IF NOT COALESCE((v_cancel->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('success', false,
        'reason', lower(coalesce(v_cancel->>'code', 'cancel_failed')),
        'detail', v_cancel);
    END IF;
    UPDATE ride_requests SET status = 'expired', responded_at = NOW()
      WHERE ride_id = p_ride_id AND status = 'offered';
    UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;
    INSERT INTO trip_events (ride_id, event_type, actor)
      VALUES (p_ride_id, 'cancelled', 'rider');
    RETURN jsonb_build_object('success', true, 'status', 'cancelled');
  END IF;

  UPDATE rides SET status = 'cancelled', cancelled_at = NOW(),
    cancellation_reason = p_reason,
    cancelled_by = CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END
  WHERE id = p_ride_id;

  UPDATE ride_requests SET status = 'expired', responded_at = NOW()
    WHERE ride_id = p_ride_id AND status = 'offered';
  UPDATE driver_locations SET ride_id = NULL WHERE ride_id = p_ride_id;

  INSERT INTO trip_events (ride_id, event_type, actor)
    VALUES (p_ride_id, 'cancelled', CASE WHEN v_is_driver THEN 'driver' ELSE 'rider' END);
  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$function$;
