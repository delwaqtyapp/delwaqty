-- 228 (H3): backing pieces for the whatsapp-webhook edge function.
-- The webhook is the ONLY path that may mark a code verified, closing the
-- cosmetic loop where request_whatsapp_otp returns the code to the client.
CREATE TABLE IF NOT EXISTS public.whatsapp_webhook_messages (
  message_id text PRIMARY KEY,
  phone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.whatsapp_webhook_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_webhook_messages FROM PUBLIC;
REVOKE ALL ON public.whatsapp_webhook_messages FROM anon;
REVOKE ALL ON public.whatsapp_webhook_messages FROM authenticated;

-- Atomic mark-verified with delivery idempotency. Service-role only: the
-- edge function calls it; no client may verify a code without the
-- WhatsApp round-trip.
CREATE OR REPLACE FUNCTION public.whatsapp_webhook_mark_verified(p_phone text, p_otp_code text, p_message_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_inserted boolean;
BEGIN
  INSERT INTO public.whatsapp_webhook_messages (message_id, phone)
  VALUES (p_message_id, p_phone)
  ON CONFLICT (message_id) DO NOTHING
  RETURNING true INTO v_inserted;
  IF v_inserted IS DISTINCT FROM true THEN
    RETURN false; -- Meta retried an already-processed delivery.
  END IF;

  UPDATE public.whatsapp_otp_verifications
     SET verified = true
   WHERE phone = p_phone
     AND otp_code = p_otp_code
     AND verified = false
     AND expires_at > now()
     AND (locked_until IS NULL OR locked_until < now());
  RETURN FOUND;
END;
$function$
;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.whatsapp_webhook_mark_verified(text, text, text) FROM authenticated;
