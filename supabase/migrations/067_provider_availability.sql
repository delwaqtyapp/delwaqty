-- ============================================================================
-- 067_provider_availability.sql
-- Additive provider availability contract (PHASE 3).
-- Reuses the existing `working_hours` table for merchant schedules and the
-- existing `service_providers.is_available` flag. Adds only the missing
-- merchant-level open/closed source of truth (`merchants.is_open`).
-- No destructive ops; authz enforced inside RPCs (owner-only via auth.uid()).
-- ============================================================================

ALTER TABLE public.merchants ADD COLUMN IF NOT EXISTS is_open boolean NOT NULL DEFAULT true;

-- ---------------------------------------------------------------------------
-- Get effective availability for the calling provider account.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.provider_get_availability()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_merchant   record;
  v_sp         record;
  v_category   text;
  v_is_open    boolean;
  v_schedule   jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id, type, is_open INTO v_merchant FROM public.merchants WHERE id = v_uid;
  IF v_merchant.id IS NOT NULL THEN
    v_category := v_merchant.type;
    v_is_open := v_merchant.is_open;
    SELECT COALESCE(
      jsonb_agg(jsonb_build_object(
        'day_of_week', day_of_week,
        'open_time', open_time,
        'close_time', close_time,
        'is_closed', is_closed
      ) ORDER BY day_of_week),
      '[]'::jsonb)
    INTO v_schedule
    FROM public.working_hours
    WHERE merchant_id = v_uid;
  ELSE
    SELECT id, category_type, is_available INTO v_sp
      FROM public.service_providers WHERE user_id = v_uid;
    IF v_sp.id IS NOT NULL THEN
      v_category := v_sp.category_type;
      v_is_open := v_sp.is_available;
      v_schedule := '[]'::jsonb;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'category', v_category,
    'is_open', COALESCE(v_is_open, true),
    'schedule', COALESCE(v_schedule, '[]'::jsonb)
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Set open/closed for the calling provider account.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.provider_set_availability(p_is_open boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_updated  boolean := false;
  v_category text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'UNAUTHENTICATED');
  END IF;
  IF p_is_open IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID');
  END IF;

  UPDATE public.merchants SET is_open = p_is_open WHERE id = v_uid;
  IF FOUND THEN
    v_updated := true;
  ELSE
    UPDATE public.service_providers SET is_available = p_is_open WHERE user_id = v_uid;
    IF FOUND THEN
      v_updated := true;
    END IF;
  END IF;

  IF NOT v_updated THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NO_PROVIDER');
  END IF;

  SELECT type INTO v_category FROM public.merchants WHERE id = v_uid;
  IF v_category IS NULL THEN
    SELECT category_type INTO v_category FROM public.service_providers WHERE user_id = v_uid;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'code', 'OK', 'is_open', p_is_open, 'category', v_category
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants (authz enforced inside each RPC)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.provider_get_availability() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_get_availability() TO authenticated;

REVOKE ALL ON FUNCTION public.provider_set_availability(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provider_set_availability(boolean) TO authenticated;
