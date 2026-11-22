-- 395 (v3): the late-delivery apology gift becomes spendable platform credit.
-- v3 review changes: settlement NETS the gift into the driver remittance
-- (owner decision: driver remits pre-credit goods minus the gift, merchant
-- still receives full goods, residuals are platform payables recorded on
-- platform_subsidies); create_order serializes same-key checkouts with an
-- advisory lock before any pricing or mutation; the v1->v2 backfill is
-- removed (v1 never reached production, staging is reset by the builder).
--
-- v1 granted the gift as ordinary wallet credit and derived availability
-- from reference strings in the wallet ledger. Review rejected that: the
-- wallet is client-debitable through wallet_pay overloads, so reference-string
-- accounting is forgeable, and reducing orders.total_amount without a
-- compensating ledger underpaid merchants/captains against the owner rule
-- "merchant and captain are paid exactly as if there were no credit; the
-- platform bears the discount."
--
-- v2 design:
--   * platform_credit_accounts: one locked row per customer, balance >= 0.
--     This is the ONLY authoritative gift balance. Generic wallet debits
--     (both wallet_pay overloads) cannot reach it.
--   * platform_credit_ledger: grant / spend / restore / backfill entries,
--     one per (order_id, kind); the row lock on the account serializes
--     concurrent checkouts, so a pound is spent once.
--   * create_order spends min(balance, amount due) server-side and records
--     orders.platform_credit_applied; total_amount is reduced by the credit
--     (customer pays less), never below zero.
--   * Settlement/remittance uses the PRE-CREDIT amount everywhere
--     (total_amount + platform_credit_applied - delivery_fee), so merchant
--     and captain earnings are identical to a no-credit order in both the
--     direct and platform settlement models. The gap is booked in
--     platform_subsidies (platform owes the driver the cash shortfall) and
--     netted in the escalation sweep so a credited order can never suspend
--     a captain over money the platform owes him.
--   * Cancel/refund restores the spent credit exactly once
--     (_platform_credit_restore, idempotent per order).
--   * my_platform_credit(p_amount_due) returns the spendable balance and
--     how much would apply to a given amount due, for the checkout screen.
--   * Backfill: any wallet credit stranded by v1 (reference_type
--     'delay_apology') is moved into the new account, debited back out of
--     the wallet (capped at the wallet balance) so it cannot be spent twice.
--
-- No expiry: nothing in the schema expires the gift. No effect on merchant
-- or driver payouts beyond the platform bearing the cost.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists platform_credit_applied numeric not null default 0;

create table if not exists public.platform_credit_accounts (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance numeric not null default 0 check (balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  kind text not null check (kind in ('grant', 'spend', 'restore')),
  amount numeric not null check (amount > 0),
  balance_after numeric not null check (balance_after >= 0),
  note text,
  created_at timestamptz not null default now()
);
-- Idempotency: at most one grant / spend / restore per order.
create unique index if not exists platform_credit_ledger_order_kind_uniq
  on public.platform_credit_ledger (order_id, kind) where order_id is not null;
create index if not exists platform_credit_ledger_user_idx
  on public.platform_credit_ledger (user_id, created_at desc);

alter table public.platform_credit_ledger
  drop constraint if exists platform_credit_ledger_kind_check;
alter table public.platform_credit_ledger
  add constraint platform_credit_ledger_kind_check
  check (kind in ('grant', 'spend', 'restore'));

create table if not exists public.platform_subsidies (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  kind text not null check (kind in ('delay_apology_credit')),
  amount numeric not null check (amount > 0),
  settlement_model text not null check (settlement_model in ('direct', 'platform')),
  reimburses text not null check (reimburses in ('driver')),
  -- How the gift is split at settlement time (owner decision 2026-11-23):
  -- remittance_reduction nets into the driver's goods obligation,
  -- driver_payable is the platform's debt to him when the gift eats into
  -- his fare, merchant_payable the platform's debt to a direct-model
  -- merchant who must still receive full goods.
  remittance_reduction numeric not null default 0 check (remittance_reduction >= 0),
  driver_payable numeric not null default 0 check (driver_payable >= 0),
  merchant_payable numeric not null default 0 check (merchant_payable >= 0),
  status text not null default 'netted'
    check (status in ('open', 'netted', 'netted_noncash', 'settled', 'void')),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  unique (order_id, kind)
);

-- Converge databases that applied an earlier revision of this migration.
alter table public.platform_subsidies
  add column if not exists remittance_reduction numeric not null default 0,
  add column if not exists driver_payable numeric not null default 0,
  add column if not exists merchant_payable numeric not null default 0;
alter table public.platform_subsidies
  drop constraint if exists platform_subsidies_status_check;
alter table public.platform_subsidies
  add constraint platform_subsidies_status_check
  check (status in ('open', 'netted', 'netted_noncash', 'settled', 'void'));

alter table public.platform_credit_accounts enable row level security;
alter table public.platform_credit_ledger enable row level security;
alter table public.platform_subsidies enable row level security;

-- ---------------------------------------------------------------------------
-- Credit helpers (server-only; every mutation holds the account row lock)
-- ---------------------------------------------------------------------------

create or replace function public._platform_credit_grant(
  p_user uuid, p_amount numeric, p_order uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_balance numeric;
begin
  if p_user is null or p_amount is null or p_amount <= 0 then
    return;
  end if;
  insert into public.platform_credit_accounts (user_id, balance)
  values (p_user, 0)
  on conflict (user_id) do nothing;
  perform 1 from public.platform_credit_accounts where user_id = p_user for update;
  -- One grant per order: a redispatch replay must not gift twice.
  if p_order is not null and exists (
    select 1 from public.platform_credit_ledger
     where order_id = p_order and kind = 'grant') then
    return;
  end if;
  update public.platform_credit_accounts
     set balance = balance + p_amount, updated_at = now()
   where user_id = p_user
  returning balance into v_balance;
  insert into public.platform_credit_ledger
    (user_id, order_id, kind, amount, balance_after, note)
  values
    (p_user, p_order, 'grant', p_amount, v_balance, 'delay apology gift');
  perform public.write_audit('PLATFORM_CREDIT_GRANTED', 'users', p_user::text,
    jsonb_build_object('amount', p_amount, 'order_id', p_order, 'balance_after', v_balance));
end;
$function$;

-- v1 used different parameter names; drop before replacing.
drop function if exists public._platform_credit_spend(uuid, uuid, numeric);

create or replace function public._platform_credit_spend(
  p_user uuid, p_order uuid, p_amount_due numeric)
 returns numeric
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_balance numeric;
  v_spend numeric;
begin
  if p_user is null or p_amount_due is null or p_amount_due <= 0 then
    return 0;
  end if;
  perform 1 from public.platform_credit_accounts where user_id = p_user for update;
  if not found then
    return 0;
  end if;
  -- Idempotent per order: a create_order replay never double-spends.
  if exists (select 1 from public.platform_credit_ledger
              where order_id = p_order and kind = 'spend') then
    return 0;
  end if;
  select balance into v_balance from public.platform_credit_accounts
   where user_id = p_user;
  v_spend := least(v_balance, p_amount_due);
  if v_spend <= 0 then
    return 0;
  end if;
  update public.platform_credit_accounts
     set balance = balance - v_spend, updated_at = now()
   where user_id = p_user;
  insert into public.platform_credit_ledger
    (user_id, order_id, kind, amount, balance_after, note)
  values
    (p_user, p_order, 'spend', v_spend, v_balance - v_spend, 'applied at checkout');
  perform public.write_audit('PLATFORM_CREDIT_SPENT', 'orders', p_order::text,
    jsonb_build_object('amount', v_spend, 'user_id', p_user,
                       'balance_after', v_balance - v_spend));
  return v_spend;
end;
$function$;

create or replace function public._platform_credit_restore(
  p_user uuid, p_amount numeric, p_order uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_spent numeric;
  v_restore numeric;
  v_balance numeric;
begin
  if p_user is null or p_amount is null or p_amount <= 0 then
    return;
  end if;
  insert into public.platform_credit_accounts (user_id, balance)
  values (p_user, 0)
  on conflict (user_id) do nothing;
  perform 1 from public.platform_credit_accounts where user_id = p_user for update;
  -- Exactly one restore per order, and never more than was spent on it.
  if exists (select 1 from public.platform_credit_ledger
              where order_id = p_order and kind = 'restore') then
    return;
  end if;
  select amount into v_spent from public.platform_credit_ledger
   where order_id = p_order and kind = 'spend';
  if not found then
    return;
  end if;
  v_restore := least(p_amount, v_spent);
  if v_restore <= 0 then
    return;
  end if;
  update public.platform_credit_accounts
     set balance = balance + v_restore, updated_at = now()
   where user_id = p_user
  returning balance into v_balance;
  insert into public.platform_credit_ledger
    (user_id, order_id, kind, amount, balance_after, note)
  values
    (p_user, p_order, 'restore', v_restore, v_balance, 'order cancelled/refunded');
  perform public.write_audit('PLATFORM_CREDIT_RESTORED', 'orders', p_order::text,
    jsonb_build_object('amount', v_restore, 'user_id', p_user, 'balance_after', v_balance));
end;
$function$;

-- patched: create_order

CREATE OR REPLACE FUNCTION public.create_order(p_merchant_id uuid, p_items jsonb, p_delivery_address text DEFAULT NULL::text, p_delivery_latitude numeric DEFAULT NULL::numeric, p_delivery_longitude numeric DEFAULT NULL::numeric, p_payment_method text DEFAULT 'cash'::text, p_coupon_code text DEFAULT NULL::text, p_special_instructions text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_line jsonb;
  v_existing uuid;
  v_stock_touched boolean := false;
  v_unit_price numeric;
  v_modifier_id text;
  v_modifier record;
  v_modifiers jsonb;
  v_selected_groups uuid[];
  v_group record;
  v_max_radius_km numeric;
  v_distance_km numeric;
  v_credit numeric := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if (select u.account_status from public.users u where u.id = v_uid) in ('suspended', 'banned') then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;

  -- Same set as orders_payment_method_check. card/wallet orders are
  -- created with payment_status 'pending'; charging stays a separate flow.
  if p_payment_method not in ('cash', 'card', 'wallet', 'instapay', 'vodafone_cash') then
    raise exception 'INVALID_PAYMENT_METHOD';
  end if;

  -- F4a: an order without delivery coordinates is undispatchable. No
  -- pickup-only order type exists in create_order, so every order must
  -- carry an address and coordinates.
  if p_delivery_latitude is null or p_delivery_longitude is null
     or p_delivery_address is null or btrim(p_delivery_address) = '' then
    raise exception 'MISSING_DELIVERY_LOCATION';
  end if;

  if p_idempotency_key is not null then
    -- 395 (#89): serialize same-key checkouts BEFORE any pricing, stock
    -- decrement or coupon redemption. A concurrent loser waits here until
    -- the winner commits, then sees the order and replays cleanly, so it
    -- never commits its own stock/coupon side effects.
    perform pg_advisory_xact_lock(hashtext(v_uid::text || ':' || p_idempotency_key));
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

  -- A cached cart is not permission to order from a closed/suspended store.
  if v_merchant.status is distinct from 'active' then
    raise exception 'MERCHANT_UNAVAILABLE';
  end if;
  if v_merchant.is_open is distinct from true then
    raise exception 'MERCHANT_CLOSED';
  end if;

  -- Reviewer batch 21: reject delivery addresses outside the store's
  -- delivery reach. delivery_zones.radius_km circles are centered on the
  -- merchant's own coordinates (the table carries no separate center). With
  -- no active zones configured, merchant_profiles.max_delivery_radius_km is
  -- the fallback. A merchant with neither declares no reach, so no limit is
  -- enforced for them.
  if v_merchant.latitude is not null and v_merchant.longitude is not null
     and p_delivery_latitude is not null and p_delivery_longitude is not null then
    select max(z.radius_km) into v_max_radius_km
    from public.delivery_zones z
    where z.merchant_id = p_merchant_id and z.is_active;
    if v_max_radius_km is null then
      select mp.max_delivery_radius_km into v_max_radius_km
      from public.merchant_profiles mp
      where mp.merchant_id = p_merchant_id and mp.is_active;
    end if;
    if v_max_radius_km is not null then
      v_distance_km := 6371.0 * 2.0 * asin(sqrt(
        pow(sin(radians((p_delivery_latitude - v_merchant.latitude)::double precision / 2.0)), 2.0) +
        cos(radians(v_merchant.latitude::double precision)) *
        cos(radians(p_delivery_latitude::double precision)) *
        pow(sin(radians((p_delivery_longitude - v_merchant.longitude)::double precision / 2.0)), 2.0)
      ));
      if v_distance_km > v_max_radius_km then
        raise exception 'DELIVERY_OUT_OF_ZONE';
      end if;
    end if;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'TOO_MANY_ITEMS';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_line := public._price_order_line(p_merchant_id, v_item, true);
    v_stock_touched := v_stock_touched or (v_line->>'stock_decremented')::boolean;
    v_subtotal := v_subtotal + (v_line->>'total_price')::numeric;
    v_lines := v_lines || (v_line - 'stock_decremented' - 'name' - 'name_ar');
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
      v_discount := round(v_subtotal * (v_coupon->'discount_value')::numeric / 100.0, 2);
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

  -- 395: a same-key twin that loses the check-then-insert race blocks on
  -- idx_orders_idempotency_key until the winner commits, then raises
  -- unique_violation; convert it into the same clean replay the sequential
  -- path returns instead of an error.
  begin
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
  exception
    when unique_violation then
      if p_idempotency_key is null then
        raise;
      end if;
      select id into v_existing from public.orders
      where user_id = v_uid and idempotency_key = p_idempotency_key;
      if v_existing is null then
        raise;
      end if;
      return jsonb_build_object(
        'ok', true, 'order_id', v_existing, 'idempotent_replay', true
      );
  end;

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, total_price, modifiers)
  select v_order_id,
         (l->>'product_id')::uuid,
         l->>'product_name',
         (l->>'quantity')::int,
         (l->>'unit_price')::numeric,
         (l->>'total_price')::numeric,
         coalesce(l->'modifiers', '[]'::jsonb)
  from jsonb_array_elements(v_lines) l;

  -- 395: the delay-apology gift is spendable here as platform credit. The
  -- server recomputes the amount due; the credit covers up to that amount,
  -- never more than the gift balance, never below zero. The credit ledger
  -- and audit rows are written inside _platform_credit_spend under the
  -- credit-account row lock, so concurrent checkouts cannot double-spend.
  v_credit := public._platform_credit_spend(v_uid, v_order_id, v_total);
  if v_credit > 0 then
    update public.orders
       set total_amount = total_amount - v_credit,
           platform_credit_applied = v_credit,
           updated_at = now()
     where id = v_order_id;
    v_total := v_total - v_credit;
  end if;

  return jsonb_build_object(
    'ok', true,
    'order_id', v_order_id,
    'subtotal', v_subtotal,
    'delivery_fee', v_delivery_fee,
    'discount', v_discount,
    'platform_credit_applied', v_credit,
    'total_amount', v_total,
    'status', 'pending',
    'idempotent_replay', false
  );
end;
$function$;
-- patched: finalize

CREATE OR REPLACE FUNCTION public._finalize_order_cancel(p_order_id uuid, p_actor text, p_reason text, p_restock boolean DEFAULT true, p_refund boolean DEFAULT true, p_release_coupon boolean DEFAULT true, p_ride_cancelled_by text DEFAULT 'system'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- 395: an order cancelled or rejected before delivery returns the
  -- platform credit it consumed, so the gift survives the failed order.
  -- The terminal-state early return above plus the order row lock make
  -- this fire once; the ledger partial-unique index backstops it.
  if coalesce(v_order.platform_credit_applied, 0) > 0 then
    perform public._platform_credit_restore(
      v_order.user_id, v_order.platform_credit_applied, p_order_id);
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

  -- 196: release the driver and close open offers on every ride of the order.
  update public.driver_locations
     set ride_id = null
   where ride_id in (select id from public.rides where order_id = p_order_id);
  update public.ride_requests
     set status = 'expired', responded_at = now()
   where ride_id in (select id from public.rides where order_id = p_order_id)
     and status = 'offered';
  update public.ride_requests
     set status = 'cancelled', responded_at = now()
   where ride_id in (select id from public.rides where order_id = p_order_id)
     and status = 'accepted';

  update public.rides
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = p_ride_cancelled_by,
         cancellation_reason = p_reason
   where order_id = p_order_id
     and status not in ('completed', 'cancelled');
end;
$function$
;
-- patched: delay

CREATE OR REPLACE FUNCTION public._driver_delay_redispatch(p_ride_id uuid, p_reason text, p_reported_by text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        -- 395: the gift now lives in the customer's platform credit account
        -- (its own locked ledger, unreachable by generic wallet debits) and
        -- is auto-applied as a discount at checkout.
        perform public._platform_credit_grant(v_customer, v_apology, v_ride.order_id);
      end if;
      insert into public.notifications (user_id, title, body, type, data, send_push)
      values (v_customer,
              'نعتذر عن التأخير 🙏',
              'طلبك رقم ' || v_short || ' اتأخر بسبب عطل فني عند الكابتن السابق. المطعم ملوش أي ذنب، والموضوع مش مقصود مننا. كابتن تاني في الطريق لطلبك دلوقتي' ||
                case when v_apology > 0
                     then '، وأضفنا ' || trim(to_char(v_apology, 'FM999990.##')) || ' جنيه (٧٪ من قيمة طلبك) هدية مننا في رصيد هداياك، هتنخصم تلقائي من طلبك الجاي 🎁'
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
$function$
;
-- patched: ride_settle

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
  v_goods_pre numeric;
  v_credit numeric := 0;
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
        -- 395: platform gift credit consumed at checkout (0 for most orders).
        v_credit := COALESCE(v_order.platform_credit_applied, 0);
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
          -- 395 (owner decision 2026-11-23): the gift is netted INTO
          -- the remittance at settlement time. The driver owes
          -- pre-credit goods minus the gift (never below zero), so
          -- the escalation, overdue and dispatch cash-ceiling checks
          -- all read the net amount straight from the obligation.
          -- The platform_subsidies row records the split: remittance
          -- reduction, a payable to the driver when the gift eats
          -- into his fare, and (direct model) a payable to the
          -- merchant, who must still receive full goods.
          v_goods_pre := GREATEST(
            COALESCE(v_order.total_amount, 0) + COALESCE(v_order.platform_credit_applied, 0)
            - COALESCE(v_order.delivery_fee, 0), 0);
          v_goods := GREATEST(v_goods_pre - v_credit, 0);
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
                   CASE WHEN v_credit > 0 THEN
                       'التوريد ' || v_goods::text || ' ' || v_currency ||
                         ' مستحق خلال ' || v_due_hours::text || ' ساعة. المنصة بتغطي ' ||
                         trim(to_char(v_credit, 'FM999990.##')) ||
                         ' من قيمة البضاعة (هدية العميل مننا).'
                   ELSE
                       'قبضت ' || v_goods::text || ' ' || v_currency ||
                         ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.'
                   END,
                   'settlement',
                   jsonb_build_object('ride_id', p_ride_id, 'amount', v_goods),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND (n.data->>'ride_id' = p_ride_id::text
                      OR n.data->>'order_id' = v_order.id::text)
            );
          ELSIF v_credit > 0 THEN
            -- The gift covered every pound of goods: no remittance is due.
            INSERT INTO public.notifications
              (user_id, title, body, type, data, send_push)
            SELECT v_driver_uid,
                   'مفيش توريد على الطلب ده',
                   'المنصة بتغطي ' || trim(to_char(v_credit, 'FM999990.##')) || ' ' || v_currency ||
                     ' (هدية العميل مننا). مفيش توريد بضاعة مستحق عليك للطلب ده.',
                   'settlement',
                   jsonb_build_object('order_id', v_order.id, 'amount', 0),
                   true
            WHERE NOT EXISTS (
              SELECT 1 FROM public.notifications n
               WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
                 AND (n.data->>'ride_id' = p_ride_id::text OR n.data->>'order_id' = v_order.id::text)
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

          -- 395: netted platform subsidy ledger. The gift reduces the
          -- driver's goods remittance (recorded net above); this row is the
          -- accounting trail of who the platform still owes: the driver when
          -- the gift ate into his fare (driver_payable) and, in the direct
          -- model, the merchant who must receive full goods
          -- (merchant_payable). Inserted exactly once per order, in the same
          -- transaction as the obligation; admin reads it via service_role.
          IF v_credit > 0
             AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                              WHERE ps.order_id = v_order.id
                                AND ps.kind = 'delay_apology_credit') THEN
            INSERT INTO public.platform_subsidies
              (order_id, kind, amount, settlement_model, reimburses,
               remittance_reduction, driver_payable, merchant_payable, status)
            VALUES
              (v_order.id, 'delay_apology_credit', v_credit,
               CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
               'driver',
               LEAST(v_credit, v_goods_pre),
               GREATEST(v_credit - v_goods_pre, 0),
               CASE WHEN v_merchant_model = 'direct'
                    THEN LEAST(v_credit, v_goods_pre) ELSE 0 END,
               'netted');
            PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', v_order.id::text,
              jsonb_build_object('amount', v_credit,
                'remittance_reduction', LEAST(v_credit, v_goods_pre),
                'driver_payable', GREATEST(v_credit - v_goods_pre, 0),
                'settlement_model', CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END));
          END IF;

        END IF;

          -- 395: non-cash credited orders carry no remittance, so the gift
          -- costs the platform nothing extra here (it already holds the
          -- money); record the subsidy for complete accounting only.
          IF NOT v_is_cash AND v_credit > 0
             AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                              WHERE ps.order_id = v_order.id
                                AND ps.kind = 'delay_apology_credit') THEN
            INSERT INTO public.platform_subsidies
              (order_id, kind, amount, settlement_model, reimburses,
               remittance_reduction, driver_payable, merchant_payable, status)
            VALUES
              (v_order.id, 'delay_apology_credit', v_credit,
               CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
               'driver', 0, 0, 0, 'netted_noncash');
            PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', v_order.id::text,
              jsonb_build_object('amount', v_credit, 'status', 'netted_noncash'));
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
$function$
;
-- patched: order_settle

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
  v_goods_pre numeric;
  v_credit numeric := 0;
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
  -- 395: platform gift credit consumed at checkout (0 for most orders).
  v_credit := COALESCE(o.platform_credit_applied, 0);

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
        -- 395 (owner decision 2026-11-23): the gift is netted INTO
        -- the remittance at settlement time. The driver owes
        -- pre-credit goods minus the gift (never below zero), so
        -- the escalation, overdue and dispatch cash-ceiling checks
        -- all read the net amount straight from the obligation.
        -- The platform_subsidies row records the split: remittance
        -- reduction, a payable to the driver when the gift eats
        -- into his fare, and (direct model) a payable to the
        -- merchant, who must still receive full goods.
        v_goods_pre := GREATEST(
          COALESCE(o.total_amount, 0) + COALESCE(o.platform_credit_applied, 0)
          - COALESCE(o.delivery_fee, 0), 0);
        v_goods := GREATEST(v_goods_pre - v_credit, 0);
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
                 CASE WHEN v_credit > 0 THEN
                     'التوريد ' || v_goods::text || ' ' || v_currency ||
                       ' مستحق خلال ' || v_due_hours::text || ' ساعة. المنصة بتغطي ' ||
                       trim(to_char(v_credit, 'FM999990.##')) ||
                       ' من قيمة البضاعة (هدية العميل مننا).'
                 ELSE
                     'قبضت ' || v_goods::text || ' ' || v_currency ||
                       ' من الطلب. التوريد مستحق خلال ' || v_due_hours::text || ' ساعة.'
                 END,
                 'settlement',
                 jsonb_build_object('order_id', p_order_id, 'amount', v_goods),
                 true
          WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications n
             WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
               AND (n.data->>'order_id' = p_order_id::text
                    OR n.data->>'ride_id' IN (
                      SELECT r2.id::text FROM public.rides r2
                       WHERE r2.order_id = p_order_id))
          );
        ELSIF v_credit > 0 THEN
          -- The gift covered every pound of goods: no remittance is due.
          INSERT INTO public.notifications
            (user_id, title, body, type, data, send_push)
          SELECT v_driver_uid,
                 'مفيش توريد على الطلب ده',
                 'المنصة بتغطي ' || trim(to_char(v_credit, 'FM999990.##')) || ' ' || v_currency ||
                   ' (هدية العميل مننا). مفيش توريد بضاعة مستحق عليك للطلب ده.',
                 'settlement',
                 jsonb_build_object('order_id', p_order_id, 'amount', 0),
                 true
          WHERE NOT EXISTS (
            SELECT 1 FROM public.notifications n
             WHERE n.user_id = v_driver_uid AND n.type = 'settlement'
               AND (n.data->>'order_id' = p_order_id::text)
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

        -- 395: netted platform subsidy ledger. The gift reduces the
        -- driver's goods remittance (recorded net above); this row is the
        -- accounting trail of who the platform still owes: the driver when
        -- the gift ate into his fare (driver_payable) and, in the direct
        -- model, the merchant who must receive full goods
        -- (merchant_payable). Inserted exactly once per order, in the same
        -- transaction as the obligation; admin reads it via service_role.
        IF v_credit > 0
           AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                            WHERE ps.order_id = p_order_id
                              AND ps.kind = 'delay_apology_credit') THEN
          INSERT INTO public.platform_subsidies
            (order_id, kind, amount, settlement_model, reimburses,
             remittance_reduction, driver_payable, merchant_payable, status)
          VALUES
            (p_order_id, 'delay_apology_credit', v_credit,
             CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
             'driver',
             LEAST(v_credit, v_goods_pre),
             GREATEST(v_credit - v_goods_pre, 0),
             CASE WHEN v_merchant_model = 'direct'
                  THEN LEAST(v_credit, v_goods_pre) ELSE 0 END,
             'netted');
          PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', p_order_id::text,
            jsonb_build_object('amount', v_credit,
              'remittance_reduction', LEAST(v_credit, v_goods_pre),
              'driver_payable', GREATEST(v_credit - v_goods_pre, 0),
              'settlement_model', CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END));
        END IF;

      END IF;

        -- 395: non-cash credited orders carry no remittance, so the gift
        -- costs the platform nothing extra here (it already holds the
        -- money); record the subsidy for complete accounting only.
        IF NOT v_is_cash AND v_credit > 0
           AND NOT EXISTS (SELECT 1 FROM public.platform_subsidies ps
                            WHERE ps.order_id = p_order_id
                              AND ps.kind = 'delay_apology_credit') THEN
          INSERT INTO public.platform_subsidies
            (order_id, kind, amount, settlement_model, reimburses,
             remittance_reduction, driver_payable, merchant_payable, status)
          VALUES
            (p_order_id, 'delay_apology_credit', v_credit,
             CASE WHEN v_merchant_model = 'direct' THEN 'direct' ELSE 'platform' END,
             'driver', 0, 0, 0, 'netted_noncash');
          PERFORM public.write_audit('PLATFORM_SUBSIDY_NETTED', 'orders', p_order_id::text,
            jsonb_build_object('amount', v_credit, 'status', 'netted_noncash'));
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
$function$
;
-- ---------------------------------------------------------------------------
-- Customer-app read path for the checkout screen. v1's zero-argument
-- my_platform_credit() is dropped so the two shapes cannot be confused.
-- ---------------------------------------------------------------------------

drop function if exists public.my_platform_credit();
drop function if exists public._platform_credit_available(uuid);

create or replace function public.my_platform_credit(p_amount_due numeric default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_balance numeric;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED',
                              'available', 0, 'applies', 0);
  end if;
  select balance into v_balance from public.platform_credit_accounts
   where user_id = v_uid;
  v_balance := coalesce(v_balance, 0);
  return jsonb_build_object(
    'ok', true,
    'available', v_balance,
    'applies', case when p_amount_due is null then v_balance
                    else least(v_balance, greatest(p_amount_due, 0)) end,
    'currency', 'EGP');
end;
$function$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

revoke all on public.platform_credit_accounts from public, anon, authenticated;
revoke all on public.platform_credit_ledger from public, anon, authenticated;
revoke all on public.platform_subsidies from public, anon, authenticated;
grant all on public.platform_credit_accounts to postgres, service_role;
grant all on public.platform_credit_ledger to postgres, service_role;
grant all on public.platform_subsidies to postgres, service_role;

revoke all on function public._platform_credit_grant(uuid, numeric, uuid) from public, anon, authenticated;
grant execute on function public._platform_credit_grant(uuid, numeric, uuid) to postgres, service_role;
revoke all on function public._platform_credit_spend(uuid, uuid, numeric) from public, anon, authenticated;
grant execute on function public._platform_credit_spend(uuid, uuid, numeric) to postgres, service_role;
revoke all on function public._platform_credit_restore(uuid, numeric, uuid) from public, anon, authenticated;
grant execute on function public._platform_credit_restore(uuid, numeric, uuid) to postgres, service_role;
revoke all on function public.my_platform_credit(numeric) from public, anon;
grant execute on function public.my_platform_credit(numeric) to authenticated, postgres, service_role;
