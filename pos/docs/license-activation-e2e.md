# License activation, end to end

## Actors and pieces
- **Platform side**: migrations 340 + 343 + 345. `cashier_licenses` rows are
  issued by the owner or an admin; keys are HMAC-signed (`_cashier_keys`),
  single-line `DLWQ1.<base64url payload>.<hex sig>` strings.
- **Desktop side**: `LicenseKey` (parses + verifies the key structure),
  `LocalLicenseSeal` (stores activation state locally), `SyncClient.DeviceLink`
  (the network call).

## The flow

1. **Issue**: `cashier_license_issue(merchant_id, plan)` → returns the key
   text once. Plans: trial (30d, starts active),
   core_monthly/quarterly/semiannual/annual, core_lifetime. Since review #27
   (346), owners can self-issue the TRIAL only; paid plans are issued by an
   admin after payment is collected (the payment gate) — the RPC rejects them
   with `PAID_PLANS_REQUIRE_ADMIN`. Paid plans start `issued` and activate on
   first device contact.
2. **First run**: the cashier enters the key. The app reads a stable device id
   (machine GUID) and calls `cashier_device_link(key, device_id)`.
   - First contact binds the device and flips the license to `active`
     (event `activated` logged).
   - Response carries plan, status, expiry, grace end, and the merchant
     profile (name/address/phone) + product count — everything the app needs
     to brand and configure itself. Event `linked` logged.
3. **Local seal**: on success the app writes a LocalLicenseSeal (device id,
   plan, expiry, last server check) so restarts need no prompt and offline
   periods work.
4. **Every run**: offline → trust the seal while inside grace; online →
   revalidate with `cashier_license_validate`, which is also what the server
   uses to flip expired licenses to `expired`.

## States the app must render (Arabic-first)
| Server reason | Meaning | App behavior |
|---|---|---|
| `UNKNOWN_KEY` | typo or revoked list | error, allow retry |
| `NOT_AUTHORIZED` | key belongs to another merchant's user | error, contact support |
| `SUSPENDED` | platform suspended | block, contact support |
| `BOUND_TO_OTHER_DEVICE` | key already activated on another PC | block; owner must reissue or support resets device binding |
| `EXPIRED` + `grace_until` | past expiry | grace mode: keep selling until grace end, persistent warning |

## Offline grace (by design, per owner)
A shop must never stop selling because the internet died. Inside
`expires_at + grace_days` the seal alone is enough. Past grace with no
successful revalidation, the app returns to the activation screen but keeps
all local data; syncing resumes after activation.

## Moving to a new PC
Owner/support path: the license is device-bound, so a new PC gets
`BOUND_TO_OTHER_DEVICE`. The fix is an admin/owner action (reset device_id or
issue a replacement key) — deliberately not self-serve, because keys are the
paid product.

## Verified on prod (2026-11-22)
Trial key issued on the bughunt store → device A links (ok, plan, merchant
profile returned) → device B rejected `BOUND_TO_OTHER_DEVICE` → unknown key
rejected `UNKNOWN_KEY` → new keys are single-line (345 fix).
