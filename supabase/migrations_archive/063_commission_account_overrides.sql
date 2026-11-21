-- ============================================================================
-- 063_commission_account_overrides.sql
-- Product requirement: per-account commission overrides (specific user).
-- Precedence (most specific wins): account override > service_category >
-- account_type default. Historical rules/transactions are NEVER mutated.
--
-- - Extends commission_rules to accept entity_type = 'account' (entity_key =
--   the target user uuid).
-- - get_commission_rate gains an optional p_user_id for the account override.
--   Existing 2-arg callers keep working (backward compatible).
-- - set_commission_rate accepts entity_type = 'account' (still requires the
--   PLATFORM_REVENUE permission; versioned/immutable history preserved).
-- - platform_commission_for_reference now passes the resolved member id so
--   per-account overrides actually apply at order/ride/service computation.
-- Additive; no change to existing rows or historical transactions.
-- ============================================================================

-- 1. Allow the new entity_type
ALTER TABLE public.commission_rules DROP CONSTRAINT IF EXISTS commission_rules_entity_type_check;
ALTER TABLE public.commission_rules ADD CONSTRAINT commission_rules_entity_type_check
  CHECK (entity_type IN ('account', 'account_type', 'service_type', 'service_category'));

-- 2. get_commission_rate with optional specific-account override
CREATE OR REPLACE FUNCTION public.get_commission_rate(
  p_account_type text,
  p_service_category text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rate numeric;
BEGIN
  -- 3. specific account override (highest specificity)
  IF p_user_id IS NOT NULL THEN
    SELECT c.rate INTO v_rate
      FROM public.commission_rules c
     WHERE c.entity_type = 'account'
       AND c.entity_key = p_user_id::text
       AND c.is_active
       AND c.effective_from <= CURRENT_DATE
       AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
     ORDER BY c.effective_from DESC, c.created_at DESC
     LIMIT 1;
    IF v_rate IS NOT NULL THEN
      RETURN v_rate;
    END IF;
  END IF;

  -- 2. service_category
  IF p_service_category IS NOT NULL THEN
    SELECT c.rate INTO v_rate
      FROM public.commission_rules c
     WHERE c.entity_type = 'service_category'
       AND c.entity_key = p_service_category
       AND c.is_active
       AND c.effective_from <= CURRENT_DATE
       AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
     ORDER BY c.effective_from DESC, c.created_at DESC
     LIMIT 1;
    IF v_rate IS NOT NULL THEN
      RETURN v_rate;
    END IF;
  END IF;

  -- 1. account_type default
  SELECT c.rate INTO v_rate
    FROM public.commission_rules c
   WHERE c.entity_type = 'account_type'
     AND c.entity_key = COALESCE(p_account_type, 'customer')
     AND c.is_active
     AND c.effective_from <= CURRENT_DATE
     AND (c.effective_to IS NULL OR c.effective_to >= CURRENT_DATE)
   ORDER BY c.effective_from DESC, c.created_at DESC
   LIMIT 1;
  RETURN v_rate;
END;
$$;

COMMENT ON FUNCTION public.get_commission_rate(text, text, uuid) IS
  'Commission rate. Specificity: account override > service_category > account_type default. Source of truth for 7%/3%.';

-- 3. set_commission_rate: also accept entity_type = 'account'
CREATE OR REPLACE FUNCTION public.set_commission_rate(
  p_entity_type text,
  p_entity_key text,
  p_rate numeric,
  p_effective_from date DEFAULT CURRENT_DATE,
  p_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_id uuid;
  v_current_id uuid;
  v_current_from date;
  v_old_to date;
BEGIN
  IF NOT public.has_permission('PLATFORM_REVENUE', NULL) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_entity_type NOT IN ('account', 'account_type', 'service_type', 'service_category') THEN
    RAISE EXCEPTION 'Invalid entity type';
  END IF;
  IF p_entity_key IS NULL OR btrim(p_entity_key) = '' THEN
    RAISE EXCEPTION 'Entity key is required';
  END IF;
  IF p_rate IS NULL OR p_rate < 0 OR p_rate > 100 THEN
    RAISE EXCEPTION 'Rate must be between 0 and 100';
  END IF;
  p_effective_from := COALESCE(p_effective_from, CURRENT_DATE);

  SELECT c.id, c.effective_from INTO v_current_id, v_current_from
    FROM public.commission_rules c
   WHERE c.entity_type = p_entity_type
     AND c.entity_key = p_entity_key
     AND c.is_active
   ORDER BY c.effective_from DESC, c.effective_from DESC
   LIMIT 1;

  IF v_current_id IS NOT NULL THEN
    v_old_to := GREATEST(v_current_from, p_effective_from);
    UPDATE public.commission_rules
       SET is_active = false,
           effective_to = v_old_to,
           updated_at = now()
     WHERE id = v_current_id;
  END IF;

  INSERT INTO public.commission_rules
    (entity_type, entity_key, rate, currency, effective_from,
     is_active, description, created_by, approved_by)
  VALUES (
    p_entity_type, p_entity_key, p_rate, 'SAR', p_effective_from,
    p_effective_from <= CURRENT_DATE,
    p_description, auth.uid(), auth.uid()
  )
  RETURNING id INTO v_new_id;

  PERFORM public.write_audit(
    'COMMISSION_RATE_CHANGED', 'commission_rules', v_new_id::text,
    jsonb_build_object('entity_type', p_entity_type,
                       'entity_key', p_entity_key,
                       'rate', p_rate,
                       'effective_from', p_effective_from,
                       'description', p_description));

  RETURN v_new_id;
END;
$$;

-- 4. platform_commission_for_reference: pass the resolved member id so
--    per-account overrides apply (only line 321 changed: added 3rd arg).
CREATE OR REPLACE FUNCTION public.platform_commission_for_reference(
  p_reference_type text,
  p_reference_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid           uuid := auth.uid();
  v_member_id     uuid;
  v_account_type  text;
  v_category      text;
  v_gross         numeric;
  v_rate          numeric;
  v_commission    numeric;
  v_net           numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT (public._is_owner_uid(v_uid)
          OR public.has_permission('MEMBER_VIEW', NULL)) THEN
    RETURN NULL;
  END IF;

  IF p_reference_type = 'order' THEN
    SELECT m.owner_user_id, 'merchant', m.type, o.total_amount
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.orders o
      JOIN public.merchants m ON m.id = o.merchant_id
     WHERE o.id = p_reference_id;
  ELSIF p_reference_type = 'ride' THEN
    SELECT d.user_id, 'driver', NULL, COALESCE(r.fare, r.base_fare)
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.rides r
      JOIN public.drivers d ON d.id = r.driver_id
     WHERE r.id = p_reference_id;
  ELSIF p_reference_type = 'service_booking' THEN
    SELECT sp.user_id, 'provider', sb.category_type,
           COALESCE(sb.final_price, sb.estimated_price)
      INTO v_member_id, v_account_type, v_category, v_gross
      FROM public.service_bookings sb
      JOIN public.service_providers sp ON sp.id = sb.provider_id
     WHERE sb.id = p_reference_id;
  END IF;

  IF v_member_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_gross := COALESCE(v_gross, 0);
  v_rate  := public.get_commission_rate(v_account_type, v_category, v_member_id);
  IF v_rate IS NULL THEN
    RETURN NULL;
  END IF;
  v_commission := public.calculate_commission(v_gross, v_rate);
  v_net        := ROUND(v_gross - v_commission, 2);

  INSERT INTO public.platform_commissions
    (member_id, reference_type, reference_id, gross_amount, commission_rate,
     commission_amount, net_amount, currency, created_by)
  VALUES
    (v_member_id, p_reference_type, p_reference_id, v_gross, v_rate,
     v_commission, v_net, 'SAR', v_uid)
  ON CONFLICT (reference_type, reference_id) DO NOTHING;  -- preserve first snapshot

  RETURN jsonb_build_object(
    'member_id',       v_member_id,
    'reference_type',  p_reference_type,
    'reference_id',    p_reference_id,
    'account_type',    v_account_type,
    'service_category', v_category,
    'gross_amount',    v_gross,
    'commission_rate', v_rate,
    'commission_amount', v_commission,
    'net_amount',      v_net,
    'currency',        'SAR'
  );
END;
$$;
