-- 181: Settlement parameters per owner decision 2026-11-21
--   - remittance window: 24h -> 12h
--   - suspension trigger: outstanding > 1500 EGP unremitted (was 5000)
--   - suspension duration: 5 days (was the 3-day overdue trigger)
--   - cash ceiling stays 1000, commissions unchanged (7% driver / 3% merchant)
-- The sweep now auto-suspends the driver for 5 days when outstanding
-- obligations exceed 1500, and reactivates after expiry once the balance
-- is back at/below the trigger. Overdue individual obligations still file
-- a high-priority complaint for ops after settlement_escalation_hours.

alter table public.drivers
  add column if not exists settlement_suspended_until timestamptz;

update public.platform_settings set
  settlement_remittance_due_hours = 12,
  settlement_suspension_amount = 1500,
  settlement_suspension_days = 5;

create or replace function public._settlement_escalation_sweep()
returns integer
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_cfg public.platform_settings;
  ob RECORD;
  v_count integer := 0;
  v_driver RECORD;
  v_amount numeric;
  v_days integer;
BEGIN
  PERFORM set_config('app.escalation_rpc', 'true', true);
  SELECT * INTO v_cfg FROM public._settlement_settings();
  v_amount := COALESCE(v_cfg.settlement_suspension_amount, 1500);
  v_days := COALESCE(v_cfg.settlement_suspension_days, 5);

  -- 1) Overdue individual obligations -> ops complaint (unchanged behavior)
  FOR ob IN
    SELECT o.*, d.user_id AS driver_uid
      FROM public.driver_obligations o
      JOIN public.drivers d ON d.id = o.driver_id
     WHERE o.status = 'open'
       AND o.escalated_at IS NULL
       AND o.due_at + make_interval(hours => COALESCE(v_cfg.settlement_escalation_hours, 24)) < now()
  LOOP
    INSERT INTO public.complaints
      (order_id, ride_id, complainant_id, respondent_id, reporter_id,
       complaint_type, category, subject, description, status, priority)
    VALUES
      (ob.order_id, ob.ride_id, ob.driver_uid, ob.driver_uid, ob.driver_uid,
       'driver', 'settlement_overdue',
       'مديونية كاش متأخرة',
       'الكابتن متأخر عن توريد ' || ob.amount::text || ' ' || ob.currency ||
         ' (نوع: ' || ob.kind || '، مستحق لـ ' || ob.owed_to || ') منذ ' ||
         ob.due_at::date::text || '.',
       'pending', 'high');
    UPDATE public.driver_obligations SET escalated_at = now() WHERE id = ob.id;
    v_count := v_count + 1;
  END LOOP;

  -- 2) Outstanding > suspension amount -> auto-suspend 5 days
  FOR v_driver IN
    SELECT o.driver_id, d.user_id AS driver_uid,
           sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) AS outstanding
      FROM public.driver_obligations o
      JOIN public.drivers d ON d.id = o.driver_id
     WHERE o.status IN ('open','disputed')
     GROUP BY o.driver_id, d.user_id
    HAVING sum(o.amount) FILTER (WHERE o.status IN ('open','disputed')) > v_amount
  LOOP
    -- Skip if already suspended for settlement and still within the window
    IF EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = v_driver.driver_id
        AND d.settlement_suspended_until IS NOT NULL
        AND d.settlement_suspended_until > now()
    ) THEN
      CONTINUE;
    END IF;

    UPDATE public.drivers
       SET settlement_suspended_until = now() + make_interval(days => v_days),
           is_online = false
     WHERE id = v_driver.driver_id;
    UPDATE public.users
       SET account_status = 'suspended'
     WHERE id = v_driver.driver_uid
       AND account_status = 'active';

    INSERT INTO public.notifications (user_id, title, body, type, data, priority)
    VALUES (
      v_driver.driver_uid,
      'إيقاف مؤقت لمدة ' || v_days || ' أيام',
      'تم إيقاف حسابك ' || v_days || ' أيام لأن المديونية غير الموردة تجاوزت ' ||
        v_amount::text || ' جنيه. الإجمالي القائم: ' ||
        COALESCE(v_driver.outstanding,0)::text || ' جنيه. قم بالتوريد لاستعادة حسابك.',
      'settlement_suspension',
      jsonb_build_object('driver_id', v_driver.driver_id,
                         'outstanding', v_driver.outstanding,
                         'suspended_days', v_days),
      'high');
    v_count := v_count + 1;

    -- Ops audit trail (kept from previous behavior)
    IF NOT EXISTS (
      SELECT 1 FROM public.complaints c
       WHERE c.respondent_id = v_driver.driver_uid
         AND c.category = 'settlement_suspension_review'
         AND c.status IN ('pending','investigating','escalated','open')
    ) THEN
      INSERT INTO public.complaints
        (complainant_id, respondent_id, reporter_id, complaint_type, category,
         subject, description, status, priority)
      VALUES
        (v_driver.driver_uid, v_driver.driver_uid, v_driver.driver_uid,
         'driver', 'settlement_suspension_review',
         'إيقاف كابتن لتجاوز حد التسوية',
         'تم إيقاف الكابتن ' || v_days || ' أيام: مديونية غير موردة ' ||
           COALESCE(v_driver.outstanding,0)::text || ' جنيه (الحد: ' || v_amount::text || ').',
         'pending', 'urgent');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- 3) Reactivate drivers whose suspension expired and balance is back in limit.
  --    If still over the limit at expiry, extend the suspension another window.
  FOR v_driver IN
    SELECT d.id AS driver_id, d.user_id AS driver_uid, d.settlement_suspended_until,
           COALESCE((SELECT sum(o.amount) FROM public.driver_obligations o
                      WHERE o.driver_id = d.id AND o.status IN ('open','disputed')), 0) AS outstanding
      FROM public.drivers d
     WHERE d.settlement_suspended_until IS NOT NULL
       AND d.settlement_suspended_until <= now()
  LOOP
    IF v_driver.outstanding > v_amount THEN
      UPDATE public.drivers
         SET settlement_suspended_until = now() + make_interval(days => v_days)
       WHERE id = v_driver.driver_id;
      v_count := v_count + 1;
    ELSE
      UPDATE public.drivers SET settlement_suspended_until = NULL WHERE id = v_driver.driver_id;
      UPDATE public.users
         SET account_status = 'active'
       WHERE id = v_driver.driver_uid
         AND account_status = 'suspended';
      INSERT INTO public.notifications (user_id, title, body, type, data, priority)
      VALUES (
        v_driver.driver_uid,
        'تمت استعادة حسابك',
        'انتهت فترة الإيقاف ومديونيتك الحالية ' || v_driver.outstanding::text ||
          ' جنيه ضمن الحد المسموح. يمكنك استقبال الطلبات من جديد.',
        'settlement_reactivation',
        jsonb_build_object('driver_id', v_driver.driver_id,
                           'outstanding', v_driver.outstanding),
        'high');
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

revoke all on function public._settlement_escalation_sweep() from public, anon, authenticated, service_role;
