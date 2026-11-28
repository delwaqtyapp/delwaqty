# Signup without WhatsApp (draft, DO NOT APPLY)

Status: draft for staging only. Not ready to turn on. Nothing here is applied to prod, merged or published.

Why: the WhatsApp business number approval is pending, so the reverse-OTP signup cannot run. Goal: free, simple signup (phone + password) for non-technical users.

## Research: is there a free SMS OTP in Egypt?
No. Firebase phone auth needs a billing plan since Sept 2024. Twilio Verify costs 0.05 USD per verification plus the SMS fee. Local gateways cost about EGP 0.65 per SMS and need a sender ID (about 100 USD and about 21 business days). Free-to-us variants (user texts a SIM we hold, or a Telegram bot) are fragile or hard for village users, so they are not recommended.
Sources: firebase.google.com/docs/auth/faq-and-troubleshooting, twilio.com/en-us/verify/pricing, twilio.com/en-us/sms/pricing/eg, esmsafrica.io/sms/egypt, ruachnet.com/messaging/sms/markets/egypt/sender-id

## Design
A server flag `platform_settings.feature_flags.signup_phone_mode`:
- absent or `whatsapp` (default): today's behavior, unchanged.
- `password`: signup is phone + password. No OTP. The account is active at once with `users.phone_verified = false`.

### Abuse limits in password mode
- Unique phone and the existing hook checks stay (valid Egyptian mobile, canonical identifier, provider allow-list).
- Global breaker: at most `feature_flags.signup_unverified_per_hour` (default 30) unconfirmed signups per hour, else `SIGNUP_BUSY`.
- Unconfirmed customers: cash only, no platform credit, at most 2 open orders (`orders_unverified_limits`) and at most 2 open courier rides (`rides_unverified_limits`). Decision on courier rides: allowed but limited like orders.
- Users cannot flip `phone_verified` themselves (`users_guard_phone_verified`).
- Existing users and WhatsApp-verified signups are `phone_verified = true`.

### Phone confirmation (done by a person, in the app)
- The merchant that owns one of the customer's orders, the driver on one of their orders or courier rides, or an admin sees a "Phone number not confirmed, call the customer" banner (merchant order card, driver delivery detail) with a confirm button.
- The banner only shows when the server says the caller may confirm AND the customer is unconfirmed (`customer_phone_needs_confirmation`). Confirming calls `confirm_customer_phone`, audited in `audit_log`.
- Fix found while building this: the driver check compares `drivers.id` (not the auth user id) to `orders.driver_id` and `rides.driver_id`.

### Forgotten password while WhatsApp is blocked
- The customer calls support. An admin who has checked the person (name, last order) opens Admin > Quick actions > Account recovery, enters the phone and gets a one-time 8-digit code to read out.
- Code: only a salted hash is stored; valid 30 minutes; single use; 5 wrong tries kill it; at most 3 issues per account per day; the account must be the only one with that phone. Issue and use are written to `audit_log` (never the code).
- The customer opens Forgot password (it switches to code mode when the flag is `password`), enters phone, code and a new password. Edge function `recovery-code-reset` consumes the code, sets the password and revokes all sessions.
- Admin-only, human-checked, so a stranger who knows a phone number cannot take over an account without an admin being fooled. This is the main residual risk: admins must check identity before issuing.

### Rollback
Set the flag back to `whatsapp` (or remove it). Clients fall back to the WhatsApp path if the flag RPC fails. Existing unconfirmed users keep working (their limits stay until confirmed).

## How it reaches users
- Installed build 16 has none of this client code. With the flag on, build 16 still shows the WhatsApp step in signup and reset, so it would not help until Meta is approved.
- Needed: apply 466, deploy the `recovery-code-reset` edge function, then publish a new build (17) through the normal flow: version bump PR, green CI/CD on the master sha, "Publish development" run. Existing users get it through the in-app self-update.
- Only after build 17 is out and tested should the flag be switched to `password`. The server pieces are harmless before that because the flag defaults to `whatsapp`.

## Staging-only acceptance checklist (newcomer)
Setup (staging only, never prod): apply 466; deploy `recovery-code-reset`; install the draft build against staging; set `feature_flags` to `{"signup_phone_mode":"password"}`; have one test merchant (with a product), one test driver and one test admin.

1. Register: new phone, name, password. No WhatsApp screen appears. Account opens straight to the customer home. Check `users.phone_verified = false`.
2. Duplicate: register again with the same phone. Refused with "already registered".
3. First order: add an item, pay cash. Order is created. Try instapay or credit: refused with the cash-only message. Place a 3rd open order: refused.
4. Courier ride: request one cash ride. A third open ride is refused.
5. Merchant side: the merchant opens the order. The "Phone number not confirmed" banner and button show. A different merchant (not owner of any of the customer's orders) sees no banner.
6. Confirm: merchant taps confirm after calling. Banner disappears. `users.phone_verified = true`, one `audit_log` row `confirm_customer_phone`.
7. Driver path: repeat 1 to 6 with a second newcomer, confirming from the driver's delivery detail instead.
8. After confirmation: instapay order and a 3rd open order are allowed.
9. Recovery: sign out. Forgot password shows phone, code, new password (no WhatsApp). Admin issues a code for that phone. Wrong code: refused. Right code with a new password: success. Old sessions on another device are signed out. Login with the new password works. Same code again: refused. After 5 wrong tries on a fresh code: refused even with the right one.
10. Breaker: set `signup_unverified_per_hour` to 1, register two newcomers: second gets the busy message. Reset it.
11. Rollback: set the flag to `whatsapp`; signup shows the WhatsApp step again; Forgot password shows the WhatsApp flow.
12. Regression: an existing WhatsApp-verified user logs in and orders normally with instapay.

## Test evidence
- `supabase/tests/466_signup_password_mode_test.sql` (wired into CI): flag, hook, breaker, order limits, ride limits, who may confirm, banner flag, recovery code (issue rights, hash only, wrong code, other phone, single use, 5-try lock, grants). Deliberate-break runs go red.
- `tool/edge_safety_test.cjs`: recovery-code-reset CORS, malformed input, invalid code, session revoke.
- Flutter tests: forgot password in code mode, banner visibility, register page.

## Not covered
- Real SMS verification. A person confirming the phone is the only check.
- No rate limit on `recovery-code-reset` beyond the per-code 5-try lock (an attacker also needs an admin-issued live code).
- Platform-credit orders by unconfirmed customers are blocked; other abuse (fake names) is left to admin review.
