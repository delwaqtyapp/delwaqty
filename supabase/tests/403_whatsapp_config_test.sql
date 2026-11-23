-- Run after403. No outbound traffic and every fixture rolls back.
BEGIN;
UPDATE public.platform_settings SET support_phone=NULL WHERE id='default';
DO $$ DECLARE r jsonb; BEGIN
r:=public.request_whatsapp_otp('+201000000099','register');
ASSERT r->>'code'='WHATSAPP_NOT_CONFIGURED';
END $$;
ROLLBACK;
