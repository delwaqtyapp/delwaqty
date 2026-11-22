-- 379: prod data backfill after 378 (lab caveat, Nov 22, 2026).
-- Licenses issued BEFORE the pro flag existed default to pro = false, but
-- currently-active trials were sold as a 30-day full (Core + PRO) trial.
-- Flip only those; paid/expired/suspended rows keep pro = false.
UPDATE public.cashier_licenses
   SET pro = true, updated_at = now()
 WHERE plan = 'trial' AND status = 'active' AND NOT pro;

INSERT INTO public.cashier_license_events (license_id, kind, detail)
SELECT id, 'pro_backfill', jsonb_build_object('reason', '378 rollout: active trial keeps full-trial promise')
  FROM public.cashier_licenses
 WHERE plan = 'trial' AND status = 'active' AND pro
   AND NOT EXISTS (SELECT 1 FROM public.cashier_license_events e
                    WHERE e.license_id = cashier_licenses.id AND e.kind = 'pro_backfill');
