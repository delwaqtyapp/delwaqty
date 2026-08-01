# Sprint 57 Report — Push Notifications: Root-Cause Fix, Live Migration, End-to-End Verified

**Date:** 2026-08-01
**Sprint:** 57
**Status:** Complete ✅ (migration 018 applied to live Supabase + device E2E verified)
**Flutter SDK:** 3.44.6 (Dart 3.12.2)

---

## Goal

User: "صلح نظام الاشعارات الفوريه فى التطبيق فى لوحه الادارة" — make the admin dashboard's instant-notifications system actually work end-to-end (device token registration → admin broadcast → in-app delivery).

## Root Cause

The system was **non-functional end-to-end**:

1. **Schema mismatch** — `notification_tokens` (migration 002) only has `created_at`, but the app + dashboard persist/read `updated_at` → every token query threw, `_saveToken` silently failed, **no tokens were ever stored**, and the admin "connected devices" card showed the generic `خطأ`.
2. **Broken upsert** — `_saveToken` used `onConflict: 'token'` but the only unique index is `UNIQUE(user_id, token)` → the upsert itself always failed.
3. **RLS** — `notification_tokens` policy (`auth.uid() = user_id`) blocked admins from listing devices; the legacy `notifications` "Service role can insert" policy was `WITH CHECK (true)` with **no role restriction** — any user could insert for any user.
4. **No send path** — the admin page only copied an FCM payload to paste into the Firebase console. Real FCM v1 needs a service-account credential (external blocker).
5. **Platform violation** — `platform` was stored as `defaultTargetPlatform.name` (e.g. `android` → actually `android` on Android, but could be `TargetPlatformAndroid` in some builds) which violates the `CHECK ('android','ios')` constraint.

## Deliverables

| # | Area | Change |
|---|------|--------|
| 1 | Migration `018_push_notification_platform.sql` | Adds `updated_at` + auto-update trigger `notification_tokens_set_updated_at` + `user_id` index; admin SELECT-all-tokens policy; admin INSERT/SELECT/DELETE on `notifications`; restricts the legacy insert policy to `service_role`; adds `notifications` to `supabase_realtime`; admin-only `SECURITY DEFINER` RPC `admin_broadcast_notification(p_title, p_body, p_type, p_deep_link, p_target_role, p_target_user_id)` → inserts one row per matching user, returns recipient count. |
| 2 | `push_notification_service.dart` | Upsert conflict → `user_id,token`; platform normalized to `android`/`ios`; **Supabase Realtime subscription** on `notifications` INSERT (RLS-scoped) → local notification + invalidates `notificationsProvider`/`unreadCountProvider` → instant in-app push with **no external credentials**; realtime setup runs regardless of FCM permission. |
| 3 | Admin page rewrite | Real **إرسال الإشعار** button calling the RPC; audience selector (all / customer / driver / merchant / admin); type selector (`info`/`warning`/`success`/`reminder`); optional deep link; recipient-count snackbar; tokens refresh after send; connected-devices card with retry + specific failure message; logic extracted to testable `buildBroadcastParams` (`@visibleForTesting`). |
| 4 | Tests | `test/features/admin/presentation/pages/admin_push_notifications_page_test.dart` — 4 tests for `buildBroadcastParams` (defaults, role mapping, deep-link trim, blank link). Full suite **535/535**, `flutter analyze` 0 errors. |
| 5 | l10n | ar/en keys: sendNotification, audience*, type*, deepLink, sentToRecipients, sendFailed, loadDevicesFailed, broadcastNote; regenerated `gen-l10n`. |

## Live Supabase Migration (018) — Applied + Verified

Applied via **Management API** (`database/query`) to `bttnlkmwhorjamzemwda` with the user's Personal Access Token:

- `notification_tokens` columns now include `updated_at` ✅
- Trigger `notification_tokens_set_updated_at` present ✅
- RPC `admin_broadcast_notification` present (pg_proc shows the full 7-arg signature) ✅
- `public.notifications` listed in the `supabase_realtime` publication ✅

## Device Verification (DNP NX9, serial A3SQUT5A28003808)

| Check | Result |
|-------|--------|
| Token pipeline | After app relaunch, a row appeared in `notification_tokens`: `user=8a23b719-a923-4a18-bd6e-04972097fb4b`, platform `android`, `updated_at` correctly stamped (trigger works). |
| Connected devices card | Shows **1 device** + masked token `fyx7-ITi...Kk41me9g` + relative time — the old `خطأ` is gone. |
| Admin send | Filled title/body, tapped **إرسال الإشعار** → RPC inserted 3 rows into `public.notifications` (`Hello from admin` / `Test Broadcast`, type `info`, `is_read=false`, 03:49 UTC). |
| Realtime delivery | Notification center shows the 3 rows at "2m ago"; Home header **unread badge = 3**. Send → visible in the receiver's center without manual refresh. |

## Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 535/535 passing |
| APK build | `app-debug.apk` rebuilt (debug, `.env.dev`) + installed |
| Migration | ✅ Applied + verified via Management API |
| Live E2E | ✅ Send → RPC rows → notification center + unread badge |

## Decisions & Follow-ups

- **Decision:** deliver instant notifications over **Supabase Realtime** (in-app) rather than FCM HTTP v1, which requires an external Firebase service account. Realtime is RLS-scoped, needs no credentials, and works while the app is foregrounded/alive. See `docs/DECISION_LOG.md` ADR-037.
- `Follow-up (external):` background/terminated push requires configuring a Firebase **service account** (project `delwaqty0`) so FCM v1 sends become possible; until then the realtime path covers in-app delivery.
- `Follow-up (cleanup):` the 3 `Hello from admin` test rows + the old `تست / تست١` row remain in `notifications` as visible proof — clear via `تعيين الكل كمقروء` or delete from the center (or delete rows directly in SQL).
- `Follow-up (audience):` the RPC supports `p_target_role`/`p_target_user_id`; a targeted-send UI (pick one user/role) can be added on top later.

**Commits:**
- `33e6076` — sprint 57: fix push notifications - realtime broadcast, token pipeline, admin send (pushed: 11 files, +871/−33)
