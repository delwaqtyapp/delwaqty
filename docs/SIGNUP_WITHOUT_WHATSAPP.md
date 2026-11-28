# Signup without WhatsApp (draft, DO NOT APPLY)

Why: the WhatsApp business number approval is pending, so the reverse-OTP signup cannot run. Goal: free, simple signup (phone + password) for non-technical users.

## Research: is there a free SMS OTP in Egypt?
No. Firebase phone auth needs a billing plan since Sept 2024. Twilio Verify costs 0.05 USD per verification plus the SMS fee. Local gateways cost about EGP 0.65 per SMS and need a sender ID (about 100 USD and about 21 business days). Free-to-us variants (user texts a SIM we hold, or a Telegram bot) are fragile or hard for village users, so they are not recommended.
Sources: firebase.google.com/docs/auth/faq-and-troubleshooting, twilio.com/en-us/verify/pricing, twilio.com/en-us/sms/pricing/eg, esmsafrica.io/sms/egypt, ruachnet.com/messaging/sms/markets/egypt/sender-id

## Design
A server flag `platform_settings.feature_flags.signup_phone_mode`:
- absent or `whatsapp` (default): today's behavior, unchanged.
- `password`: signup is phone + password. No OTP. The account is active at once with `users.phone_verified = false`.

Abuse limits in password mode:
- Unique phone: the existing hook checks stay (valid Egyptian mobile, not already registered, identity rules).
- Global breaker: at most `feature_flags.signup_unverified_per_hour` (default 30) unconfirmed signups per hour, else `SIGNUP_BUSY`.
- Unconfirmed customers can only place cash orders, no platform credit, at most 2 open orders (trigger `orders_unverified_limits`).
- The phone is confirmed by a person: admin, the order's driver, or the owning merchant calls the customer and uses `confirm_customer_phone(user_id)` (audited in `audit_log`). Users cannot flip the flag themselves (`users_guard_phone_verified`).
- Existing users and WhatsApp-verified signups are `phone_verified = true`.

Rollback: set the flag back to `whatsapp` (or remove it). Clients fail closed to the WhatsApp path if the RPC fails.

## In this PR
- `supabase/migrations/466_signup_password_mode.sql` (NOT applied to prod).
- `supabase/tests/466_signup_password_mode_test.sql` (wired into CI; green, and two deliberate-break runs go red).
- Register page skips the WhatsApp step when the server says `password`.

## Not in this PR (follow-ups before enabling)
- Merchant/driver UI: "number not confirmed, call the customer" banner and confirm button. Needs a `phoneVerified` field on the order models (freezed regeneration). Until then the RPC works but has no button.
- Courier rides (`request_courier_delivery`) are not limited by the unconfirmed rules.
- Password reset remains WhatsApp-only, so a user who forgets the password needs the admin until WhatsApp is back.
- Enabling needs the owner's word: apply 466, then set the flag.
