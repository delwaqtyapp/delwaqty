-- 196: auditor recheck items on 194/195.
--
-- 1. _finalize_order_cancel now also releases the driver from the dead ride:
--    clears driver_locations.ride_id and closes open ride_requests
--    ('offered' -> expired, 'accepted' -> cancelled) for every ride of the
--    order. Previously only the rider-cancel wrapper did this, so cancel_order
--    / refusal / incident / merchant-reject paths left a driver pointing at a
--    cancelled ride and stale open requests.
--
-- 2. update_service_booking_status admin gate: permission check alone let a
--    region admin act on bookings of NULL-region customers (has_permission
--    skips its geographic gate on NULL). Now additionally gated by
--    _admin_scope_allows(customer_region): NULL region => owner/global only.
--
-- 3. Booking price hardening: negative/zero estimated_price rejected at
--    insert; providers may set final_price through the status RPC (the only
--    client path past the guard trigger); completion commission base stays
--    COALESCE(final_price, estimated_price, 0), now with both inputs
--    validated positive.

-- 1. Finalizer: dispatch cleanup.
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
$func$;
revoke all on function public._finalize_order_cancel(uuid, text, text, boolean, boolean, boolean, text) from public, anon, authenticated;

-- 2+3. Booking RPC: region-gated admin + provider final_price.
drop function if exists public.update_service_booking_status(uuid, text);
CREATE OR REPLACE FUNCTION public.update_service_booking_status(p_booking_id uuid, p_status text, p_final_price numeric default null)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_book service_bookings%ROWTYPE;
  v_is_customer boolean;
  v_is_provider boolean;
  v_is_admin boolean := false;
  v_region uuid;
  v_allowed boolean := false;
  v_cur_status text;
  v_provider_uid uuid;
  v_gross numeric;
  v_rate numeric;
  v_commission numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'UNAUTHENTICATED');
  END IF;
  IF p_status NOT IN ('confirmed','inProgress','completed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_STATUS');
  END IF;
  IF p_final_price IS NOT NULL AND p_final_price <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_PRICE');
  END IF;

  SELECT * INTO v_book
    FROM public.service_bookings
   WHERE id = p_booking_id
   FOR UPDATE;
  IF v_book.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  v_is_customer := v_book.user_id = v_uid;
  v_is_provider := public.is_service_provider_owner(v_book.provider_id);

  -- Admin branch is region-scoped (195/196): the booking's region is the
  -- booking customer's users.region_id; NULL-region customers fall back to
  -- owner/global admins only (_admin_scope_allows), matching the 194
  -- incident pattern and the 190 appeals precedent.
  IF NOT (v_is_customer OR v_is_provider) THEN
    IF public._is_owner_uid(v_uid) THEN
      v_is_admin := true;
    ELSE
      SELECT region_id INTO v_region FROM public.users WHERE id = v_book.user_id;
      v_is_admin := (public.has_permission('SERVICE_MANAGE', NULL, NULL)
                  OR public.has_permission('MEMBER_MODERATE', NULL, NULL))
                AND public._admin_scope_allows(v_region);
    END IF;
  END IF;

  IF NOT (v_is_customer OR v_is_provider OR v_is_admin) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_YOUR_BOOKING');
  END IF;

  v_cur_status := v_book.status;
  IF v_cur_status IN ('completed','cancelled') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'TERMINAL_STATE', 'status', v_cur_status);
  END IF;

  -- Role transition matrix.
  IF v_is_customer THEN
    v_allowed := p_status = 'cancelled' AND v_cur_status IN ('pending','confirmed');
  ELSIF v_is_provider THEN
    v_allowed := (v_cur_status = 'pending'    AND p_status = 'confirmed')
              OR (v_cur_status = 'confirmed'  AND p_status = 'inProgress')
              OR (v_cur_status = 'inProgress' AND p_status = 'completed');
  ELSE -- region-scoped admin: support cancellation only
    v_allowed := p_status = 'cancelled';
  END IF;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'INVALID_TRANSITION',
      'from', v_cur_status, 'to', p_status);
  END IF;

  -- Only the provider may quote the final price, and only while the booking
  -- is live (196: commission base = provider final_price, else estimate).
  IF p_final_price IS NOT NULL AND NOT v_is_provider THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'PRICE_PROVIDER_ONLY');
  END IF;

  UPDATE public.service_bookings
     SET status = p_status,
         final_price = CASE WHEN p_final_price IS NOT NULL THEN p_final_price ELSE final_price END,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_booking_id;

  -- Completion records the platform's commission on the provider: the agreed
  -- price (final when set, else the estimate) at the provider rate, once.
  IF p_status = 'completed' THEN
    SELECT user_id INTO v_provider_uid
      FROM public.service_providers WHERE id = v_book.provider_id;
    IF v_provider_uid IS NOT NULL THEN
      v_gross := COALESCE(v_book.final_price, v_book.estimated_price, 0);
      v_rate := COALESCE(
        public.get_commission_rate('provider', v_book.category_type, v_provider_uid), 0);
      v_commission := public.calculate_commission(v_gross, v_rate);
      INSERT INTO public.platform_commissions
        (member_id, reference_type, reference_id, gross_amount, commission_rate,
         commission_amount, net_amount, currency, status)
      VALUES (v_provider_uid, 'service_booking', p_booking_id, v_gross, v_rate,
              v_commission, v_gross - v_commission, 'EGP', 'computed')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$function$;

-- 3b. INSERT normalization: reject non-positive estimates outright.
create or replace function public.service_bookings_normalize_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_provider public.service_providers%rowtype;
begin
  -- Lifecycle and payment state are server-owned; a fresh booking is always
  -- a pending, unpaid request with no completion or collection markers.
  new.status := 'pending';
  new.completed_at := null;
  new.payment_status := 'unpaid';
  new.cash_collected_at := null;
  new.cash_collected_by := null;
  new.final_price := null;

  -- Provider truth comes from the provider row, never the client payload.
  select * into v_provider from public.service_providers where id = new.provider_id;
  if not found then
    raise exception 'PROVIDER_NOT_FOUND';
  end if;
  new.provider_name := v_provider.name;
  new.category_type := v_provider.category_type;

  -- 196: no zero/negative estimates; the provider floor still applies.
  if new.estimated_price is not null and new.estimated_price <= 0 then
    raise exception 'INVALID_PRICE';
  end if;
  if v_provider.fixed_price_min is not null
     and (new.estimated_price is null or new.estimated_price < v_provider.fixed_price_min) then
    new.estimated_price := v_provider.fixed_price_min;
  end if;

  return new;
end;
$function$;
