-- 195: service bookings - INSERT normalization + role transition matrix +
--      region-scoped admin authorization.
--
-- Two holes closed:
--   (a) the INSERT policy trusted every client field: a client could insert
--       status='completed' with payment markers and a self-declared
--       provider/category/price, which review + commission logic would trust.
--   (b) update_service_booking_status allowed ANY status from ANY nonterminal
--       state by ANY related party, and scoped admin permission checks with a
--       NULL region (any region admin acted everywhere).
--
-- Matrix (role-aware; terminal states immutable):
--   customer (booking owner): cancel from pending/confirmed only.
--   provider (business owner): pending->confirmed->inProgress->completed.
--     (pending->confirmed is provider acceptance; the chain cannot start
--      without it. Added under the fix-pipeline mandate - flag for override.)
--   admin (owner, or region admin whose coverage includes the booking
--     customer's users.region_id, holding SERVICE_MANAGE or MEMBER_MODERATE):
--     cancel from any nonterminal state.
--   Customer confirm/dispute of completion: NO 'disputed' status exists in
--     the schema - noted as a product gap, not implemented here.

-- 1. BEFORE INSERT normalization: server owns lifecycle/payment/provider truth.
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

  -- The client may not estimate below the provider's own floor.
  if v_provider.fixed_price_min is not null
     and (new.estimated_price is null or new.estimated_price < v_provider.fixed_price_min) then
    new.estimated_price := v_provider.fixed_price_min;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_service_bookings_normalize_insert on public.service_bookings;
create trigger trg_service_bookings_normalize_insert
  before insert on public.service_bookings
  for each row execute function public.service_bookings_normalize_insert();

-- 2. Role transition matrix + region-scoped admin authorization.
CREATE OR REPLACE FUNCTION public.update_service_booking_status(p_booking_id uuid, p_status text)
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

  SELECT * INTO v_book
    FROM public.service_bookings
   WHERE id = p_booking_id
   FOR UPDATE;
  IF v_book.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'NOT_FOUND');
  END IF;

  v_is_customer := v_book.user_id = v_uid;
  v_is_provider := public.is_service_provider_owner(v_book.provider_id);

  -- Admin branch is region-scoped (195): the booking's region is the booking
  -- customer's users.region_id, matching the appeals precedent (190).
  IF NOT (v_is_customer OR v_is_provider) THEN
    IF public._is_owner_uid(v_uid) THEN
      v_is_admin := true;
    ELSE
      SELECT region_id INTO v_region FROM public.users WHERE id = v_book.user_id;
      v_is_admin := public.has_permission('SERVICE_MANAGE', v_region, NULL)
        OR public.has_permission('MEMBER_MODERATE', v_region, NULL);
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

  UPDATE public.service_bookings
     SET status = p_status,
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
