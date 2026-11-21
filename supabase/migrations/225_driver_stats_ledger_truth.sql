-- 225 (batch 14 item D): the driver dashboard disagreed with itself because
-- drivers.earnings_balance / total_trips are stale counters — the crediting
-- earnings RPCs never update them, only request_withdrawal debits the
-- balance. driver_earnings + rides are the ledger of record. Make every
-- stats RPC read the ledger, make request_withdrawal check the ledger, and
-- backfill the counters so admin views stop showing zeros.

-- 1) driver_dashboard_stats: totals and balance from the ledger.
CREATE OR REPLACE FUNCTION public.driver_dashboard_stats(p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_owner UUID;
  v_today_rides INTEGER;
  v_today_earnings DECIMAL(10,2);
  v_week_earnings DECIMAL(10,2);
  v_balance DECIMAL(10,2);
  v_pending_withdrawals DECIMAL(10,2);
  v_total_trips INTEGER;
  v_rating DECIMAL(3,2);
  v_acceptance NUMERIC;
BEGIN
  SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'reason', 'forbidden');
  END IF;

  SELECT COUNT(*) INTO v_today_rides FROM rides
    WHERE driver_id = p_driver_id AND status = 'completed'
      AND completed_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings FROM driver_earnings
    WHERE driver_id = p_driver_id AND type IN ('trip','bonus','tip')
      AND created_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_week_earnings FROM driver_earnings
    WHERE driver_id = p_driver_id AND type IN ('trip','bonus','tip')
      AND created_at >= date_trunc('week', NOW());

  -- Ledger truth: completed rides and the full driver_earnings sum
  -- (trip credits minus withdrawals), not the stale denormalized counters.
  SELECT COUNT(*) INTO v_total_trips FROM rides
    WHERE driver_id = p_driver_id AND status = 'completed';

  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM driver_earnings
    WHERE driver_id = p_driver_id;

  SELECT COALESCE(rating, 0) INTO v_rating FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals FROM withdrawal_requests
    WHERE driver_id = p_driver_id AND status IN ('pending','approved');

  SELECT CASE WHEN COUNT(*) = 0 THEN 100
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'accepted') / COUNT(*), 0)
         END INTO v_acceptance
    FROM ride_requests WHERE driver_id = p_driver_id
      AND status IN ('accepted','rejected','expired');

  RETURN jsonb_build_object(
    'success', true,
    'today_rides', v_today_rides,
    'today_earnings', v_today_earnings,
    'week_earnings', v_week_earnings,
    'balance', v_balance,
    'pending_withdrawals', v_pending_withdrawals,
    'total_trips', v_total_trips,
    'rating', v_rating,
    'acceptance_rate', v_acceptance
  );
END;
$function$
;

-- 2) get_driver_performance: same ledger sources for total trips + balance.
CREATE OR REPLACE FUNCTION public.get_driver_performance(p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_trips INTEGER;
  v_completed_trips INTEGER;
  v_cancelled_by_driver INTEGER;
  v_total_offers INTEGER;
  v_acceptance_count INTEGER;
  v_avg_rating DECIMAL;
  v_today_earnings DECIMAL;
  v_week_earnings DECIMAL;
  v_month_earnings DECIMAL;
  v_balance DECIMAL;
  v_bonus DECIMAL;
  v_incentive DECIMAL;
  v_pending_withdrawals DECIMAL;
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('error', 'FORBIDDEN');
  END IF;

  -- Ledger truth: completed rides, not the stale drivers.total_trips counter.
  SELECT COUNT(*) INTO v_total_trips
  FROM rides WHERE driver_id = p_driver_id AND status = 'completed';

  v_completed_trips := v_total_trips;

  SELECT COUNT(*) INTO v_cancelled_by_driver
  FROM rides WHERE driver_id = p_driver_id AND status = 'cancelled' AND cancelled_by = 'driver';

  SELECT COUNT(*) INTO v_total_offers
  FROM ride_requests WHERE driver_id = p_driver_id;

  SELECT COUNT(*) INTO v_acceptance_count
  FROM ride_requests WHERE driver_id = p_driver_id AND status = 'accepted';

  SELECT COALESCE(rating, 0) INTO v_avg_rating FROM drivers WHERE id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('day', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_week_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('week', NOW());

  SELECT COALESCE(SUM(amount), 0) INTO v_month_earnings
  FROM driver_earnings WHERE driver_id = p_driver_id
    AND created_at >= date_trunc('month', NOW());

  -- Ledger truth: full driver_earnings sum, not drivers.earnings_balance.
  SELECT COALESCE(SUM(amount), 0) INTO v_balance
  FROM driver_earnings WHERE driver_id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_bonus
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'bonus';

  SELECT COALESCE(SUM(amount), 0) INTO v_incentive
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'incentive';

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status = 'pending';

  RETURN jsonb_build_object(
    'total_trips', v_total_trips,
    'completed_trips', v_completed_trips,
    'cancelled_trips', v_cancelled_by_driver,
    'rating', v_avg_rating,
    'acceptance_rate', CASE WHEN v_total_offers > 0 THEN ROUND(v_acceptance_count::DECIMAL / v_total_offers * 100, 1) ELSE 100 END,
    'cancellation_rate', CASE WHEN (v_completed_trips + v_cancelled_by_driver) > 0 THEN ROUND(v_cancelled_by_driver::DECIMAL / (v_completed_trips + v_cancelled_by_driver) * 100, 1) ELSE 0 END,
    'today_rides', (SELECT COUNT(*) FROM rides WHERE driver_id = p_driver_id AND status = 'completed' AND completed_at >= date_trunc('day', NOW())),
    'today_earnings', v_today_earnings,
    'week_earnings', v_week_earnings,
    'month_earnings', v_month_earnings,
    'balance', v_balance,
    'bonus_balance', v_bonus,
    'incentive_balance', v_incentive,
    'pending_withdrawals', v_pending_withdrawals,
    'currency', 'EGP'
  );
END;
$function$
;

-- 3) get_driver_wallet_detail: balance from the ledger.
CREATE OR REPLACE FUNCTION public.get_driver_wallet_detail(p_driver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_balance DECIMAL;
  v_bonus DECIMAL;
  v_incentive DECIMAL;
  v_pending_withdrawals DECIMAL;
  v_total_withdrawn DECIMAL;
BEGIN
  IF NOT (EXISTS (
        SELECT 1 FROM public.drivers d
         WHERE d.id = p_driver_id AND d.user_id = auth.uid()
      ) OR public._is_owner_uid(auth.uid())) THEN
    RETURN jsonb_build_object('error', 'FORBIDDEN');
  END IF;

  -- Ledger truth: full driver_earnings sum, not drivers.earnings_balance.
  SELECT COALESCE(SUM(amount), 0) INTO v_balance
  FROM driver_earnings WHERE driver_id = p_driver_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_bonus
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'bonus';

  SELECT COALESCE(SUM(amount), 0) INTO v_incentive
  FROM driver_earnings WHERE driver_id = p_driver_id AND type = 'incentive';

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status = 'pending';

  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawn
  FROM withdrawal_requests WHERE driver_id = p_driver_id AND status IN ('approved','paid');

  RETURN jsonb_build_object(
    'balance', COALESCE(v_balance, 0),
    'bonus_balance', v_bonus,
    'incentive_balance', v_incentive,
    'pending_withdrawals', v_pending_withdrawals,
    'total_withdrawn', v_total_withdrawn,
    'currency', 'EGP'
  );
END;
$function$
;

-- 4) request_withdrawal: balance check against the ledger, and keep the
-- counter in sync for any other reader.
CREATE OR REPLACE FUNCTION public.request_withdrawal(p_driver_id uuid, p_amount double precision, p_method text DEFAULT 'bank'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_owner uuid; v_balance numeric; v_id uuid; BEGIN IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated'); END IF; SELECT user_id INTO v_owner FROM public.drivers WHERE id = p_driver_id FOR UPDATE; IF v_owner IS NULL THEN RETURN jsonb_build_object('success', false, 'reason', 'driver_not_found'); END IF; IF v_owner IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('success', false, 'reason', 'forbidden'); END IF; SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.driver_earnings WHERE driver_id = p_driver_id; IF p_amount IS NULL OR p_amount <= 0 OR p_amount > v_balance THEN RETURN jsonb_build_object('success', false, 'reason', 'insufficient_balance'); END IF; INSERT INTO public.withdrawal_requests (driver_id, amount, status, method) VALUES (p_driver_id, p_amount, 'pending', p_method) RETURNING id INTO v_id; INSERT INTO public.driver_earnings (driver_id, type, amount, description) VALUES (p_driver_id, 'withdrawal', -p_amount, 'Withdrawal request'); UPDATE public.drivers SET earnings_balance = v_balance - p_amount WHERE id = p_driver_id; RETURN jsonb_build_object('success', true, 'withdrawal_id', v_id); END; $function$
;

-- 5) Backfill the denormalized counters from the ledger so admin views and
-- any remaining counter readers agree with the dashboard.
UPDATE public.drivers d
SET earnings_balance = s.earn,
    total_trips = s.completed,
    total_deliveries = s.completed,
    updated_at = now()
FROM (
  SELECT d2.id,
         (SELECT COALESCE(SUM(amount), 0) FROM public.driver_earnings e
           WHERE e.driver_id = d2.id) AS earn,
         (SELECT COUNT(*) FROM public.rides r
           WHERE r.driver_id = d2.id AND r.status = 'completed') AS completed
  FROM public.drivers d2
) s
WHERE s.id = d.id;
