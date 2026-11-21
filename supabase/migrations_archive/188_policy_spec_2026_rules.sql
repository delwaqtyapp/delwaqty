-- 188: Owner policy spec 2026-11-21 3:14 PM voice note (relayed via main,
-- picks settled): delay compensation redesign, cancellation suspension,
-- refusal suspension + appeals, admin-region duty routing.
--
-- a) Delay compensation (replaces the 185 flat-EGP apology): the customer
--    gets a gift of 7% of the order value, platform-funded, framed as
--    appreciation for the customer's and restaurant's patience; the delayed
--    driver keeps the no-deduction exemption (185); the platform takes NO
--    commission from the replacement driver on that order (waiver in
--    _record_delivery_earnings / _record_order_settlement).
--    platform_settings.delay_apology_discount_egp is deprecated (ignored);
--    the rate is delay_apology_percent (default 7).
-- b) Cancellations: 2/month; the 3rd monthly cancel EXECUTES and the account
--    gets a 5-day suspension via the moderation engine (sanctions), with an
--    in-app appeal route to the region's duty admin.
-- c) Refusals: warnings on 1st and 2nd; on the 3rd the 5-day suspension
--    executes when the driver reports the refusal (the interactive
--    "must receive this order" pre-warning is app-side work). Appeal route
--    same as (b).
-- d) Appeals: appeals table + submit_appeal / decide_appeal, routed to the
--    duty admin for the member's region (_duty_admin_for_region):
--    assigned-and-available admin, else nearest ancestor-region admin, else
--    any available global admin, else owner. Admin availability is
--    admin_availability (default available), toggled via
--    set_admin_availability.
-- e) Suspension gets teeth: create_order rejects suspended/banned customers.
-- f) Expired sanctions lift automatically: _lift_expired_member_sanctions
--    every 15 minutes via pg_cron (recomputes derived account_status).

alter table public.platform_settings
  add column if not exists delay_apology_percent numeric not null default 7;

-- ─── Admin availability + appeals ─────────────────────────────

create table if not exists public.admin_availability (
  admin_id uuid primary key references public.users(id) on delete cascade,
  is_available boolean not null default true,
  note text,
  updated_at timestamptz not null default now()
);
alter table public.admin_availability enable row level security;
revoke all on public.admin_availability from anon, authenticated;
grant select on public.admin_availability to authenticated;

create table if not exists public.appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  sanction_id uuid not null references public.sanctions(id),
  message text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  region_id uuid references public.regions(id),
  assigned_admin_id uuid references public.users(id),
  decided_by uuid references public.users(id),
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now()
);
alter table public.appeals enable row level security;
revoke all on public.appeals from anon, authenticated;
grant select on public.appeals to authenticated;
drop policy if exists appeals_own_read on public.appeals;
create policy appeals_own_read on public.appeals
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists appeals_admin_read on public.appeals;
create policy appeals_admin_read on public.appeals
  for select to authenticated using (public.is_admin());

-- Does p_admin's assignment cover p_region (031 semantics)?
create or replace function public._admin_covers_region(p_admin uuid, p_region uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $func$
  select exists (
    select 1 from public.admin_region_assignments a
    where a.admin_id = p_admin
      and (
        (a.scope = 'self' and a.region_id = p_region)
        or (a.scope = 'descendants' and p_region in (
          with recursive covered as (
            select id from public.regions where id = a.region_id
            union all
            select r.id from public.regions r join covered c on r.parent_region_id = c.id
          )
          select id from covered
        ))
      )
  );
$func$;
revoke all on function public._admin_covers_region(uuid, uuid) from public, anon, authenticated;

-- Duty admin for a region: assigned + available (nearest ancestor wins),
-- then any available unscoped admin, then the owner. NULL region skips
-- straight to the fallbacks.
create or replace function public._duty_admin_for_region(p_region_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $func$
declare
  v_admin uuid;
begin
  if p_region_id is not null then
    with recursive chain as (
      select id, parent_region_id, 0 as depth from public.regions where id = p_region_id
      union all
      select r.id, r.parent_region_id, c.depth + 1
        from public.regions r join chain c on r.id = c.parent_region_id
    )
    select a.admin_id into v_admin
      from public.admin_region_assignments a
      join chain c on a.region_id = c.id
      join public.users u on u.id = a.admin_id and u.account_status = 'active'
      left join public.admin_availability av on av.admin_id = a.admin_id
     where (a.scope = 'descendants' or (a.scope = 'self' and c.depth = 0))
       and coalesce(av.is_available, true)
     order by c.depth asc, a.created_at asc
     limit 1;
    if v_admin is not null then
      return v_admin;
    end if;
  end if;

  -- Any available admin with no region rows (global scope).
  select u.id into v_admin
    from public.users u
    left join public.admin_availability av on av.admin_id = u.id
   where u.role = 'admin' and u.account_status = 'active'
     and not exists (select 1 from public.admin_region_assignments a where a.admin_id = u.id)
     and coalesce(av.is_available, true)
   order by u.created_at asc
   limit 1;
  if v_admin is not null then
    return v_admin;
  end if;

  select id into v_admin from public.users where role = 'owner' order by created_at asc limit 1;
  return v_admin;
end;
$func$;
revoke all on function public._duty_admin_for_region(uuid) from public, anon, authenticated;

create or replace function public.set_admin_availability(p_available boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
begin
  if auth.uid() is null or not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  insert into public.admin_availability (admin_id, is_available, note, updated_at)
  values (auth.uid(), p_available, p_note, now())
  on conflict (admin_id)
  do update set is_available = excluded.is_available,
                note = excluded.note,
                updated_at = now();
  return jsonb_build_object('ok', true, 'is_available', p_available);
end;
$func$;
grant execute on function public.set_admin_availability(boolean, text) to authenticated;

-- Member submits an appeal against an active sanction; routed to the duty
-- admin of the member's region.
create or replace function public.submit_appeal(p_sanction_id uuid, p_message text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
  v_sanction public.sanctions%rowtype;
  v_region uuid;
  v_admin uuid;
  v_appeal uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  end if;
  select * into v_sanction from public.sanctions where id = p_sanction_id;
  if not found or v_sanction.target_user_id is distinct from v_uid then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;
  if not (v_sanction.is_active and v_sanction.action_status = 'active') then
    return jsonb_build_object('ok', false, 'code', 'SANCTION_NOT_ACTIVE');
  end if;
  if exists (select 1 from public.appeals
              where sanction_id = p_sanction_id and status = 'pending') then
    return jsonb_build_object('ok', false, 'code', 'APPEAL_ALREADY_PENDING');
  end if;
  v_region := public._member_region_id(v_uid);
  v_admin := public._duty_admin_for_region(v_region);
  insert into public.appeals (user_id, sanction_id, message, region_id, assigned_admin_id)
  values (v_uid, p_sanction_id, nullif(btrim(p_message), ''), v_region, v_admin)
  returning id into v_appeal;
  if v_admin is not null then
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_admin,
            'التماس مراجعة إيقاف',
            'مستخدم موقوف قدّم التماس مراجعة في منطقتك. القرار قرارك: إعادة التفعيل أو الرفض.',
            'appeal',
            jsonb_build_object('appeal_id', v_appeal, 'sanction_id', p_sanction_id, 'member_id', v_uid),
            true);
  end if;
  insert into public.notifications (user_id, title, body, type, data, send_push)
  values (v_uid,
          'تم استلام التماسك',
          'وصل التماسك للمسؤول عن منطقتك وهيوصلك الرد هنا فور مراجعته.',
          'appeal',
          jsonb_build_object('appeal_id', v_appeal, 'sanction_id', p_sanction_id),
          true);
  return jsonb_build_object('ok', true, 'appeal_id', v_appeal, 'assigned_admin_id', v_admin);
end;
$func$;
grant execute on function public.submit_appeal(uuid, text) to authenticated;

-- Duty admin (or owner) decides an appeal. Approval revokes the sanction
-- through the moderation engine.
create or replace function public.decide_appeal(p_appeal_id uuid, p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_uid uuid := auth.uid();
  v_appeal public.appeals%rowtype;
  v_duty uuid;
  v_is_owner boolean;
begin
  if v_uid is null or not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'FORBIDDEN');
  end if;
  select * into v_appeal from public.appeals where id = p_appeal_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'NOT_FOUND');
  end if;
  if v_appeal.status <> 'pending' then
    return jsonb_build_object('ok', false, 'code', 'ALREADY_DECIDED');
  end if;
  v_duty := public._duty_admin_for_region(v_appeal.region_id);
  select exists (select 1 from public.users where id = v_uid and role = 'owner') into v_is_owner;
  if not (v_is_owner or v_uid is not distinct from v_duty) then
    return jsonb_build_object('ok', false, 'code', 'NOT_DUTY_ADMIN');
  end if;
  if p_approve then
    perform public._member_exec_revoke_sanction(v_uid, v_appeal.sanction_id,
      coalesce(nullif(btrim(p_note), ''), 'قبول الالتماس'));
    update public.appeals
       set status = 'approved', decided_by = v_uid, decided_at = now(), decision_note = p_note
     where id = p_appeal_id;
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_appeal.user_id,
            'تم قبول الالتماس 🎉',
            'راجع المسؤول التماسك واتفعل حسابك من جديد. أهلًا بعودتك.',
            'appeal',
            jsonb_build_object('appeal_id', p_appeal_id, 'status', 'approved'),
            true);
  else
    update public.appeals
       set status = 'rejected', decided_by = v_uid, decided_at = now(), decision_note = p_note
     where id = p_appeal_id;
    insert into public.notifications (user_id, title, body, type, data, send_push)
    values (v_appeal.user_id,
            'تم رفض الالتماس',
            'راجع المسؤول التماسك وقرر استمرار الإيقاف.' ||
              case when p_note is not null and btrim(p_note) <> '' then ' السبب: ' || p_note else '' end,
            'appeal',
            jsonb_build_object('appeal_id', p_appeal_id, 'status', 'rejected'),
            true);
  end if;
  return jsonb_build_object('ok', true, 'status', case when p_approve then 'approved' else 'rejected' end);
end;
$func$;
grant execute on function public.decide_appeal(uuid, boolean, text) to authenticated;

-- Lift expired sanctions: recompute derived account_status for members whose
-- active sanctions all expired. Runs via pg_cron every 15 minutes.
create or replace function public._lift_expired_member_sanctions()
returns integer
language plpgsql
security definer
set search_path = public
as $func$
declare
  r record;
  v_count integer := 0;
begin
  for r in
    select distinct target_user_id
      from public.sanctions
     where is_active
       and action_status = 'active'
       and end_date is not null
       and end_date < now()
  loop
    perform public._enforce_member_status(r.target_user_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$func$;
revoke all on function public._lift_expired_member_sanctions() from public, anon, authenticated;

select cron.schedule(
  'lift-expired-member-sanctions',
  '*/15 * * * *',
  $$select public._lift_expired_member_sanctions()$$
);

-- 2. _driver_delay_redispatch: 7%-of-order gift compensation.
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
  -- 188: the compensation is a GIFT of 7% of the order value (owner spec
  -- 2026-11-21), platform-funded, replacing the flat-EGP credit; the old
  -- delay_apology_discount_egp setting is deprecated and ignored.
  v_apology := round(coalesce((select o.total_amount from public.orders o
                                where o.id = v_ride.order_id), 0)
                     * greatest(coalesce(v_cfg.delay_apology_percent, 7), 0) / 100.0, 2);

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
                     then '، وأضفنا ' || trim(to_char(v_apology, 'FM999990.##')) || ' جنيه (٧٪ من قيمة طلبك) هدية مننا في محفظتك تقديرًا لصبرك وصبر المطعم 🎁'
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

-- 3. _record_delivery_earnings: delay commission waiver.
CREATE OR REPLACE FUNCTION public._record_delivery_earnings(p_ride_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  r public.rides%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_merchant_model text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_driver_commission numeric;
  v_currency text;
  v_due_hours integer;
  v_goods numeric;
  v_is_cash boolean;
BEGIN
  SELECT * INTO r FROM public.rides WHERE id = p_ride_id;
  IF NOT FOUND OR r.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one earning/commission pair per ride.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE ride_id = p_ride_id) THEN
    RETURN;
  END IF;

  -- Idempotent across paths: when the order-scoped accrual (172 trigger on
  -- orders.status -> delivered) already ran for the linked order, skip.
  -- complete_delivery updates orders.status BEFORE calling this function,
  -- so without this check both paths accrue (regression found in E2E).
  IF r.order_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.driver_earnings WHERE order_id = r.order_id) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = r.driver_id;
  v_currency := COALESCE(NULLIF(r.currency, ''), 'EGP');
  v_is_cash := lower(COALESCE(r.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fare minus the driver-rate commission.
  v_gross := COALESCE(r.fare, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  -- 188: driver-delay waiver - the platform takes NO commission from the
  -- replacement driver on an order that was redispatched for a delay.
  if r.order_id is not null and exists (
    select 1 from public.driver_delay_events de where de.order_id = r.order_id
  ) then
    v_commission := 0;
  end if;
  v_driver_commission := v_commission;

  INSERT INTO public.driver_earnings (driver_id, ride_id, type, amount, currency, description)
  VALUES (r.driver_id, p_ride_id, 'trip', v_gross - v_commission, v_currency,
          'Delivery fare ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'ride', p_ride_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal for merchant orders.
  IF r.order_id IS NOT NULL THEN
    SELECT * INTO v_order FROM public.orders WHERE id = r.order_id;
    IF FOUND AND v_order.merchant_id IS NOT NULL THEN
      SELECT owner_user_id, type, settlement_model
        INTO v_merchant_uid, v_merchant_type, v_merchant_model
        FROM public.merchants WHERE id = v_order.merchant_id;
      IF v_merchant_uid IS NOT NULL THEN
        v_gross := COALESCE(v_order.subtotal, 0);
        v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
        v_commission := public.calculate_commission(v_gross, v_rate);
        INSERT INTO public.platform_commissions
          (member_id, reference_type, reference_id, gross_amount, commission_rate,
           commission_amount, net_amount, currency, status)
        VALUES (v_merchant_uid, 'order', v_order.id, v_gross, v_rate, v_commission,
                v_gross - v_commission, v_currency, 'computed')
        ON CONFLICT (reference_type, reference_id) DO NOTHING;

        IF v_is_cash THEN
          SELECT settlement_remittance_due_hours INTO v_due_hours
            FROM public._settlement_settings();
          v_due_hours := COALESCE(v_due_hours, 24);

          -- Goods money: order value minus the delivery fee (driver keeps the
          -- fare side). Owed to the platform (model A) or the merchant (B).
          v_goods := GREATEST(
            COALESCE(v_order.total_amount, 0) - COALESCE(v_order.delivery_fee, 0), 0);
          IF v_goods > 0 THEN
            INSERT INTO public.driver_obligations
              (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
               owed_to, due_at)
            VALUES
              (r.driver_id, p_ride_id, v_order.id, v_order.merchant_id, 'goods',
               v_goods, v_currency,
               CASE WHEN v_merchant_model = 'direct' THEN 'merchant' ELSE 'platform' END,
               now() + make_interval(hours => v_due_hours))
            ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;

            INSERT INTO public.notifications
              (user_id, title, body, type, data, send_push)
            SELECT v_driver_uid,
                   'تسوية كاش مستحقة',
                   'قبضت ' || v_goods::text || ' ' || v_currency ||
                     ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.',
                   'settlement',
                   jsonb_build_object('ride_id', p_ride_id, 'amount', v_goods),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND n.data->>'ride_id' = p_ride_id::text
            );
          END IF;

          -- Model A: platform owes the merchant goods minus its commission.
          IF v_merchant_model IS DISTINCT FROM 'direct' THEN
            INSERT INTO public.merchant_ledger
              (merchant_id, order_id, entry_type, amount, currency, description)
            VALUES
              (v_order.merchant_id, v_order.id, 'credit',
               v_gross - v_commission, v_currency,
               'Order goods ' || v_gross::text || ' less ' || v_rate::text || '% platform commission')
            ON CONFLICT (order_id, entry_type)
              WHERE order_id IS NOT NULL AND entry_type = 'credit'
              DO NOTHING;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  -- Cash rides of any kind: the platform's driver-side commission is debt
  -- until remitted (pure cash rides have no goods obligation).
  IF v_is_cash AND v_driver_commission > 0 THEN
    SELECT settlement_remittance_due_hours INTO v_due_hours
      FROM public._settlement_settings();
    INSERT INTO public.driver_obligations
      (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
       owed_to, due_at)
    VALUES
      (r.driver_id, p_ride_id, r.order_id, r.merchant_id, 'commission',
       v_driver_commission, v_currency, 'platform',
       now() + make_interval(hours => COALESCE(v_due_hours, 24)))
    ON CONFLICT (ride_id, kind) WHERE ride_id IS NOT NULL DO NOTHING;
  END IF;
END;
$function$;

-- 3. _record_order_settlement: delay commission waiver.
CREATE OR REPLACE FUNCTION public._record_order_settlement(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  o public.orders%ROWTYPE;
  v_driver_uid uuid;
  v_merchant_uid uuid;
  v_merchant_type text;
  v_merchant_model text;
  v_rate numeric;
  v_gross numeric;
  v_commission numeric;
  v_driver_commission numeric;
  v_currency text := 'EGP';
  v_due_hours integer;
  v_goods numeric;
  v_is_cash boolean;
BEGIN
  SELECT * INTO o FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND OR o.status <> 'delivered' OR o.driver_id IS NULL THEN
    RETURN;
  END IF;
  -- Idempotent: one accrual per order, regardless of path.
  IF EXISTS (SELECT 1 FROM public.driver_earnings WHERE order_id = p_order_id) THEN
    RETURN;
  END IF;
  -- A linked ride already accrued for this order (147/161 ride path).
  IF EXISTS (
    SELECT 1 FROM public.driver_earnings de
    JOIN public.rides r ON r.id = de.ride_id
    WHERE r.order_id = p_order_id
  ) THEN
    RETURN;
  END IF;

  SELECT user_id INTO v_driver_uid FROM public.drivers WHERE id = o.driver_id;
  v_is_cash := lower(COALESCE(o.payment_method, '')) = 'cash';

  -- Driver: earns the delivery fee minus the driver-rate commission.
  v_gross := COALESCE(o.delivery_fee, 0);
  v_rate := COALESCE(public.get_commission_rate('driver', NULL, v_driver_uid), 0);
  v_commission := public.calculate_commission(v_gross, v_rate);
  -- 188: driver-delay waiver - the platform takes NO commission from the
  -- replacement driver on an order that was redispatched for a delay.
  if p_order_id is not null and exists (
    select 1 from public.driver_delay_events de where de.order_id = p_order_id
  ) then
    v_commission := 0;
  end if;
  v_driver_commission := v_commission;

  INSERT INTO public.driver_earnings (driver_id, order_id, type, amount, currency, description)
  VALUES (o.driver_id, p_order_id, 'trip', v_gross - v_commission, v_currency,
          'Order delivery fee ' || v_gross::text || ' less ' || v_rate::text || '% platform commission');

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, status)
  VALUES (v_driver_uid, 'order_driver', p_order_id, v_gross, v_rate, v_commission,
          v_gross - v_commission, v_currency, 'computed')
  ON CONFLICT (reference_type, reference_id) DO NOTHING;

  -- Merchant: commission on the goods subtotal.
  IF o.merchant_id IS NOT NULL THEN
    SELECT owner_user_id, type, settlement_model
      INTO v_merchant_uid, v_merchant_type, v_merchant_model
      FROM public.merchants WHERE id = o.merchant_id;
    IF v_merchant_uid IS NOT NULL THEN
      v_gross := COALESCE(o.subtotal, 0);
      v_rate := COALESCE(public.get_commission_rate('merchant', v_merchant_type, v_merchant_uid), 0);
      v_commission := public.calculate_commission(v_gross, v_rate);
      INSERT INTO public.platform_commissions
        (member_id, reference_type, reference_id, gross_amount, commission_rate,
         commission_amount, net_amount, currency, status)
      VALUES (v_merchant_uid, 'order', p_order_id, v_gross, v_rate, v_commission,
              v_gross - v_commission, v_currency, 'computed')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;

      IF v_is_cash THEN
        SELECT settlement_remittance_due_hours INTO v_due_hours
          FROM public._settlement_settings();
        v_due_hours := COALESCE(v_due_hours, 24);

        -- Goods money owed by the driver (order value minus the delivery fee).
        v_goods := GREATEST(
          COALESCE(o.total_amount, 0) - COALESCE(o.delivery_fee, 0), 0);
        IF v_goods > 0 THEN
          INSERT INTO public.driver_obligations
            (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
             owed_to, due_at)
          VALUES
            (o.driver_id, NULL, p_order_id, o.merchant_id, 'goods',
             v_goods, v_currency,
             CASE WHEN v_merchant_model = 'direct' THEN 'merchant' ELSE 'platform' END,
             now() + make_interval(hours => v_due_hours))
          ON CONFLICT (order_id, kind) WHERE ride_id IS NULL AND order_id IS NOT NULL DO NOTHING;

          INSERT INTO public.notifications
            (user_id, title, body, type, data, send_push)
          SELECT v_driver_uid,
                 'تسوية كاش مستحقة',
                 'قبضت ' || v_goods::text || ' ' || v_currency ||
                   ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.',
                 'settlement',
                 jsonb_build_object('order_id', p_order_id, 'amount', v_goods),
                 true
          WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications n
             WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
               AND n.data->>'order_id' = p_order_id::text
          );
        END IF;

        -- Platform model: platform owes the merchant goods minus commission.
        IF v_merchant_model IS DISTINCT FROM 'direct' THEN
          INSERT INTO public.merchant_ledger
            (merchant_id, order_id, entry_type, amount, currency, description)
          VALUES
            (o.merchant_id, p_order_id, 'credit',
             v_gross - v_commission, v_currency,
             'Order goods ' || v_gross::text || ' less ' || v_rate::text || '% platform commission')
          ON CONFLICT (order_id, entry_type)
            WHERE order_id IS NOT NULL AND entry_type = 'credit'
            DO NOTHING;
        END IF;
      END IF;
    END IF;
  END IF;

  -- Driver-side commission on cash orders is debt until remitted.
  IF v_is_cash AND v_driver_commission > 0 THEN
    SELECT settlement_remittance_due_hours INTO v_due_hours
      FROM public._settlement_settings();
    INSERT INTO public.driver_obligations
      (driver_id, ride_id, order_id, merchant_id, kind, amount, currency,
       owed_to, due_at)
    VALUES
      (o.driver_id, NULL, p_order_id, o.merchant_id, 'commission',
       v_driver_commission, v_currency, 'platform',
       now() + make_interval(hours => COALESCE(v_due_hours, 24)))
    ON CONFLICT (order_id, kind) WHERE ride_id IS NULL AND order_id IS NOT NULL DO NOTHING;
  END IF;
END;
$function$;

-- 4. cancel_order: 3rd monthly cancel executes + 5-day suspension.
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
  v_suspend_after boolean := false;
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



-- 5b. Refusal log: single counting source for the monthly refusal window
-- (3rd-refusal orders are not cancelled, so orders.cancelled_by can't count
-- them). Server-written only.
create table if not exists public.refusal_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  order_id uuid not null references public.orders(id),
  created_at timestamptz not null default now()
);
alter table public.refusal_events enable row level security;
revoke all on public.refusal_events from anon, authenticated;
create index if not exists refusal_events_user_month_idx
  on public.refusal_events (user_id, created_at);

-- 5. report_delivery_refusal: 3rd refusal = no cancel + 5-day suspension + ops incident.
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

-- 6. create_order: suspended/banned guard.
create or replace function public.create_order(
  p_merchant_id uuid, p_items jsonb, p_delivery_address text default null,
  p_delivery_latitude numeric default null, p_delivery_longitude numeric default null,
  p_payment_method text default 'cash', p_coupon_code text default null,
  p_special_instructions text default null, p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_merchant public.merchants%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty int;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_discount numeric := 0;
  v_total numeric;
  v_order_id uuid;
  v_coupon jsonb;
  v_coupon_id uuid;
  v_lines jsonb := '[]'::jsonb;
  v_existing uuid;
  v_stock_touched boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  -- 188: a suspended/banned customer cannot place orders (the 5-day policy
  -- suspensions would otherwise be cosmetic).
  if (select u.account_status from public.users u where u.id = v_uid) in ('suspended', 'banned') then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;

  if p_payment_method not in ('cash', 'instapay', 'vodafone_cash') then
    raise exception 'INVALID_PAYMENT_METHOD';
  end if;

  if p_idempotency_key is not null then
    select id into v_existing from public.orders
    where user_id = v_uid and idempotency_key = p_idempotency_key;
    if v_existing is not null then
      return jsonb_build_object(
        'ok', true, 'order_id', v_existing, 'idempotent_replay', true
      );
    end if;
  end if;

  select * into v_merchant from public.merchants where id = p_merchant_id;
  if not found then
    raise exception 'MERCHANT_NOT_FOUND';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART';
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

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid
      and merchant_id = p_merchant_id;
    if not found then
      raise exception 'PRODUCT_NOT_FOUND %', v_item->>'product_id';
    end if;
    if v_product.is_available is not true then
      raise exception 'PRODUCT_UNAVAILABLE %', coalesce(v_product.name_ar, v_product.name);
    end if;

    -- Atomic stock check + decrement (NULL stock = unlimited)
    if v_product.stock_quantity is not null then
      update public.products
         set stock_quantity = stock_quantity - v_qty
       where id = v_product.id
         and stock_quantity >= v_qty;
      if not found then
        raise exception 'INSUFFICIENT_STOCK %', coalesce(v_product.name_ar, v_product.name);
      end if;
      v_stock_touched := true;
    end if;

    v_subtotal := v_subtotal + (v_product.price * v_qty);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'product_name', coalesce(v_product.name_ar, v_product.name),
      'quantity', v_qty,
      'unit_price', v_product.price,
      'total_price', v_product.price * v_qty
    );
  end loop;

  v_delivery_fee := coalesce(v_merchant.delivery_fee, 0);

  if v_merchant.min_order is not null and v_subtotal < v_merchant.min_order then
    raise exception 'BELOW_MIN_ORDER %', v_merchant.min_order;
  end if;

  if p_coupon_code is not null and btrim(p_coupon_code) <> '' then
    v_coupon := public.redeem_coupon(p_coupon_code, v_uid);
    if not (v_coupon->>'success')::boolean then
      raise exception 'COUPON_%', upper(v_coupon->>'reason');
    end if;
    if (v_coupon->>'merchant_id') is not null
       and (v_coupon->>'merchant_id')::uuid <> p_merchant_id then
      raise exception 'COUPON_WRONG_MERCHANT';
    end if;
    if (v_coupon->>'minimum_order') is not null
       and v_subtotal < (v_coupon->>'minimum_order')::numeric then
      raise exception 'COUPON_MIN_ORDER_NOT_MET';
    end if;
    v_coupon_id := (v_coupon->>'coupon_id')::uuid;
    if v_coupon->>'discount_type' = 'percentage' then
      v_discount := round(v_subtotal * (v_coupon->>'discount_value')::numeric / 100.0, 2);
    else
      v_discount := (v_coupon->>'discount_value')::numeric;
    end if;
    if (v_coupon->>'maximum_discount') is not null then
      v_discount := least(v_discount, (v_coupon->>'maximum_discount')::numeric);
    end if;
    v_discount := least(v_discount, v_subtotal);
  end if;

  v_total := v_subtotal + v_delivery_fee - v_discount;
  if v_total < 0 then
    v_total := 0;
  end if;

  insert into public.orders (
    user_id, merchant_id, merchant_name, status, payment_status,
    payment_method, subtotal, delivery_fee, discount, tax, total_amount,
    coupon_id, delivery_address, delivery_latitude, delivery_longitude,
    special_instructions, items, idempotency_key, dispatch_status,
    stock_decremented
  ) values (
    v_uid, p_merchant_id, v_merchant.name, 'pending', 'pending',
    p_payment_method, v_subtotal, v_delivery_fee, v_discount, 0, v_total,
    v_coupon_id, p_delivery_address, p_delivery_latitude, p_delivery_longitude,
    p_special_instructions, v_lines, p_idempotency_key, 'PENDING_DISPATCH',
    v_stock_touched
  )
  returning id into v_order_id;

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
  select v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric
  from jsonb_array_elements(v_lines) l;

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'total_amount', v_total,
    'status', 'pending',
    'idempotent_replay', false
  );
end;
$$;
