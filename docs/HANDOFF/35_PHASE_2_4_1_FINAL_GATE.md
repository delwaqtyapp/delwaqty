# HANDOFF 35 — PHASE 2.4.1 FINAL PRE-COMMIT GATE (SP-2.4.4)

**Date:** 2026-08-16 Session 52
**Phase:** 2.4.1 — Notification delivery layer (server infra + Flutter wiring)
**Authority:** ADR-062 + `docs/HANDOFF/34_PHASE_2_4_IMPLEMENTATION_PLAN.md` (owner-approved)
**Gate result:** 🟢 **GREEN — implementation complete, full gates pass. STOPPED at PRE-COMMIT GATE.**
**Commit (locked, awaiting approval):** `sprint 78: implement notification delivery and deep links`

---

## 1. What shipped

### 1.1 Backend — `supabase/migrations/041_notification_delivery_layer.sql` (additive only; 030–040 untouched)

- **Tables/columns:** `notification_destinations` allowlist (12 seeds, 3 admin-only);
  `notification_push_config` (id=1, `is_enabled=false`); notifications gains `priority` (low/normal/high),
  `sender_id`, `send_push` (default true), `push_status` (pending/sent/failed/unconfigured),
  `push_sent_at`, `push_error`.
- **RPCs (13):** `register_device_token`, `refresh_token_heartbeat`, `deactivate_device_tokens`
  (device-scoped logout), `cleanup_invalid_token` (FCM 404/410 path), `deactivate_stale_tokens`,
  `validate_notification_deep_link`, `dispatch_push` (operator backstop, admin-gated),
  `get_unread_notification_count` (hardened: `search_path` + self/admin authz), `_enqueue_push`
  (internal), plus existing-writer validators. All SECURITY DEFINER with pinned `search_path` and
  the fixed authz pattern.
- **Triggers (5):** chat reply → notify (`chat-msg-<msgid>[-<uid>]` idempotency, first-of-turn +
  same-turn suppression), complaint new/status → admin/complainant, SOS → admin high-priority
  (`/admin/live-tracking`), `guard_notifications_user_update` (content edits blocked, read-state allowed).
- **RLS/policies:** `notification_tokens` own-ALL + admin SELECT + service_role ALL, TRUNCATE/TRIGGER/
  REFERENCES/MAINTAIN stripped from authenticated; revokes on `notification_push_config` (anon/authenticated
  stripped); `campaigns` public-published SELECT (only `published` + in-window).
- **Security remediations during this phase:**
  1. **SECURITY DEFINER flaw fixed:** inside SECURITY DEFINER `current_user` is always the owner, so the
     inherited `IF current_user NOT IN ('service_role','postgres')` checks silently bypassed authz.
     041 uses `auth.uid() IS NULL` = server bypass, else enforce `auth.uid()`/`is_admin()`.
  2. **pg_default_acl grants leak fixed:** Supabase auto-grants on new functions; 041 REVOKEs
     `_enqueue_push`, `cleanup_invalid_token`, `deactivate_stale_tokens` (postgres/service_role only).

### 1.2 Flutter wiring (minimal, additive)

- `push_notification_service.dart` — `register_device_token`/`refresh_token_heartbeat`/
  `deactivate_device_tokens` RPCs; single `delwaqty_notifications` realtime channel filtered by
  `user_id`; re-login `initialize()` on every `AuthEventType.signedIn` (fixes `_initialized` bug);
  device-scoped logout (deactivates ONLY the current device).
- `device_identity.dart` — persisted Random.secure UUIDv4 (`delwaqty_device_id`).
- `app_notification.dart` — `NotificationPriority` (low/normal/high), `NotificationPushStatus`
  (pending/sent/failed/unconfigured), `senderId`; `NotificationType` stays at 13 values (no enum churn).
- `notification_center_page.dart` — pagination (page size 20 + load more + RefreshIndicator), localized
  date grouping (`notificationToday/Yesterday/Older`), priority chip, resolver-based deep links, unread
  invalidation.
- Shared — `notification_channels.dart` (12-channel allowlist + admin-only flags + scheme/traversal
  rejection), `notification_route_resolver.dart` (resolve/safe → `/notifications` fallback).
- Campaigns feature — entity (13 types, 10 statuses), repository/DS/impl, providers, read-only
  `campaign_detail_page.dart`, `/campaign/:id` GoRoute registered in `lib/module_registry.dart`
  (after RewardsModule).
- Auth — `auth_provider.dart` re-initializes push service on re-login.
- l10n — 11 new keys appended AR/EN, regenerated.

## 2. Verification evidence

| Check | Result |
|-------|--------|
| 041 applied live | HTTP 201, re-runs idempotent (`[]`), 6× total |
| Backend probe matrix | anon denied all (`42501`); token lifecycle own-allow/cross-deny/rotation; deep-link matrix (wildcard ok; injection/traversal/unknown/empty → NULL); UPDATE guard; unread cross-user `P0001`; dispatch non-admin `P0001`; triggers (chat/complaint/SOS); campaign RLS chain — all green |
| Fixture residue | 0 (campaigns/approvals/reviews/targets/notifs/users) |
| `flutter analyze` | 0 errors; new code 0 issues (repo info/warnings pre-existing) |
| `flutter test` | **805/805** (+46 new cases in 10 new files) |
| Secret scan | clean — no PAT/keys; only prose mention of secret names |
| `git diff --check` | clean (CRLF-at-EOL on `.arb` = repo convention, HEAD also CRLF) |
| `supabase/.temp/` | gitignored (machine-local metadata) |
| Scope audit | no edge functions, no 2.5+ features, no enum churn, 030–040 untouched |

## 3. What did NOT ship (blocked / out of scope)

- **SP-2.4.2 `send-push` Edge Function + pg_net trigger wiring** — blocked on **FCM server credentials**
  (no service account / server key in env/repo/gcloud). 041 is credential-ready by design: without keys
  the path no-ops to `push_status='unconfigured'`; adding keys later requires **zero code change**.
- **Physical-device E2E** (DNP-NX9 disconnected).
- **Phase 2.5** (escalation engine) and everything later — untouched by design.

## 4. Preservation contract

- Migrations 030–040: **not modified** (verifiable in `git diff`).
- No parallel notification system: reuses `notifications` + `notification_tokens`.
- No FCM/PAT credentials stored in code or repo; PAT never printed/committed.
- `NotificationType` enum stable at 13 values.

## 5. Gate decision

**STOPPED at the PHASE 2.4.1 PRE-COMMIT GATE.** All gates green; the change set is complete and staged
for commit. Commit+push will occur ONLY on explicit owner approval:
`git add . && git commit -m "sprint 78: implement notification delivery and deep links" && git push origin master`

Next after approval: commit+push, then SP-2.4.2 (edge function, needs FCM credentials), physical E2E.
