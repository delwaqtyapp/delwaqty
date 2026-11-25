# Staff sync runbook (444)

Every staff admin op (enable, disable, reset) is a generation-bound
handshake: the DB arms the op (`sync_state='pending'`, one op slot), the
edge performs the GoTrue effects and attests them in the staff user's
`app_metadata.staff_sync`, and the DB completes only after verifying the
attestation server-side. Arming ANY op cuts staff access immediately.

## Recovery routes

- **Edge dies mid-op** (row left `pending`): after 10 minutes (by
  `merchant_staff.updated_at`) the next arming call treats the op as
  failed and re-arms with a new generation. This also covers an
  abandoned RESET, whose row is inactive: the stale-pending sweep runs
  before the eligibility check, so `staff_admin_record_password_reset`
  re-arms it directly. A fresh `pending` op still refuses with
  `operation already pending`.
- **Explicit failure**: the edge calls `staff_admin_sync_failed` before
  every 502 it returns after arming. A `failed` op re-arms immediately;
  a failed RESET re-arms even though the row is inactive.
- **Lost completion response** (state is `ok` but the edge returned 502
  with no password, e.g. the connection dropped after
  `sync_complete` committed): the op actually COMPLETED. For a reset,
  the new password was delivered to nobody. Recovery: simply request a
  FRESH reset; the row is healthy and re-arms normally. Do not try to
  recover the lost password; it is never stored.
- **Genuinely disabled rows** (completed disable, `sync_state='ok'`,
  `is_active=false`) can never be reset: `staff not found`. Re-enable
  first; enable-then-reset for a timed-out reset is NOT the recovery
  path because enabling can restore access before a replacement
  password is delivered.

## Invariants

- `staff_password_changed` clears `must_change_password` only under
  FOR UPDATE + CAS: the row must still be active, settled
  (`sync_state='ok'`) and un-rotated (digest IS DISTINCT FROM the live
  GoTrue digest). A concurrent reset always re-arms the barrier.
- Attestation is fail-closed: `_staff_sync_attested` (private) requires
  an object with the exact generation and op (IS DISTINCT FROM) and a
  timestamp within now()-10min .. now()+2min; anything else refuses.
- `merchant_staff_events` is append-only; `password_digest`,
  `sync_state`, `sync_op`, `sync_generation` are never exposed to
  anon/authenticated (column-level SELECT).
