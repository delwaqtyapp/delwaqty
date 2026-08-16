# Phase 2.3 Pre-Commit Gate Report — Member Management, Support, Rewards & Retention

**Session 52 (2026-08-16) · HEAD before commit:** `991819e` (`sprint 76: add promotion targeting and approval`)
**Scope:** migrations 033/034/035/038 + Flutter rewards layer + docs
**Authorization:** owner's Session-52 7-phase implementation permit (AGENTS.md §10 autonomous run)

---

## 1. Backend deliverables (applied live to `bttnlkmwhorjamzemwda`)

| Migration | Purpose | Apply | Idempotent | Verification |
|-----------|---------|-------|-----------|--------------|
| `033_support_chat_priority_region_assignment.sql` | chat priority (incl. emergency) + deterministic region→parent→global→owner routing + escalation + guard triggers + activity_logs/sos_alerts/driver_locations RLS fixes | HTTP 201 | re-run OK | **22/22** probes (T1 8/8, T4 5/5, T4b 5/5, T5, N-probes DENIED-OK), zero residue |
| `034_admin_management_permissions_approvals.sql` | supervision tree `admin_management` + `has_permission()` engine + M1 invariants + Approval Center (`submit_approval_request` + extended `decide_approval_request`) | HTTP 201 | re-run OK | **74 assertions + 2 denial probes**, zero residue; 3VL decider-guard bypass found + fixed live |
| `035_member_management_moderation_deletion.sql` | `users.date_of_birth/account_status/anonymized_at` + `users_guard_account_fields` (replaces 031 role-only guard), `member_events` timeline, sanctions additive, moderation/deletion RPCs, `get_member_profile` | HTTP 201 | re-run OK | **73 assertions + 4 denial probes**, zero residue |
| `038_member_rewards_engines_retention.sql` | `member_rewards` ledger + `run_member_engines(date)` + `retention_policies`/`apply_retention_policies()` + `write_audit` service-context hardening | HTTP 201 | re-run OK | **36 assertions + 4 denial probes + 11 residue checks zero** |

### Security fixes found by live probes (all re-applied + re-verified)
1. **034 decider 3VL bypass** — `required_approver IS NULL` made the guard predicate NULL → `IF` skipped → unrelated authorized admin could decide an owner-addressed request. Fixed with explicit `IS NULL` branches + self-decision check reordered first.
2. **038 `write_audit` service-context crash** — `auth.uid()::text` (NULL in service context) violated `activity_logs.user_id` NOT NULL, crashing the retention audit. Hardened with `COALESCE(auth.uid()::text, 'system')`; signature + service_role-only ACL unchanged.

---

## 2. Probe suite results — `probe_038` (migration 038)

| Probe | Coverage | Result |
|-------|----------|--------|
| T1_BIRTHDAY | 9 asserts — grants exactly 2 birthdays when enabled; suspended + admin excluded; double-run no-op; 2027 re-grant under new period_key; benefit `{"kind":"none"}`; `notified_at` set; notification idempotency key; `member_events` row | ✅ |
| T2_ANNIVERSARY | 7 asserts — 2-year member granted on 2026-07-19 (`anniversary:2`); double-run no-op; next-year `anniversary:3`; `free_delivery` DENIED until `platform_settings.promotions.free_delivery_enabled` | ✅ |
| T3_RETENTION | notifications kept/purged by policy toggle; 200-day-old `location_updates` purged / 1-day-old kept; `activity_logs` archived-then-purged; `member_events`/chat old-purged-new-kept; active sanctions never purged, closed/revoked old purged; only `archived_at`-expired campaigns purged; absent tables skipped; RETURNED jsonb; every purge audited `RETENTION_PURGED`; re-run OK | ✅ |
| T4_CAMPAIGN_EXPIRY | full lifecycle `campaign_submit` → `decide_approval_request('approve')` → `campaign_publish` → backdated `ends_at` → engine flips `published→expired`; future campaign stays published; draft untouched; idempotent | ✅ |
| T5_RLS_ACL | 9 ACL asserts + authenticated-role RLS block — own-read only; other member 0 rows; Maadi admin (4095 `MEMBER_VIEW`) sees Maadi reward, 0 rows for Cairo; `retention_policies` admin 9 / non-admin 0; member + retention INSERTs 42501; anon/authenticated lack EXECUTE on engines; `member_events` CHECK | ✅ |
| N1–N4 | anon/authenticated engine + retention calls → HTTP 400 DENIED-OK | ✅ |
| Z_RESIDUE | 11/11 zero (probe_rewards/users/campaigns/notifications/events/audit/locations/sanctions/chat 0, archive exists 1, invariant violations 0) | ✅ |

**RESULT ALL GREEN — 36 assertions + 4 denial probes + 11 residue checks.**

---

## 3. Flutter layer

- New `lib/features/rewards/` module registered in `lib/module_registry.dart` (`/rewards`, profile tile, `navPriority 84`, non-nav module).
- Freezed `MemberReward` entity (`RewardType`/`RewardStatus` enums with `@JsonValue`, `benefitKind` getter via `const MemberReward._()`).
- Own-read data source with repo-convention `_fromRow` snake_case→camelCase mapping (no `@JsonKey` on factory params); repository impl wraps `ServerException`.
- `rewardsRepositoryProvider` + `myRewardsProvider` (autoDispose, gated on `AuthAuthenticated.user.id`, empty list for guest).
- `RewardsPage` — loading/error/empty/data states, reward cards (status chip + benefit label), fully l10n-driven.
- `NotificationType.reward` added (enum + icon/color mapping, incl. admin push-notifications exhaustive switch).
- L10n: +16 keys EN/AR regenerated.
- Tests: 8 new (entity 5 + repository mocktail 3); NotificationType enum tests 12→13.

---

## 4. Full gate

| Check | Result |
|-------|--------|
| `flutter pub get` | ✅ |
| `flutter gen-l10n` | ✅ |
| `build_runner` (freezed/json) | ✅ 3 outputs |
| `flutter analyze` | ✅ **0 errors, 0 new warnings** (remaining warnings/infos = pre-existing baseline) |
| `flutter test` | ✅ **759/759** |
| Live apply + idempotency (033/034/035/038) | ✅ all HTTP 201, idempotent re-runs OK |
| Probe suites (033/034/035/038) | ✅ all green, zero residue |
| Secret scan | ✅ no secrets/PAT in diff |

---

## 5. Docs updated

- `SESSION_STATUS.md` — Phase 2.3 complete.
- `docs/DECISION_LOG.md` — **ADR-061** (038 + write_audit hardening + Flutter rewards layer).
- `ROADMAP.md` — 2.3 ✅ IMPLEMENTED + GATE 🟢.
- Untracked Phase 2.3 docs ship with the commit: `32_PHASE_2_3_SUPPORT_CHAT_PRIORITY_ASSIGNMENT_AUDIT.md`,
  `PHASE_2_3_MEMBER_MANAGEMENT_SUPPORT_ARCHITECTURE_AUDIT.md`, `PHASE_2_3_DECISION_LOCK_REPORT.md`.

**Commit:** `sprint 77: complete Phase 2.3 member management support and rewards`
