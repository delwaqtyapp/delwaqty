# Email + Facebook signup (draft 467)

Status: DRAFT. Not merged, not applied to prod, not published. Needs the owner's word for each item below.

## Built in the draft
- Signup by email (name, email, password) or Facebook button. Phone signup UI is off when the email flag is on.
- Activation email from our sender. The link opens the app at `io.delwaqty://login-callback/activated`, which signs out, goes to the login page and shows "account is active".
- Facebook button, client and server guard, behind `feature_flags.auth_methods` (`facebook` false by default). Nothing shows until the flag is on.
- Google login unchanged.
- Safety kept: mailbox proven before access, no auto-link by email match, 467 hook guard (format check, hourly breaker, no @delwaqty.app).
- Login by real email resolves in `auth_login_resolve_email`. The 8 old synthetic phone accounts still log in by phone.
- Edit Profile > Login and security: show the password saved on this device (no copy button), set or change the login password, and change email. Each needs fingerprint or phone screen lock first (client-side only). The saved password exists only if the user turned on fingerprint login.
- Change email (shipped): GoTrue mails a confirmation link; the email changes only after it is opened. Migration 468 then copies the new email to `public.users`. Secure email change also asks the OLD address, which does not exist for the 8 @delwaqty.app phone accounts, so email change does not work for them (open item).
- Hotfix 469 (PR #140) closes signup-as-owner/admin and must be applied first.

## Not built yet (phase 2)
- Change phone from Edit Profile (stays read-only: needs WhatsApp verification, which is blocked). Username is already editable.
- Login by username or by the phone saved in the profile (needs a resolver extension and the phone-change rules).
- Provider and driver document uploads need a session, which does not exist before activation.

## What blocks Facebook (owner side)
1. Meta app set to Live.
2. App ID and secret entered in Supabase Auth > Facebook.
3. Redirect URI in Meta: `https://bttnlkmwhorjamzemwda.supabase.co/auth/v1/callback`.
4. Privacy policy URL and data-deletion URL or instructions in the Meta app.
5. Facebook users with no email on their account fail to sign in.
Then set `auth_methods.facebook` true.

## Prod config changes needing approval
- `mailer_autoconfirm` to false (activation email required).
- Activation email template and sender name.
- Add `io.delwaqty://login-callback/activated` (or a wildcard) to `uri_allow_list`.
- Enable the Facebook provider.
- Manual linking on.
- Apply migration 467 (security A0 + apply GO + owner's word).
- Build 17 publish.

## Verify on staging first
- GoTrue may auto-link an OAuth identity to an unconfirmed email account. Must not.
- Whether an email change applies without confirmation under autoconfirm.
- Email send limit (30/hour now, Gmail SMTP) is enough for launch volume.

## Runbook gates (not enforced in SQL; GoTrue settings are not readable from a migration)
- Migration 468 must NOT be applied until `mailer_autoconfirm` is off AND a throwaway-mailbox check shows an email change waits for the new-mailbox link.
- Email flag stays off until: autoconfirm off, activation template and sender work, `io.delwaqty://login-callback/activated` is in `uri_allow_list`, password re-authentication is on.
- Facebook flag stays off until the Meta app is Live and a check shows GoTrue does not auto-link to an unconfirmed email account.
- Order: 469 (#140), then 467 + 468, then Auth config, then throwaway test, then the email flag, then build 17.
