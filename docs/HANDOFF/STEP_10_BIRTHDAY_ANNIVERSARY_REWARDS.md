# HANDOFF: Step 10 — Birthday + Account Anniversary Rewards (Production-Hardened)

**Commit:** (sprint 80: implement birthday and anniversary rewards)
**Date:** 2026-08-17
**Gate:** 862/862 tests, 0 analyzer errors, live engine probes green

---

## What was delivered

### 1. Migration 045 — `supabase/migrations/045_rewards_config_approvals_region.sql` (live, deployed, idempotent)

Extends migration 038 (`member_rewards` / `run_member_engines`) — **no duplicate reward system**. Additive + re-runnable (re-applied live to confirm).

| Gap found | Fix |
|---|---|
| `platform_settings.promotions` column referenced by `_reward_benefit_valid`/`campaign_validate_benefit` but **never created** — free-delivery gate silently returned false forever | `ADD COLUMN IF NOT EXISTS promotions jsonb` + seed `{free_delivery_enabled: false}` |
| `_reward_config(reward_type)` was singleton — no region-aware config | New overload `_reward_config(reward_type, region_id)` with regional override → global fallback → `{}` no-op. Old single-arg signature preserved for backward compat |
| Engine run-date used the session timezone, not Egypt | `run_member_engines(p_run_date date DEFAULT (now() AT TIME ZONE 'Africa/Cairo')::date)`; anniversary matching converts `created_at AT TIME ZONE 'Africa/Cairo'` |
| Reward `status` never transitioned `granted → expired` | Config-driven expiry pass: `valid_days` in reward config (global or regional) drives auto-expiry; audit row written |
| No way to change reward config through the existing approval pipeline | New approval type `reward_config_change` (in `_valid_approval_type`), apply handler `_reward_config_exec`, and admin RPC `request_reward_config_change` (owner = global, in-scope admin = regional); wired into `_approval_apply` |
| Regional overrides not reachable by the engine | Engine resolves each member's region (`_member_region_id`) and feeds region-aware config |

**Config shape** (`platform_settings.rewards`):
```jsonc
{
  "birthday": { "enabled": true, "title_en": "…{{name}}…", "title_ar": "…",
                "body_en": "…", "body_ar": "…", "deep_link": "/rewards",
                "benefit": { "kind": "none" }, "campaign_id": null, "valid_days": 30 },
  "anniversary": { /* same shape, {{years}} placeholder */ },
  "regions": { "<region_id>": { "birthday": {…}, "anniversary": {…} } }
}
```
Absent config / `enabled:false` / invalid benefit → engine no-op. **No hardcoded business rules.**

### 2. Flutter rewards surface (enhancement)

| Component | Change |
|---|---|
| `member_reward.dart` entity | New getters: `birthdayYear`, `anniversaryYears`, `benefitCode` |
| `rewards_page.dart` | Card now shows **period** ("Birthday gift for 2026" / "With us for 3 years"), **status chip** (granted/claimed/expired), **benefit label**, and **benefit code box** (copyable) when a `code_copy` benefit is present |
| `app_en.arb` / `app_ar.arb` | New keys: `rewardPeriodBirthday`, `rewardPeriodAnniversary` (+ placeholders) |
| `app_localizations*.dart` | Regenerated via `flutter gen-l10n` |

No new hardcoded reward content — the client renders what the server config defines.

---

## Live verification (all probes green)

| # | Probe | Result |
|---|---|---|
| 1 | `promotions` column exists + seeded `free_delivery_enabled:false` | ✅ |
| 2 | `_reward_benefit_valid({kind:free_delivery})` = **false** while disabled | ✅ |
| 3 | `_reward_benefit_valid({kind:free_delivery})` = **true** once enabled | ✅ |
| 4 | Birthday grant on run-date matching DOB | ✅ `birthday_granted: 1` |
| 5 | Missing DOB member skipped (never invented) | ✅ fixture with `date_of_birth: NULL` skipped |
| 6 | Re-run same date → **0 new grants** (idempotent ledger) | ✅ `birthday_granted: 0` |
| 7 | Anniversary grant (years = run-year − created-year, Cairo date) | ✅ `anniversary_granted: 2` |
| 8 | Anniversary idempotency (same run → 0) | ✅ |
| 9 | Notification created with localized title + member display name | ✅ `Happy Birthday Reward Alpha!` |
| 10 | `{{name}}` placeholder substituted; no DOB ever in text | ✅ |
| 11 | Region-aware `_reward_config` resolution (global vs Cairo override) | ✅ `Global BD` vs `Cairo BD` |
| 12 | Engine uses regional override for member's own region | ✅ notification title = Cairo override |
| 13 | Config-driven expiry (`valid_days:1`, 10-day-old grant) | ✅ `rewards_expired: 1` |
| 14 | `_valid_approval_type('reward_config_change')` | ✅ `true` |
| 15 | `_reward_config_exec` owner-global apply writes `rewards.birthday.title_en` | ✅ |
| 16 | `_reward_config_exec` non-owner global → rejected | ✅ `Only owner can change global reward config` |
| 17 | `request_reward_config_change` without auth → rejected | ✅ `Not authorized` |
| 18 | ACL: anon denied RPC, authenticated allowed RPC, anon/authn denied engine, service_role allowed engine | ✅ |
| 19 | Migration re-run → idempotent (no errors) | ✅ |
| 20 | Fixtures + audit rows cleaned after testing; live state reset to `rewards:{}` + `free_delivery_enabled:false` | ✅ |

---

## Test results

| Suite | Count | Status |
|---|---|---|
| Full suite (`flutter test`) | **862/862** | ✅ |
| Rewards feature (entity + repo + widget) | 14/14 | ✅ |
| New tests this step | +6 (5 entity period/benefit + 2 widget page = 7 new; net +6 vs 856 baseline) | ✅ |

**New files:** `test/features/rewards/rewards_page_test.dart` (widget: period/status/benefit-code rendering, empty state); extended `test/features/rewards/member_reward_entity_test.dart` (period-key parsing + benefitCode).

---

## Analyzer / gate

- `flutter analyze`: **0 errors** on all touched files (rewards feature + l10n now issue-free)
- `flutter pub run build_runner build`: succeeded (257 actions)
- `git diff --check`: clean
- Secret scan: clean
- One-time normalization: `app_ar.arb` CRLF → LF (matches `app_en.arb`; eliminates `git diff --check` trailing-whitespace failures on the added lines)

---

## Owner verification (unchanged, re-confirmed)

| Field | Value |
|---|---|
| Email | `said.3pkarino@gmail.com` |
| UID | `8a23b719-a923-4a18-bd6e-04972097fb4b` |
| Role | `owner` |
| Authorization path | `users.role` + admin hierarchy + `has_permission()` + RLS/RPC — no hardcoded auth bypass |

---

## Files touched

**Modified (Flutter/l10n):**
- `lib/features/rewards/domain/entities/member_reward.dart`
- `lib/features/rewards/presentation/pages/rewards_page.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (+ generated `app_localizations*.dart`)
- `test/features/rewards/member_reward_entity_test.dart`

**Created:**
- `supabase/migrations/045_rewards_config_approvals_region.sql`
- `test/features/rewards/rewards_page_test.dart`

---

## Next step

**Step 11 — Profile + Registration (customer/provider/driver):** profile page personal-data editing incl. date-of-birth privacy rules (never shown raw in rewards text), registration role flows, verification integration.
