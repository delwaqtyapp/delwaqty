-- Staging rollback-only. Requires 403 and 414. Synthetic fixtures, no messages.
BEGIN;

-- Fixtures (as postgres): one synthetic customer, a configured support phone,
-- one active and one inactive coupon, one active and one inactive promo code.
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
('fb414000-0000-4000-8000-000000000001','zz414-customer@example.invalid','{"user_type":"customer"}');
INSERT INTO public.platform_settings(id, support_phone) VALUES ('default','+201000000414')
ON CONFLICT (id) DO UPDATE SET support_phone='+201000000414';
INSERT INTO public.coupons(code, discount_type, discount_value, is_active) VALUES
('ZZ414ACTIVE','percentage',10,true),
('ZZ414INACTIVE','percentage',10,false);
INSERT INTO public.promo_codes(code, discount_type, discount_value, is_active) VALUES
('ZZ414PROMO','percentage',10,true),
('ZZ414PROMOOFF','percentage',10,false);
DELETE FROM public.identifier_lookup_attempts WHERE k LIKE 'otp-ip:203.0.113.%' OR k LIKE 'ip:203.0.113.%';
DELETE FROM public.whatsapp_otp_verifications WHERE phone LIKE '+2015554141%' OR phone = '+201000414140';

DO $test$
BEGIN
  ASSERT md5(pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)) = '2e2f0086c65bac716c937af718debf86', '414 function live';
  ASSERT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coupons' AND policyname='coupons authenticated read' AND cmd='SELECT' AND roles='{authenticated}' AND qual='(is_active = true)'), 'coupons read policy authenticated-only';
  ASSERT NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coupons' AND policyname='Coupons are viewable by everyone'), 'anon coupons read policy removed';
  ASSERT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='promo_codes' AND policyname='promo authenticated read' AND cmd='SELECT' AND roles='{authenticated}' AND qual='(is_active = true)'), 'promo read policy authenticated-only';
  ASSERT NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='promo_codes' AND policyname='promo public read'), 'anon promo read policy removed';
END;
$test$;

-- (7a) Per-phone 3-per-10-minutes cap preserved, then per-IP hourly bucket caps.
SET LOCAL ROLE anon;
SELECT set_config('request.headers','{"x-forwarded-for":"203.0.113.114"}',true);
DO $test$
DECLARE r jsonb; g int;
BEGIN
  FOR g IN 1..3 LOOP
    r := public.request_whatsapp_otp('+201000414140');
    ASSERT (r->>'ok')::boolean, 'per-phone call ' || g || ' must pass';
  END LOOP;
  r := public.request_whatsapp_otp('+201000414140');
  ASSERT r->>'code' = 'RATE_LIMITED', 'per-phone 4th call must be RATE_LIMITED';
  -- 3 successful calls consumed 3 of the 30/hour IP bucket; the blocked call did not.
  FOR g IN 1..27 LOOP
    r := public.request_whatsapp_otp('+2015554141' || lpad(g::text,2,'0'));
    ASSERT (r->>'ok')::boolean, 'ip bucket call ' || g || ' must pass';
  END LOOP;
  r := public.request_whatsapp_otp('+201555414199');
  ASSERT r->>'code' = 'RATE_LIMITED', '31st call from one IP must be RATE_LIMITED';
END;
$test$;
RESET ROLE;
DO $test$
BEGIN
  -- Bucket rows are RLS-invisible to anon; assert them as postgres.
  ASSERT EXISTS(SELECT 1 FROM public.identifier_lookup_attempts WHERE k='otp-ip:203.0.113.114' AND n=31), 'otp-ip bucket counted 30 allowed + 1 rejected';
  ASSERT NOT EXISTS(SELECT 1 FROM public.identifier_lookup_attempts WHERE k='ip:203.0.113.114'), 'lookup ip namespace untouched';
END;
$test$;

-- (7b) A different IP is unaffected (per-IP, not global), and the 403 gates are intact.
SET LOCAL ROLE anon;
SELECT set_config('request.headers','{"x-forwarded-for":"203.0.113.115"}',true);
DO $test$
DECLARE r jsonb;
BEGIN
  r := public.request_whatsapp_otp('+201555414150');
  ASSERT (r->>'ok')::boolean, 'fresh IP must not inherit the other IP bucket';
END;
$test$;
RESET ROLE;
UPDATE public.platform_settings SET support_phone='' WHERE id='default';
SET LOCAL ROLE anon;
SELECT set_config('request.headers','{"x-forwarded-for":"203.0.113.115"}',true);
DO $test$
DECLARE r jsonb;
BEGIN
  r := public.request_whatsapp_otp('+201555414151');
  ASSERT r->>'code' = 'WHATSAPP_NOT_CONFIGURED', 'fail-closed gate preserved';
  r := public.request_whatsapp_otp('123');
  ASSERT r->>'code' = 'INVALID_PHONE', 'phone format gate preserved';
END;
$test$;
RESET ROLE;
UPDATE public.platform_settings SET support_phone='+201000000414' WHERE id='default';

-- (8a) Anon can no longer read active coupons or promos.
SET LOCAL ROLE anon;
DO $test$
BEGIN
  ASSERT (SELECT count(*) FROM public.coupons WHERE code LIKE 'ZZ414%') = 0, 'anon sees no coupons';
  ASSERT (SELECT count(*) FROM public.promo_codes WHERE code LIKE 'ZZ414PROMO%') = 0, 'anon sees no promos';
END;
$test$;
RESET ROLE;

-- (8b) Signed-in customer still lists active coupons, never inactive ones,
-- and the server-side redeem path still validates.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','fb414000-0000-4000-8000-000000000001',true);
DO $test$
DECLARE r jsonb;
BEGIN
  ASSERT (SELECT count(*) FROM public.coupons WHERE code='ZZ414ACTIVE') = 1, 'customer sees active coupon';
  ASSERT (SELECT count(*) FROM public.coupons WHERE code='ZZ414INACTIVE') = 0, 'customer cannot see inactive coupon';
  ASSERT (SELECT count(*) FROM public.promo_codes WHERE code='ZZ414PROMO') = 1, 'customer sees active promo';
  ASSERT (SELECT count(*) FROM public.promo_codes WHERE code='ZZ414PROMOOFF') = 0, 'customer cannot see inactive promo';
  r := public.redeem_coupon('ZZ414ACTIVE', auth.uid());
  ASSERT (r->>'success')::boolean, 'customer can still redeem active coupon';
  r := public.redeem_coupon('ZZ414INACTIVE', auth.uid());
  ASSERT r->>'reason' = 'coupon_inactive', 'inactive coupon still rejected server-side';
END;
$test$;
RESET ROLE;

SELECT 'PASS414: per-phone OTP cap kept, per-IP bucket caps at 30/hour, gates intact, anon promo reads denied, customer coupon flows intact' AS result;
ROLLBACK;
