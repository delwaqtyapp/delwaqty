-- ============================================================
-- 110_storefront_and_working_hours_writers.sql
-- Two merchant capabilities had a table, an RLS policy and a READER,
-- but no writer at all:
--
--   * merchants_update_own exists, so a merchant is allowed to edit their
--     storefront — but no page and no RPC existed, so the capability was
--     unreachable.
--   * working_hours is read by provider_get_availability and rendered
--     read-only in the availability page: a merchant could switch the
--     store open/closed but could never set opening hours.
--
-- Both are added here, scoped to the caller's own merchant and with
-- validation, so the client cannot write another store's row.
-- ============================================================

-- ─── 1. storefront update ──────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_my_storefront(
  p_name text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_logo_url text DEFAULT NULL,
  p_cover_url text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_delivery_fee numeric DEFAULT NULL,
  p_min_order numeric DEFAULT NULL,
  p_delivery_time_min integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_merchant uuid;
BEGIN
  v_merchant := public.resolve_my_merchant();
  IF v_merchant IS NULL THEN
    RAISE EXCEPTION 'No merchant store for this account';
  END IF;

  IF p_name IS NOT NULL AND btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Store name cannot be empty';
  END IF;

  -- COALESCE keeps every field optional so the caller can PATCH one
  -- value without resending the whole storefront.
  UPDATE public.merchants
     SET name = COALESCE(NULLIF(btrim(p_name), ''), name),
         description = COALESCE(p_description, description),
         logo_url = COALESCE(p_logo_url, logo_url),
         cover_url = COALESCE(p_cover_url, cover_url),
         phone = COALESCE(p_phone, phone),
         address = COALESCE(p_address, address),
         latitude = COALESCE(p_latitude, latitude),
         longitude = COALESCE(p_longitude, longitude),
         delivery_fee = COALESCE(p_delivery_fee, delivery_fee),
         min_order = COALESCE(p_min_order, min_order),
         delivery_time_min = COALESCE(p_delivery_time_min, delivery_time_min),
         updated_at = now()
   WHERE id = v_merchant;

  -- Return the stored row, not the inputs.
  RETURN (
    SELECT jsonb_build_object(
      'id', m.id, 'name', m.name, 'description', m.description,
      'logo_url', m.logo_url, 'cover_url', m.cover_url,
      'phone', m.phone, 'address', m.address,
      'latitude', m.latitude, 'longitude', m.longitude,
      'delivery_fee', m.delivery_fee, 'min_order', m.min_order,
      'delivery_time_min', m.delivery_time_min
    )
    FROM public.merchants m
    WHERE m.id = v_merchant
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_storefront(text, text, text, text, text, text, double precision, double precision, numeric, numeric, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_my_storefront(text, text, text, text, text, text, double precision, double precision, numeric, numeric, integer) TO authenticated;

-- ─── 2. working hours writer ───────────────────────────────────
-- p_schedule is a JSON array of
--   {"day": 0..6, "open": "HH:MM", "close": "HH:MM", "closed": false}
-- (0 = Sunday, matching the reader's day_of_week convention).

CREATE OR REPLACE FUNCTION public.provider_set_working_hours(p_schedule jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_merchant uuid;
  v_entry jsonb;
  v_day int;
  v_open text;
  v_close text;
  v_closed boolean;
  v_stored int := 0;
BEGIN
  v_merchant := public.resolve_my_merchant();
  IF v_merchant IS NULL THEN
    RAISE EXCEPTION 'No merchant store for this account';
  END IF;

  IF p_schedule IS NULL OR jsonb_typeof(p_schedule) <> 'array' THEN
    RAISE EXCEPTION 'Schedule must be a JSON array';
  END IF;

  -- Replace the whole schedule atomically so a partial failure can never
  -- leave the store with half a week defined.
  DELETE FROM public.working_hours WHERE merchant_id = v_merchant;

  FOR v_entry IN SELECT * FROM jsonb_array_elements(p_schedule) LOOP
    v_day := COALESCE((v_entry->>'day')::int, -1);
    v_open := v_entry->>'open';
    v_close := v_entry->>'close';
    v_closed := COALESCE((v_entry->>'closed')::boolean, false);

    IF v_day < 0 OR v_day > 6 THEN
      RAISE EXCEPTION 'Invalid day of week: %', v_day;
    END IF;

    IF NOT v_closed
       AND (v_open IS NULL OR v_close IS NULL
            OR v_open !~ '^[0-2][0-9]:[0-5][0-9]$'
            OR v_close !~ '^[0-2][0-9]:[0-5][0-9]$') THEN
      RAISE EXCEPTION 'Invalid time format for day % (expected HH:MM)', v_day;
    END IF;

    IF NOT v_closed AND v_open >= v_close THEN
      RAISE EXCEPTION 'Closing time must be after opening time on day %', v_day;
    END IF;

    INSERT INTO public.working_hours
      (merchant_id, day_of_week, open_time, close_time, is_closed)
    VALUES
      (v_merchant, v_day, v_open::time, v_close::time, v_closed);

    v_stored := v_stored + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'rows', v_stored,
    'merchant_id', v_merchant
  );
END;
$$;

REVOKE ALL ON FUNCTION public.provider_set_working_hours(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provider_set_working_hours(jsonb) TO authenticated;