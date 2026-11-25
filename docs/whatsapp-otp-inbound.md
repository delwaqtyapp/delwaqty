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
 |<-- ok + otp_code ---------|  (today, by design; cutover      |
 |                           |   below stops returning it)     |
 |-- open wa.me prefilled ---|------------ user sends code --->|
 |                            |<-- POST /whatsapp-webhook -----|
 |                            |  mark verified (228)           |
 |-- poll verification ------>|                                 |
 |    status RPC ------------>|                                 |
 |<-- verified=true ----------|                                 |
```

1. **Meta setup (dashboard action, one time):** a dedicated Cloud API
   number (the `whatsapp_otp_number` destination — interim test number or
   the platform's own SIM, see Operations; NEVER the protected support
   line); webhook URL
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
   by grant design (anon and authenticated have no EXECUTE). Idempotent per Meta message
   id via `whatsapp_webhook_messages`; atomically sets `verified = true`
   only for an unexpired, unlocked, unverified matching code.
4. **Cutover (future direction, unscheduled - NOT part of this change):**
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
`platform_settings.whatsapp_otp_number` (migration 434). There is NO
fallback to `support_phone`: migration 434 removed the fallback that 414
carried, because the production `support_phone` is the protected support
line (+201555570885) and routing OTP traffic there was the bug being
fixed. When the override is unset or malformed the RPC fails closed with
`WHATSAPP_NOT_CONFIGURED` instead of guessing a destination.

Rules that keep this safe:

- The protected support line (+201555570885) must NEVER be set as
  `whatsapp_otp_number` and must NEVER be used for OTP smoke tests.
- `whatsapp_otp_number` is owner-only: the
  `guard_platform_settings_owner_fields` trigger rejects changes from
  anyone but the platform owner (same pattern as migration 393).
- The OTP destination is infrastructure — the Meta Cloud API number this
  webhook watches — not the customer support contact; keep them in
  separate columns and change them independently.

### Why sign-in with WhatsApp was dead (root cause, Nov 24)

The number in `support_phone` was registered on the consumer WhatsApp
Business app, not the Cloud API. Meta only delivers webhook events for
numbers onboarded to the Cloud API, so no real message should ever have
reached this webhook. Consistent with that: an inspection of
`whatsapp_webhook_messages` on Nov 24, 2026 found only synthetic
`wamid.demoNNN` test posts and no real inbound delivery. The webhook
function, secrets, and challenge flow were deployed, but because Meta
never delivered an event, the end-to-end path has never been observed
working in production.

Removing the `support_phone` fallback (434) is therefore not expected to
break a working sign-in: the Nov 24 inspection found no real delivery and
no `verified_via='webhook'` row attributable to one. If a working login
did somehow depend on that path, the failure mode is a clear
`WHATSAPP_NOT_CONFIGURED` error, recoverable by setting the override.

### Interim: Meta's free Cloud API test number

Superseded Nov 25, 2026: the dedicated Egyptian SIM is registered on the
Cloud API (see the registration record below); the interim test-number
path is no longer the plan of record.

Until the platform has its own SIM, point `whatsapp_otp_number` at the
Meta app's test number (any country code — the +1 test number is why the
migration validates generic E.164, not `^\+201`).

CAVEAT: whether Meta's test number delivers INBOUND messages to webhooks
is UNVERIFIED - this PR cites no Meta documentation for it. Treat it as
unproven until confirmed by a Meta documentation citation or one approved
smoke test: a single real WhatsApp send to the test number on an approved
line (see checklist), never to the protected support line. The
test-number limits apply to outbound sends, which this design never
uses.

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
4. Smoke test (on an approved line, never the protected support line):
   Meta's "Send test message" webhook sample, then one real WhatsApp
   send; expect the function's `received`/`results` JSON response shape
   and a `verified_via='webhook'` row.

## Registration record (Nov 25, 2026): dedicated number live on Cloud API

The platform number +201550692655 (dedicated Egyptian SIM) is registered
on the Cloud API under the business portfolio "دلوقتي"
(business_id 999347779858871):

- WABA "دلوقتي": id 2210575052859324
- Phone number: id 1538371209348768 (+20 15 50692655, display name
  "دلوقتي", category Shopping & Retail, display-name review pending —
  Meta reviews within ~24h; inbound works meanwhile)
- App-level webhook subscription ACTIVE: object
  `whatsapp_business_account`, field `messages`, callback
  `https://bttnlkmwhorjamzemwda.supabase.co/functions/v1/whatsapp-webhook`

Actual flow that worked (the Delwaqty app has no WhatsApp product/use
case in the new developer dashboard, so App Dashboard > WhatsApp setup
does not exist for it):

1. Business Manager > business info: Meta required full legal business
   details before any WhatsApp setup.
2. Business Settings > Messaging accounts (حسابات المراسلة) > create
   WhatsApp account: creates the WABA and onboards the SIM; Meta texts
   the SIM a 6-digit code (relayed by the owner).
3. Business Settings > Apps > Add > link the Delwaqty app id to the
   portfolio (auto-approved as app admin).
4. Business Settings > System users: created "Delwaqty API" (Admin) and
   assigned the WhatsApp account asset with full control. NOTE: the BM
   token wizard shows "no permissions available" for the Delwaqty app
   (an app needs the WhatsApp product for `whatsapp_business_management`
   scope, and this app's type cannot add it), so `POST
   /{waba}/subscribed_apps` cannot be driven by API from the app token.
   For this inbound-only OTP design the app-level webhook subscription
   (step 5) plus same-portfolio app linking is what makes events flow.
5. App-level webhook subscription via Graph API
   (`POST /{app-id}/subscriptions`, app access token): object
   `whatsapp_business_account`, field `messages`. This is the piece that
   was already live since Nov 24.

Platform setting: `platform_settings.whatsapp_otp_number =
'+201550692655'` applied on staging (adcgqoccrgauqdoplsgg) Nov 25;
prod apply pending owner approval and reviewer GO.

This section is a historical registration/staging record only. It is NOT
authorization for any prod deploy or apply; prod keeps its own gates
(both reviewer GOs, green CI, explicit owner/main order). Operational
Meta claims above (webhook subscription active, live inbound, ~24h
display-name review) are as reported by the registration agent, not
independently verified.

Verify inbound delivery after any wiring change: run the real pending
OTP flow from an approved phone - request a code in the app, send it by
WhatsApp to +201550692655, and assert `verified_via='webhook'` on the
OTP row plus the matching Meta message id in
`whatsapp_webhook_messages`. (A code-less message proves nothing here:
the webhook skips it before the RPC, and ids are recorded only after a
successful pending-OTP verify.) To verify code-less transport itself,
use raw Meta delivery evidence (Graph API responses, Meta dashboard
webhook logs) instead.
