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

## Operations: the destination number (Nov 24, 2026)

`request_whatsapp_otp` reads the destination from
`platform_settings.whatsapp_otp_number` (migration 429), falling back to
`support_phone` when unset. The OTP destination is infrastructure — the
Meta Cloud API number this webhook watches — not the customer support
contact; keep them in separate columns and change them independently.
An override that is set but malformed fails closed
(`WHATSAPP_NOT_CONFIGURED`) rather than falling back silently.

### Why sign-in with WhatsApp was dead (root cause, Nov 24)

The number in `support_phone` was registered on the consumer WhatsApp
Business app, not the Cloud API. Meta only delivers webhook events for
numbers onboarded to the Cloud API, so no real message ever reached this
webhook (all deliveries in `whatsapp_webhook_messages` before the fix are
synthetic `wamid.demoNNN` test posts). Everything else — this function,
the secrets, the challenge flow — was already live and correct.

### Interim: Meta's free Cloud API test number

Until the platform has its own SIM, point `whatsapp_otp_number` at the
Meta app's test number (any country code — the +1 test number is why the
migration validates generic E.164, not `^\+201`). Inbound messages to a
test number fire webhooks normally; the test-number limits apply to
outbound sends, which this design never uses. Verify inbound capability
with one real WhatsApp send after wiring (see checklist).

### End state: dedicated Egyptian SIM

Register the platform's own Egyptian number on the Cloud API in the same
WABA (Meta dashboard > WhatsApp > API Setup > Add phone number; Meta texts
the SIM a one-time code). Then:

1. `UPDATE platform_settings SET whatsapp_otp_number='<new E.164>' WHERE id='default';`
2. Send one real code from any WhatsApp to the new number and confirm a
   `verified_via='webhook'` row appears for the matching
   `whatsapp_otp_verifications` row.
3. Keep the webhook subscription and secrets unchanged.

Never onboard a number that is actively used in the WhatsApp Business
app: Cloud API registration revokes the app session on that line.

### Wiring checklist (Meta dashboard, per environment)

1. App > WhatsApp > Configuration: Callback URL
   `https://<project-ref>.supabase.co/functions/v1/whatsapp-webhook`,
   verify token = vault "Delwaqty WhatsApp webhook verify token".
2. Subscribe to the `messages` webhook field on the WABA.
3. Supabase secrets per project: `WHATSAPP_VERIFY_TOKEN`,
   `WHATSAPP_APP_SECRET` (Meta app secret; rotating it requires updating
   the secret on every project).
4. Smoke test: Meta's "Send test message" webhook sample, then one real
   WhatsApp send; expect `ok:true` in the function response log and a
   `verified_via='webhook'` row.
