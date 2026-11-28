# Email signup, profile editing and account linking (design only, draft)

Status: design for the owner's 28 Nov 17:56 decision ("we register with email again; edit email, username and phone in Edit Profile; link Google and Facebook"). Nothing here is applied, merged or published. It builds on draft #138 (phone + password mode).

## 1. What works today (read-only checks on prod, 28 Nov)
| Item | State | Evidence |
| --- | --- | --- |
| Google login | Enabled in prod auth config; button exists in build 16; 2 Google identities already exist on prod. Not re-tested end to end today. | auth settings endpoint (`external.google: true`), `auth.identities` counts |
| Facebook login | Not working. Provider is disabled on prod and build 16 has no Facebook button (the code path exists but nothing calls it). | auth settings (`external.facebook: false`), login_page.dart shows Google only |
| Email signup | Blocked by the signup hook (`EMAIL_SIGNUP_NOT_ALLOWED`); email is not accepted as a login identifier in `auth-login-identifier`. | migration 388, function header |
| Email confirmation | None: prod has `mailer_autoconfirm = true`. SMTP is already set to Gmail (free, about 500 mails/day, 30/hour rate limit in config). | management API read of auth config |
| Account linking | Off: `security_manual_linking_enabled = false`, so in-app linking cannot work yet. | auth config |
| Edit Profile | Username editable; phone read-only; no email, no linking. | edit_profile_page.dart |

Facebook needs: the Meta app set Live, its App ID and secret entered in Supabase, and the owner's Facebook account working (it is locked per memory). Basic Facebook Login does not need business verification, but the Live switch and the secret both need that account. Not something to promise until the account is back.

## 2. How email signup fits with #138
The earlier decisions (22 and 25 Nov: no email anywhere, phone + password for non-technical users) are superseded for signup by the owner's 28 Nov 17:56 message. Keep them as flags, not code deletions:

`feature_flags.signup_methods` (server, no new build to flip): any of `email`, `phone_password` (#138), `whatsapp`, `google`. Google stays on.

Email signup flow (free, no OTP cost):
1. User enters email. Supabase emails a 6-digit code through the existing Gmail SMTP (`signInWithOtp`, email template shows the code, not a link, easier for village users).
2. User types the code, then name, phone and a password. The password is set after the code proves the mailbox.
3. Phone is collected (couriers and merchants call customers) but stays unconfirmed; it is confirmed by the call-and-confirm banner from #138. Same unconfirmed limits (cash only, 2 open orders, 2 open rides).
4. Login by email or phone or username + password. `auth-login-identifier` must accept email again (its lockout buckets already lowercase emails).
5. Forgot password for email users: free self-service code by email. The admin recovery code from #138 stays as the fallback for phone-only users.

Why code-first and not email + password + confirm link: with `mailer_autoconfirm = true` an attacker can register a victim's email with their own password before the victim ever does, then keep access after the victim signs in with Google (pre-account hijack). Proving the mailbox before the password is set closes that. Flipping `mailer_autoconfirm` off is NOT recommended now: phone signups use a synthetic `phone_<digits>@delwaqty.app` email that can never receive mail, so they would break.

Hook change (466-style migration): when `email` is in `signup_methods`, allow real emails whose mailbox was proven by the code (not the synthetic domain, not a second account on the same email), and keep the hourly breaker. To verify on staging: that `signInWithOtp` with `shouldCreateUser` passes through the existing hook as intended.

## 3. Edit Profile plan
Principle: every change that can take over or lock out an account needs a fresh sign-in proof (current password, or a session younger than 5 minutes), is rate limited, is audited in `audit_log`, and revokes other sessions when a credential changes.

| Change | Rules |
| --- | --- |
| Username | Already works. Add: case-insensitive unique, reserved words blocked, one change per 7 days. |
| Email | Enter new address, a 6-digit code goes to the NEW address, a notice goes to the OLD one. Applied only after the code. 3 attempts per day, cooldown 24h. Needs the current password. Verify on staging whether GoTrue applies an email change without confirmation while `mailer_autoconfirm` is true; if yes, do the change through an edge function with the code check instead of `updateUser(email)`. |
| Phone | Current password required. The new phone must be unique (existing unique index). It becomes unconfirmed again (back under the limits) until a merchant, driver or admin confirms it by call, or WhatsApp proves it once Meta is back. One change per 30 days. Login by phone switches to the new number. |
| Link Google | Needs `security_manual_linking_enabled = true` (prod config change, owner's word) and `linkIdentity`, from a signed-in, re-authenticated session. Never auto-link by matching email. |
| Link Facebook | Same as Google, after the Facebook provider is configured (section 1). |
| Unlink | Allowed only if another way to sign in remains (password or another identity). Re-authentication required. |

Hijack checks to put in the test plan: a stranger cannot claim someone else's email; a linked identity cannot be attached to a second account; an email or phone change without the password is refused; old sessions die after a credential change; two accounts cannot hold one phone or email.

## 4. Order of work (all staging first)
1. Owner answers the open questions below.
2. Migration + hook + `auth-login-identifier` + `signup_methods` flag, with SQL tests.
3. Signup and login UI for email, email forgot-password.
4. Edit Profile changes (username rules, email, phone, link/unlink Google).
5. Facebook only after the Meta account is usable.
6. Staging acceptance run, then the owner decides on a new build. Installed build 16 has none of this client code.

## 5. Open questions for the owner
- Keep phone + password (#138) as a second option, or email only?
- Still collect a phone number at email signup (recommended: yes, unconfirmed, for courier and merchant calls)?
- OK to enable manual linking and, later, Facebook once the account is usable?
