# FINAL REPORT — Production Readiness Audit (Post Passenger Removal)

**Date:** 2026-08-21 · **Branch:** master · **Latest:** `00e861b`
**Verdict:** STORE READY = 🔴 (environment-blocked, NOT a code defect)

> All code-side safe actions completed. Remaining blockers are **environment-only**:
> no live Supabase DB, `flutter analyze`/`flutter test` disabled (Windows Dev Mode),
> no physical device. These must be cleared at deployment, not fabricated.

## 1. Scope & Direction
DelwaQty = **Order + Delivery + Services only**. Passenger transportation fully
removed. Backend internal identifiers (`reference_type='ride'`, `Ride` entity,
`rides` table) are **deliberately retained** as shared delivery infrastructure.

## 2. Code Removal (Sprint 98) — ✅ COMPLETE
Deleted: ride feature module, booking/tracking/history/driver-hub/trip/offer/register
sheets, `RideModel`/`getRecentRides`, passenger routes. Repointed delivery deep link.
`lib/features/customer/ride/*` survives ONLY as shared infra (`Ride` entity,
`ride_providers`, `ride_map`, `ride_repository`, `supabase_ride_data_source`) —
verified imported by active delivery/dispatch code.

## 3. l10n Terminology Purge — ✅ `28f5316`
Removed 97 dead passenger keys (EN+AR). Kept+renamed 31 delivery terms.
Admin ledger `'ride'` → `l10n.delivery` (backend `reference_type='ride'` unchanged).
Removed `rideUpdates` toggle + `StorageKeys.rideUpdates`. Fixed `enterOtpToStart`.

## 4. SQL SECURITY DEFINER — ✅
- `060`: delivery RPCs `search_path` + anon EXECUTE revoke.
- `061`: `set_updated_at`/`deactivate_stale_tokens`/`get_unread_notification_count`
  `search_path`; **32 privileged helpers locked** (`_admin_exec_*`, `_member_exec_*`,
  `_approval_apply`, `_is_owner_uid`, `_reward_*`, etc.) `REVOKE EXECUTE FROM PUBLIC,anon`
  + `GRANT service_role`.
- `052`/`053`/`057`/`063`: additional DEFINER hardening.

## 5. RLS Audit — ✅ Hardened
- `platform_commissions`/`commission_rules` locked (platform_admin only).
- `062`: dropped over-permissive `authenticated read from buckets`; added owner-scoped
  SELECT/INSERT for `complaints` & `chat_attachments` (`split_part(name,'/',1)::uuid`).
- `064-A`: **driver-documents** bucket + owner/admin policies (was MISSING entirely).
- `064-B`: **profiles** upload tightened to owner path (was ANY authenticated →
  avatar-overwrite risk). Public read unchanged.
- History: `ride_ratings`/`ride_pricing` carry `USING(true)` public read — **DORMANT,
  low sensitivity**, retained per deletion policy.

## 6. Concurrency (Acceptance Race) — ✅ PROVEN SAFE
`accept_ride_request` (008:197) locks `rides FOR UPDATE` (229) → second caller blocked
then rejected on `status!='searching'`. `dispatch_delivery` (011) dedupes via UNIQUE +
`unique_violation`; `complete_delivery` guards `status='inTrip'`.

## 7. Financial Contract — ✅ CORRECT
- `070`: commission `*100` bug fixed (700% → 7%). Re-verified: `apply_commission` stores
  `amount * rate / 100`; ledger uses `amount` (NO double scaling). 🟢
- `063`: precedence = account override > service_category > account_type > default.
  Defaults driver 7% / provider 7% / merchant 3%. `get_commission_rate(p_user_id)` +
  `set_commission_rate('account')` added. `platform_commission_for_reference` wired.
- `064-C`: per-account override region-scoped via `user_region_preferences` +
  `_region_in_scope`. Global rules gated by `PLATFORM_REVENUE`.

## 8. Notification Contract — ✅ CLEAN
`notification_route_resolver` routes only to order/merchant/service/delivery screens.
No passenger/trip route. Flutter enum↔RPC-category verified aligned.

## 9. Secret Hygiene — ✅
No hardcoded `service_role`/JWT/API key in `lib`. `_send_fcm_to_user` keyless (DB FCM
tokens). `supabase_flutter` initializes from env.

## 10. Static Sweeps — ✅ (partial exhaustive)
- No dead passenger ROUTES (`'/ride'` etc.) remain — only shared-entity imports. 🟢
- Driver docs upload path `driver_licenses/$userId/...` matches `064-A` policy. 🟢
- Profiles avatar path `avatars/$userId/...` matches `064-B` owner check. 🟢
- Nullability/exhaustive DB-contract: **🟡 partially re-verified** (critical surface
  covered this + prior passes); full column-by-column re-diff deferred.

## 11. Commits This Sprint
`28f5316` (l10n), `d6304fe` (061), `87c0655` (062+063), `00e861b` (064). All pushed.

## 12. Remaining (Environment-Blocked) — MUST CLEAR AT DEPLOY
- 🔴 **Live DB**: apply `060`–`064` to staging; verify 061/062/063 take effect
  (acceptance race, storage ownership, commission rates). No live DB available.
- 🔴 **`flutter analyze` / `flutter test`**: disabled (Windows Dev Mode off).
  Build APKs green (admin+customer) but static analysis + unit suite unrun.
- 🔴 **Device (Phase 22)**: no physical device; runtime UI/notification untested.
- 🟠 **Global commission rule scope**: `account_type`/`service_category` changes still
  allowed for any `PLATFORM_REVENUE` admin (regional vs global not distinguished).
  Product decision recommended; per-account region enforcement done.
- 🟠 **Full nullability + DB-contract exhaustive re-diff**: not fully redone.

## 13. Recommendation
Ship to internal/staging with `060`–`064` applied. Run `flutter analyze`+`flutter test`
on a Dev-Mode-enabled machine, deploy to staging, then to production. Code is
substantively production-ready; the 🔴 is operational gating, not defects.
