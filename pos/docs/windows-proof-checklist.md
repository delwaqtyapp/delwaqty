# Windows proof checklist — cashier data protection (2026-11-23 head)

Manual on-Windows verification for the protection changes (DPAPI
CurrentUser, ACL hardening, key regeneration, legacy repair state). We
cannot run Windows in CI, so each item is a scripted manual pass. Run on a
real Windows 10/11 machine (or VM) with the Pharmacy build.

Setup for all items: install/run the app once as Windows user A
("SHOPPC\Cashi­er"), activate with a test key, make at least one offline
sale (airplane mode) so the outbox holds a pending op. Data dir:
`C:\ProgramData\Delwaqty\Pos` (confirm via AppPaths).

## 1. Cross-user protection

1. Create a second standard Windows user B (Settings → Accounts → Other
   users), sign in as B.
2. Try to open `C:\ProgramData\Delwaqty\Pos` in Explorer.
   Expected: access denied (ACL grants only user A + SYSTEM + Admins).
3. As B, run `certutil -dump` on nothing — instead: copy the data dir to
   B's Desktop with an admin elevate, then run the app as B.
   Expected: device.key does not unprotect under B → key regenerates →
   activation screen appears; B's fresh key cannot read A's sealed state;
   no sale data is shown. The original files under A's install dir remain
   intact.
4. Sign back in as A, run the app.
   Expected: normal startup; if A's own device.key was overwritten by the
   copy test, the app asks for ONE online reactivation and then works; the
   pending outbox op is still queued and uploads after reactivation.

## 2. File-copy to another PC (clone attempt)

1. On PC-1 (activated, pending offline op queued), zip the whole data dir.
2. On PC-2 (same Windows account NAME, fresh app install), unzip into the
   data dir and start the app.
   Expected: DPAPI unprotect fails (different machine/user keys) → key
   regenerates → activation screen; entering the same license key returns
   BOUND_TO_OTHER_DEVICE (server-side device binding). No local sales or
   customers are ever visible on PC-2.
3. Back on PC-1: reactivate online once.
   Expected: the pending op uploads; cashier_daily_close balances include it.

## 3. Uninstall / reinstall recovery

1. With a pending offline op queued, uninstall the app (do NOT delete
   `C:\ProgramData\Delwaqty\Pos`).
2. Reinstall the same build, start as the SAME Windows user.
   Expected: normal startup with no activation prompt (DPAPI blobs still
   unprotect for the same user on the same machine); the pending op is
   still queued and uploads on the next sync.
3. Repeat but reinstall a build with a DIFFERENT protection version (or
   delete only `device.key` to simulate corruption).
   Expected: key regenerates, one online reactivation is required, outbox
   and sales history are preserved and upload after reactivation.

## 4. Legacy flat-layout repair state (upgrade completeness)

1. Build a fake pre-DP1 layout: in a scratch data dir place an `outbox.db`
   with one pending op and a `license.seal` whose payload HMAC was made
   with a DIFFERENT key (support tooling can produce this; the Core test
   `LegacyRepairTests` shows the exact shape).
2. Start the app pointed at that data dir and try to activate.
   Expected: activation is refused with the Arabic repair message
   (LEGACY_DATA_NEEDS_REPAIR); `outbox.db` still exists with its pending
   op; no `merchants/` directory was created.
3. Repeat with a seal whose payload HMAC matches the install's current
   device key (DP1-era install).
   Expected: activation succeeds and the flat files migrate into the
   merchant scope; the pending op uploads.
4. Startup path: with the unverifiable layout present AND a valid
   activation, start the app.
   Expected: blocking Arabic repair dialog, app exits, no file modified.

## 5. Registry of what "good" means

- No plaintext secret ever appears in the data dir: `device.key` starts
  with `DP1:`, `session.cred` with `DP2:`, `license.seal` is JSON with a
  `Seal` over the whole `StateJson`.
- `icacls C:\ProgramData\Delwaqty\Pos` shows exactly: SYSTEM (F),
  BUILTIN\Administrators (F), SHOPPC\<shop account> (F) — no Users,
  no Everyone.
- After ANY forced reactivation: queued ops upload exactly once (server
  dedupes by client_op_id) and no sale appears twice in the daily close.
