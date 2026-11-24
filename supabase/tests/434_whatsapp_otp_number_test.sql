-- Rollback suite for migration 434 (dedicated WhatsApp OTP destination).
-- Synthetic fixtures only: sender numbers +201000000xx (never a real or
-- protected line), destination +15550001111 (Meta test-number shape), IP
-- 203.0.113.x (TEST-NET-3, documentation range). Run with
-- psql -v ON_ERROR_STOP=1; any failed assert aborts non-zero.
--
-- Covers: override-only destination (NO support_phone fallback - the
-- protected line must never come back), malformed/empty override fails
-- closed, invalid-phone input, per-phone 3/10min cap, per-IP 30/hour cap
-- across many phones, anon + authenticated ACL execution, owner-only
-- guard on the new column, A0 drift guard logic, atomic rollback shape.

-- Fixtures shared by every block.
create temporary table zz_ctx(c1 uuid, adm uuid);
insert into zz_ctx select gen_random_uuid(), gen_random_uuid();
insert into auth.users(id,email)
select id, id::text||'@example.invalid' from (
  select c1 as id from zz_ctx union all select adm from zz_ctx
) x;
-- c1 is a country admin: RLS lets its UPDATE reach the trigger, so the
-- owner-only guard (not RLS) is what must deny the repoint below.
update public.users set role='admin', user_type='admin', verification_status='approved'
where id = (select c1 from zz_ctx);
insert into public.admin_management (admin_id, supervisor_id, is_active)
values ((select c1 from zz_ctx), (select adm from zz_ctx), true);
insert into public.admin_region_assignments (admin_id, region_id, scope)
values ((select c1 from zz_ctx), '00000000-0000-0000-0000-000000000001', 'descendants');
update public.users set role='owner', user_type='owner', verification_status='approved'
where id = (select adm from zz_ctx);

-- A rolled-back set_config leaves custom GUCs defined-but-empty, which
-- breaks auth.uid()'s json parse; give the session a valid default.
select set_config('request.jwt.claims', '{}', false);

-- 1) Override set: it is the destination returned to callers.
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000091','register');
ASSERT (r->>'ok')::boolean IS TRUE, format('expected ok, got %s', r);
ASSERT r->>'whatsapp_number'='+15550001111', 'override is the destination';
ASSERT r->>'otp_code' ~ '^[0-9]{6}$', 'otp_code returned by design';
END $$;
ROLLBACK;

-- 2) Override UNSET: fails closed - and must NEVER fall back to
-- support_phone (sentinel set to prove it is not consulted).
BEGIN;
UPDATE public.platform_settings SET support_phone='+201999999999', whatsapp_otp_number=NULL WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000092','register');
ASSERT r->>'code'='WHATSAPP_NOT_CONFIGURED', format('unset override must fail closed, got %s', r);
ASSERT r->>'whatsapp_number' IS NULL, 'no destination leaks on failure';
END $$;
ROLLBACK;

-- 3) Override set but malformed: fails closed.
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='not-a-number' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000093','register');
ASSERT r->>'code'='WHATSAPP_NOT_CONFIGURED', 'malformed override fails closed';
END $$;
ROLLBACK;

-- 4) Invalid phone input: non-Egyptian, malformed, empty.
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+15550001111','register');
ASSERT r->>'code'='INVALID_PHONE', 'non-Egyptian sender rejected';
r:=public.request_whatsapp_otp('hello','register');
ASSERT r->>'code'='INVALID_PHONE', 'garbage sender rejected';
r:=public.request_whatsapp_otp('','register');
ASSERT r->>'code'='INVALID_PHONE', 'empty sender rejected';
END $$;
ROLLBACK;

-- 5) Per-phone cap: 4th code for one phone inside 10 minutes is limited
-- (distinct IP so the per-IP bucket is not what fires).
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; i int; BEGIN
perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.50"}', true);
for i in 1..3 loop
  r:=public.request_whatsapp_otp('+201000000095','register');
  ASSERT (r->>'ok')::boolean IS TRUE, format('call %s should pass, got %s', i, r);
end loop;
r:=public.request_whatsapp_otp('+201000000095','register');
ASSERT r->>'code'='RATE_LIMITED', '4th code for one phone is RATE_LIMITED';
END $$;
ROLLBACK;

-- 6) Per-IP cap (414 regression): 30 calls from ONE IP across MANY phones
-- pass; the 31st from the same IP is limited even though every phone is
-- fresh. A different IP is unaffected.
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; i int; BEGIN
perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.60"}', true);
for i in 1..30 loop
  r:=public.request_whatsapp_otp('+201000' || lpad(i::text, 6, '0'),'register');
  ASSERT (r->>'ok')::boolean IS TRUE, format('ip call %s should pass, got %s', i, r);
end loop;
r:=public.request_whatsapp_otp('+201000000031','register');
ASSERT r->>'code'='RATE_LIMITED', '31st call from one IP is RATE_LIMITED';
perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.61"}', true);
r:=public.request_whatsapp_otp('+201000000032','register');
ASSERT (r->>'ok')::boolean IS TRUE, 'a different IP is unaffected';
END $$;
ROLLBACK;

-- 7) ACL: anon and authenticated roles may EXECUTE the RPC (its own
-- validation, not the grant, is the gate).
BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
set local role anon;
perform set_config('request.jwt.claims', '{}', true);
perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.70"}', true);
r:=public.request_whatsapp_otp('+201000000096','register');
ASSERT (r->>'ok')::boolean IS TRUE, format('anon may call, got %s', r);
END $$;
ROLLBACK;

BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; v_c1 uuid := (select c1 from zz_ctx); BEGIN
perform set_config('request.jwt.claims', json_build_object('sub', v_c1)::text, true);
set local role authenticated;
perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.71"}', true);
r:=public.request_whatsapp_otp('+201000000097','register');
ASSERT (r->>'ok')::boolean IS TRUE, format('authenticated may call, got %s', r);
END $$;
ROLLBACK;

-- 8) Owner-only guard on whatsapp_otp_number: a country admin passes RLS
-- (so the trigger actually runs) but is not the owner, so the guard itself
-- must reject the repoint with its exact message. The owner passes.
BEGIN;
DO $$ DECLARE v_msg text; v_c1 uuid := (select c1 from zz_ctx); BEGIN
perform set_config('request.jwt.claims', json_build_object('sub', v_c1)::text, true);
set local role authenticated;
begin
  update public.platform_settings set whatsapp_otp_number='+15550001111' where id='default';
  v_msg := '<no error - update went through>';
exception when others then
  v_msg := sqlerrm;
end;
ASSERT v_msg = 'Only the platform owner can change the WhatsApp OTP destination',
  format('guard must reject non-owner repoint, got: %s', v_msg);
END $$;
DO $$ BEGIN
  ASSERT (SELECT whatsapp_otp_number FROM public.platform_settings WHERE id='default') IS NULL,
    'denied repoint left no value behind';
END $$;
ROLLBACK;

BEGIN;
UPDATE public.platform_settings SET whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE v_adm uuid := (select adm from zz_ctx); BEGIN
perform set_config('request.jwt.claims', json_build_object('sub', v_adm)::text, true);
set local role authenticated;
update public.platform_settings set whatsapp_otp_number='+15550002222' where id='default';
END $$;
DO $$ BEGIN
  ASSERT (SELECT whatsapp_otp_number FROM public.platform_settings WHERE id='default') = '+15550002222',
    'owner can repoint the OTP destination';
END $$;
ROLLBACK;

-- 9) A0 drift guard logic: if the live function ever drifts from the
-- pinned 414 pre-image, the pinned md5 comparison catches it.
BEGIN;
CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
 RETURNS jsonb LANGUAGE plpgsql AS $f$ BEGIN RETURN '{}'::jsonb; END; $f$;
DO $$ BEGIN
  ASSERT md5(pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure))
         <> '2e2f0086c65bac716c937af718debf86',
    'drifted body no longer matches the pinned pre-image md5';
  ASSERT pg_get_functiondef('public.request_whatsapp_otp(text,text)'::regprocedure)
         NOT LIKE '%_lookup_rate_allow%',
    'drifted body no longer contains the per-IP guard marker';
END $$;
ROLLBACK;

-- 10) Atomic rollback shape: a failed migration transaction leaves no
-- trace (column addition rolls back with it).
BEGIN;
ALTER TABLE public.platform_settings ADD COLUMN zz_434_atomic_probe text;
ROLLBACK;
DO $$ BEGIN
ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
  WHERE table_schema='public' AND table_name='platform_settings'
    AND column_name='zz_434_atomic_probe'), 'rolled-back DDL leaves no trace';
END $$;
