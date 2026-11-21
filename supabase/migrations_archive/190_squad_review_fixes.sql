-- 190: E2E squad static-review fixes (4 confirmed defects).
--
-- 1. register_device_token: token rotation was scoped to (user, device) only,
--    so registering one app flavor deactivated the user's tokens for every
--    other flavor on the same device. Rotation is now per (user, device, app).
-- 2. _notification_audience_for: type 'appeal' was hard-mapped to the admin
--    audience, but the same type carries receipts + decisions TO the appellant
--    (submit_appeal / decide_appeal, mig 188). Live damage: 3 appeal rows, all
--    stamped admin, including ones addressed to a customer. Removed from the
--    fixed admin list so it derives from the recipient's role, and backfilled.
-- 3. appeals_admin_read was plain is_admin(): any admin could read every
--    region's appeal text, contradicting the region-locked admin model.
--    Read access now mirrors _duty_admin_for_region semantics.
-- 4. report_delivery_refusal: the 3rd-refusal branch leaves the order in
--    'delivering', and there was no order-level dedupe, so retried reports
--    stacked refusal_events and repeated 5-day suspensions for one delivery.
--    Now one refusal report per order, enforced by a unique index.

-- ─── 1. register_device_token: app-scoped rotation ───────────────────────────

create or replace function public.register_device_token(
  p_token text, p_platform text, p_device_id text,
  p_app_version text default null, p_app text default null
) returns void
language plpgsql security definer set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_token is null or btrim(p_token) = '' then
    raise exception 'token is required';
  end if;
  if p_platform is null or btrim(p_platform) = '' then
    raise exception 'platform is required';
  end if;

  insert into public.notification_tokens
    (user_id, token, platform, device_id, app_version, app, is_active, last_seen_at)
  values
    (v_uid, p_token, p_platform, p_device_id, p_app_version, p_app, true, now())
  on conflict (user_id, token)
  do update set
    platform = excluded.platform,
    device_id = excluded.device_id,
    app_version = excluded.app_version,
    app = coalesce(excluded.app, notification_tokens.app),
    is_active = true,
    last_seen_at = now(),
    updated_at = now();

  -- Token rotation: other ACTIVE tokens of this user on the same device AND
  -- SAME APP are superseded (re-install / refresh). Other flavors on the same
  -- device keep their own tokens. Legacy untagged calls (p_app null) rotate
  -- only untagged tokens.
  if p_device_id is not null and btrim(p_device_id) <> '' then
    update public.notification_tokens
       set is_active = false, updated_at = now()
     where user_id = v_uid
       and device_id = p_device_id
       and token <> p_token
       and is_active = true
       and app is not distinct from p_app;

    -- Cross-account leak fix (189): another account's token for the SAME app
    -- on the SAME device must not keep receiving pushes after an account switch.
    if p_app is not null and btrim(p_app) <> '' then
      update public.notification_tokens
         set is_active = false, updated_at = now()
       where device_id = p_device_id
         and app = p_app
         and user_id <> v_uid
         and is_active = true;
    end if;
  end if;
end;
$func$;
grant execute on function public.register_device_token(text, text, text, text, text) to authenticated;

-- ─── 2. 'appeal' audience derives from the recipient, not a fixed admin map ──

create or replace function public._notification_audience_for(
  p_type text, p_deep_link text, p_data jsonb, p_user_id uuid
) returns text
language plpgsql stable security definer set search_path = public
as $func$
declare
  v_marker text;
  v_role text;
begin
  -- 1. explicit marker in the payload
  v_marker := lower(coalesce(
    p_data->>'target_app', p_data->>'target_role', p_data->>'audience', ''));
  if v_marker in ('customer','client','user') then return 'customer'; end if;
  if v_marker in ('driver','delivery','courier') then return 'driver'; end if;
  if v_marker in ('provider','merchant','vendor','partner') then return 'provider'; end if;
  if v_marker in ('admin','owner','super_admin','operational') then return 'admin'; end if;
  if v_marker in ('all','broadcast') then return 'all'; end if;

  -- 2. app-owned deep-link prefixes
  if p_deep_link is not null then
    if p_deep_link like '/admin%' then return 'admin'; end if;
    if p_deep_link like '/driver%' then return 'driver'; end if;
    if p_deep_link like '/provider%' or p_deep_link like '/merchant-dashboard%' then
      return 'provider';
    end if;
  end if;

  -- 3. unambiguous types. NOTE: 'appeal' is deliberately NOT here - the same
  -- type is used for admin-bound submissions AND member-bound receipts and
  -- decisions, so it must fall through to recipient-role derivation.
  if p_type in ('admin_management','approval',
                'emergency_alert','complaint_escalated','complaint_assigned',
                'chat_assigned','chat_escalated','topup_request_pending') then
    return 'admin';
  end if;
  if p_type in ('provider_profile','providerProfile') then
    return 'provider';
  end if;
  if p_type in ('promotion','reward') then
    return 'customer';
  end if;

  -- 4. recipient role
  select role into v_role from public.users where id = p_user_id;
  if v_role = 'customer' then return 'customer'; end if;
  if v_role = 'driver' then return 'driver'; end if;
  if v_role in ('merchant','provider') then return 'provider'; end if;
  if v_role in ('admin','owner','super_admin') then return 'admin'; end if;

  return 'all';
end;
$func$;
revoke all on function public._notification_audience_for(text, text, jsonb, uuid) from public, anon, authenticated;

-- Backfill: recompute only the type whose mapping changed.
update public.notifications n
   set audience = public._notification_audience_for(n.type, n.deep_link, n.data, n.user_id)
 where n.type = 'appeal';

-- ─── 3. appeals_admin_read: region-locked, mirroring _duty_admin_for_region ──

create or replace function public._appeals_admin_read_allowed(p_region_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $func$
declare
  v_role text;
begin
  if not public.is_admin() then
    return false;
  end if;
  select role into v_role from public.users where id = auth.uid();
  -- Owner sees all (final fallback of the duty chain).
  if v_role = 'owner' then
    return true;
  end if;
  -- Global admins (no region assignment rows) are the duty-chain fallback for
  -- every region, including NULL-region appeals.
  if not exists (
    select 1 from public.admin_region_assignments a where a.admin_id = auth.uid()
  ) then
    return true;
  end if;
  -- Region-assigned admins read only appeals inside their coverage; NULL-region
  -- appeals route to the fallbacks only, like _duty_admin_for_region does.
  if p_region_id is null then
    return false;
  end if;
  return public._admin_covers_region(auth.uid(), p_region_id);
end;
$func$;
-- Used directly in the appeals_admin_read policy expression: the querying role
-- must hold EXECUTE or every select on appeals errors with 42501 (verified live).
-- Safe to expose: boolean about the caller's own access only (auth.uid()-bound).
revoke all on function public._appeals_admin_read_allowed(uuid) from public, anon;
grant execute on function public._appeals_admin_read_allowed(uuid) to authenticated;

drop policy if exists appeals_admin_read on public.appeals;
create policy appeals_admin_read on public.appeals
  for select to authenticated
  using (public._appeals_admin_read_allowed(region_id));

-- ─── 4. report_delivery_refusal: one refusal report per order ────────────────

create unique index if not exists refusal_events_order_id_key
  on public.refusal_events (order_id);

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
grant execute on function public.report_delivery_refusal(uuid, text) to authenticated;
