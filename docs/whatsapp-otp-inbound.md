# WhatsApp OTP: inbound verification (H3)

## Problem

`request_whatsapp_otp` returns the generated code to the caller (`otp_code`
in the RPC response) and the app deep-links the user into WhatsApp with the
code prefilled. Nothing today proves the user controls that WhatsApp
number: the app already holds the code and can skip the round-trip
entirely. The "WhatsApp verification" is cosmetic until the code comes back
through Meta's platform from the user's own number.

## Design

```
app                          Supabase                         Meta Cloud API
 |-- request_whatsapp_otp -->|                                 |
 |<-- ok (NO otp_code) ------|                                 |
 |-- open wa.me prefilled ---|------------ user sends code --->|
 |                            |<-- POST /whatsapp-webhook -----|
 |                            |  mark verified (228)           |
 |-- poll verification ------>|                                 |
 |    status RPC ------------>|                                 |
 |<-- verified=true ----------|                                 |
```

1. **Meta setup (dashboard action, one time):** WhatsApp Business app on
   the platform support number; webhook URL
   `https://bttnlkmwhorjamzemwda.supabase.co/functions/v1/whatsapp-webhook`;
   subscribe to `messages`.
2. **Edge function `whatsapp-webhook`** (supabase/functions/whatsapp-webhook):
   - GET: Meta handshake, gated by `WHATSAPP_VERIFY_TOKEN` (secret).
   - POST: requires `X-Hub-Signature-256` matching HMAC-SHA256 of the raw
     body with `WHATSAPP_APP_SECRET` (secret). Deployed `--no-verify-jwt`;
     the HMAC is the authentication.
   - Extracts sender + first 6-digit code, normalizes Egyptian numbers the
     same way `_normalize_egypt_phone` does, calls
     `whatsapp_webhook_mark_verified` (228) with the Meta message id.
   - Always 200 after signature validation so Meta does not retry forever.
3. **`whatsapp_webhook_mark_verified` (migration 228):** service-role only
   (anon + authenticated get 42501, verified). Idempotent per Meta message
   id via `whatsapp_webhook_messages`; atomically sets `verified = true`
   only for an unexpired, unlocked, unverified matching code.
4. **Cutover (follow-up, after the webhook is live):**
   - Stop returning `otp_code` from `request_whatsapp_otp` to clients
     (keep it for owner/admin test tooling only).
   - Register flow: after the user sends the WhatsApp message, the app
     polls a status RPC (e.g. `whatsapp_otp_status(phone, purpose)` ->
     pending/verified/expired) or subscribes to the row via Realtime,
     then proceeds without ever seeing the code.
   - Keep `verify_whatsapp_otp(phone, code)` as the manual fallback for
     users who typed the code from their own WhatsApp client.

## Security notes

- Never log the OTP body; the webhook logs message ids and phones only.
- Rate limiting already lives in `request_whatsapp_otp` (3 codes / phone /
  10 min) and `attempts`/`locked_until` on verification.
- Idempotency is on Meta's message id, not the code, so a retried delivery
  can never double-verify or mask a failed first attempt.
- The webhook never reveals whether a phone has a pending code beyond the
  boolean result, and only to Meta (signature-gated).
