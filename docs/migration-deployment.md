# Migration deployment procedure

How migrations reach prod, and how to keep the history honest.

## Applying

1. Read `supabase_migrations.schema_migrations` on prod; the highest
   applied version is the starting point.
2. Apply pending files from `supabase/migrations/` in version order,
   one at a time, EXCEPT any file listed in
   `supabase/migrations/SUPERSEDED.txt` (never apply a superseded file;
   apply its replacement instead).
3. Every migration is self-guarding: preconditions (pinned md5s of the
   live functions it replaces, column-absence checks) abort BEFORE any
   mutation when the live state drifted. An abort means stop and
   reconcile, never force.
4. After each apply, record the version in `schema_migrations` (the
   apply tool does this) and run that migration's harness locally
   against a fresh clone when one exists.

## Current reconciliation: 434 vs 442/443

- Prod applied 431, then 435; 434 (`whatsapp_otp_number`) was SKIPPED
  (verified via `schema_migrations`, 2026-11-25).
- 434 and 442 both pin the 393-era `guard_platform_settings_owner_fields`
  pre-image, so applying both makes the second one abort.
- Resolution: apply **442 first** (it pins the 393-era guard), then
  **443_whatsapp_otp_number_rebased.sql** — a rebase of 434 that pins
  the 442 guard body and replaces it with one covering BOTH
  `whatsapp_otp_number` and `feature_flags`. 443 keeps every original
  434 precondition and post-check.
- The original 434 stays in the repo for history, carries a SUPERSEDED
  marker header, and is listed in `supabase/migrations/SUPERSEDED.txt`.
  `tool/superseded_migrations_guard.sh` runs in CI and fails if a
  superseded file loses its marker.
- Release order for the pending chain: 437, 436, 440, 441, 442, 443.
