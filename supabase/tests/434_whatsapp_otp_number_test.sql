-- 429: whatsapp_otp_number override precedence and fail-closed config.
-- No outbound traffic and every fixture rolls back.

-- 1) Override unset: falls back to support_phone (existing installs keep working).
BEGIN;
UPDATE public.platform_settings SET support_phone='+201555570885', whatsapp_otp_number=NULL WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000091','register');
ASSERT (r->>'ok')::boolean IS TRUE;
ASSERT r->>'whatsapp_number'='+201555570885', 'fallback to support_phone';
END $$;
ROLLBACK;

-- 2) Override set to a non-Egyptian E.164 number (Meta Cloud API test number):
-- the override wins even though it is not Egyptian.
BEGIN;
UPDATE public.platform_settings SET support_phone='+201555570885', whatsapp_otp_number='+15550001111' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000092','register');
ASSERT (r->>'ok')::boolean IS TRUE;
ASSERT r->>'whatsapp_number'='+15550001111', 'override wins, non-Egyptian allowed';
END $$;
ROLLBACK;

-- 3) Override set but malformed: fails closed, never silently falls back.
BEGIN;
UPDATE public.platform_settings SET support_phone='+201555570885', whatsapp_otp_number='not-a-number' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000093','register');
ASSERT r->>'code'='WHATSAPP_NOT_CONFIGURED', 'malformed override fails closed';
END $$;
ROLLBACK;

-- 4) Both empty: not configured.
BEGIN;
UPDATE public.platform_settings SET support_phone=NULL, whatsapp_otp_number='  ' WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000094','register');
ASSERT r->>'code'='WHATSAPP_NOT_CONFIGURED';
END $$;
ROLLBACK;
