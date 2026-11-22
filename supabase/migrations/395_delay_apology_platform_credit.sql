-- 395: make the delay-apology gift spendable as platform credit.
--
-- Today _driver_delay_redispatch grants the customer an apology (7% of the
-- late order, platform_settings.delay_apology_percent) as a wallet credit
-- (wallet_transactions reference_type 'delay_apology'), but nothing can
-- spend from the wallet, so the gift is stranded. This migration keeps the
-- grant path untouched and adds the spend path:
--
--   * orders.platform_credit_applied records the credit consumed per order
--     (frozen from direct client writes by orders_guard_sensitive).
--   * create_order auto-applies the credit server-side as a discount on the
--     customer's next order: min(available credit, wallet balance, amount
--     due after coupon). It cannot go negative, cannot push the discount
--     past the order total, and each pound is spent once (wallet row lock
--     plus the wallets_balance_check constraint).
--   * Every spend writes a wallet_transactions debit
--     (reference_type 'delay_apology_spend', reference_id = the new order)
--     and an activity_logs audit row (PLATFORM_CREDIT_APPLIED).
--   * _finalize_order_cancel returns the credit when the order is cancelled
--     or rejected before delivery (reference_type 'delay_apology_restore',
--     audit PLATFORM_CREDIT_RESTORED) - the same "coupon comes back" rule
--     the owner approved for cancellations.
--   * my_platform_credit() lets the customer app show the gift and the
--     automatic discount at checkout.
--
-- Merchant and captain payouts are untouched: commissions keep computing
-- from orders.subtotal (see merchant_complete_order / complete_delivery),
-- so the platform bears the discount out of its own commission share,
-- matching the apology design ("المنصة تتحمل").
--
-- Expiry: none. The wallet ledger has no expiry concept and the grant
-- carries none, so the credit never expires.
--
-- Available credit is derived from the wallet ledger itself:
--   credits (delay_apology grants + delay_apology_restore)
--   minus debits (delay_apology_spend), floored at zero.
-- wallet_pay can only write debits, so a client cannot forge availability.

alter table public.orders
  add column if not exists platform_credit_applied numeric(10,2) not null default 0;

do $$
begin
  alter table public.orders
    add constraint orders_platform_credit_non_negative
    check (platform_credit_applied >= 0);
exception when duplicate_object then null;
end $$;

-- Remaining gift credit for one customer, from the wallet ledger.
create or replace function public._platform_credit_available(p_user_id uuid)
 returns numeric
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select greatest(coalesce((
    select sum(wt.amount * case when wt.type = 'credit' then 1 else -1 end)
      from public.wallet_transactions wt
      join public.wallets w on w.id = wt.wallet_id
     where w.user_id = p_user_id
       and ((wt.type = 'credit' and wt.reference_type in ('delay_apology', 'delay_apology_restore'))
         or (wt.type = 'debit' and wt.reference_type = 'delay_apology_spend'))
  ), 0), 0);
$function$;

-- Spend up to p_max_amount of the customer's gift credit against an order.
-- Locks the wallet row first: concurrent checkouts serialize here and the
-- second one recomputes availability after the first commits. Returns the
-- amount actually applied (0 when there is nothing to spend).
create or replace function public._platform_credit_spend(p_user_id uuid, p_order_id uuid, p_max_amount numeric)
 returns numeric
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_wallet_id uuid;
  v_balance numeric;
  v_available numeric;
  v_apply numeric;
begin
  if p_user_id is null or p_order_id is null then
    return 0;
  end if;
  if p_max_amount is null or p_max_amount <= 0 then
    return 0;
  end if;
  v_wallet_id := public._ensure_wallet(p_user_id);
  select balance into v_balance from public.wallets where id = v_wallet_id for update;
  v_balance := coalesce(v_balance, 0);
  if v_balance <= 0 then
    return 0;
  end if;
  v_available := public._platform_credit_available(p_user_id);
  v_apply := round(least(v_available, v_balance, p_max_amount), 2);
  if v_apply is null or v_apply <= 0 then
    return 0;
  end if;
  update public.wallets set balance = balance - v_apply, updated_at = now() where id = v_wallet_id;
  insert into public.wallet_transactions
    (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after)
  values
    (v_wallet_id, p_user_id, 'debit', v_apply, 'delay_apology_spend', p_order_id,
     'Platform credit applied to order ' || p_order_id::text, v_balance - v_apply);
  perform public.write_audit('PLATFORM_CREDIT_APPLIED', 'orders', p_order_id::text,
    jsonb_build_object('user_id', p_user_id, 'amount', v_apply,
                       'balance_before', v_balance, 'balance_after', v_balance - v_apply));
  return v_apply;
end;
$function$;

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
  -- never more than the credit balance, never below zero. The wallet ledger
  -- and audit rows are written inside _platform_credit_spend under the
  -- wallet row lock, so concurrent checkouts cannot double-spend it.
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
  -- The early return above on terminal status makes this fire once.
  if coalesce(v_order.platform_credit_applied, 0) > 0 then
    perform public._wallet_credit(
      p_user_id := v_order.user_id,
      p_amount := v_order.platform_credit_applied,
      p_description := 'Platform credit restored from cancelled order ' || p_order_id::text,
      p_reference_type := 'delay_apology_restore',
      p_reference_id := p_order_id);
    perform public.write_audit('PLATFORM_CREDIT_RESTORED', 'orders', p_order_id::text,
      jsonb_build_object('user_id', v_order.user_id,
                         'amount', v_order.platform_credit_applied));
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

-- Customer-app read path for the checkout screen.
create or replace function public.my_platform_credit()
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED', 'available', 0);
  end if;
  return jsonb_build_object(
    'ok', true,
    'available', public._platform_credit_available(v_uid),
    'currency', 'EGP');
end;
$function$;

revoke all on function public._platform_credit_available(uuid) from public, anon, authenticated;
grant execute on function public._platform_credit_available(uuid) to postgres, service_role;
revoke all on function public._platform_credit_spend(uuid, uuid, numeric) from public, anon, authenticated;
grant execute on function public._platform_credit_spend(uuid, uuid, numeric) to postgres, service_role;
revoke all on function public.my_platform_credit() from public, anon;
grant execute on function public.my_platform_credit() to authenticated, postgres, service_role;
