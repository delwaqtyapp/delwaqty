# Sprint 57 Report — Admin Push UX (Device Counters + Received Metric + Notification Deletion)

**Date:** 2026-08-01
**Sprint:** 57
**Status:** Complete ✅ (migration 019 applied live + verified on device)
**Flutter SDK:** 3.44.6 (Dart 3.12.2)

---

## Goal

User requests (in order):
1. Connected devices → a **number counter** only (no token list).
2. **Offline** → a counter too.
3. A **button showing how many devices received** the notification.
4. **Hide the Firebase/database card** below the send button.
5. Notification center: a **delete-all** button.
6. Per-notification **delete button**.

## Deliverables

| # | Area | Change |
|---|------|--------|
| 1 | Migration `019_push_broadcast_device_count.sql` | Replaces `admin_broadcast_notification` so it returns the **device count** (number of `notification_tokens` rows belonging to the matched recipients) instead of the recipient-user count. Delivery unchanged — still inserts one `notifications` row per matching user. |
| 2 | Admin page | Connected-devices card → compact stat tiles: **متصل (online)** / **غير متصل (offline)** counters (15-min window) + an **الأجهزة المستلمة (devices received)** button that updates with the last broadcast's device count. Token list removed. `computeDeviceStats(tokens, now)` extracted for tests. |
| 3 | Admin page | Firebase Console copy card + `_copyPayload`/`_openConsoleGuide`/`_buildPayload` dead code **removed** — the RPC send is the single path. |
| 4 | Notification center | **حذف الجميع** (delete-all) action with confirmation dialog (`clearAll()`); each card gains a **حذف الإشعار** per-item delete button (`deleteNotification(id)`). Both invalidate `notificationsProvider`/`unreadCountProvider`. |
| 5 | Push service | **Token heartbeat** — re-upserts the FCM token every 5 min while the app is alive so `updated_at` is a real liveness signal (a closed app drops to offline after 15 min). |
| 6 | l10n | Renamed `sentToRecipients` → `sentToDevices` ("جهاز"/"device"); new keys `devicesOnline`, `devicesOffline`, `devicesReceived`, `deleteAllNotifications`, `deleteAllNotificationsConfirm`, `deleteNotification`. |
| 7 | Tests | 4 new `computeDeviceStats` tests + 3 notification-center widget tests (per-item delete, delete-all cancel/confirm, empty state). Suite **535 → 542**. |

## Live Migration (019) — Applied + Verified

Applied via **Management API** to `bttnlkmwhorjamzemwda`. Verified `pg_proc` shows the new body (`matched_ids uuid[]`, `device_count INTEGER`, returns device count).

## Device Verification (DNP NX9, serial A3SQUT5A28003808)

| Check | Result |
|-------|--------|
| Stats card | Renders `1 متصل` / `0 غير متصل` / `الأجهزة المستلمة: 0` — the device's token refreshed on launch (heartbeat + initial save). |
| Received metric | A test broadcast returned **1 device** (RPC live) and the received button updated to `الأجهزة المستلمة: 1`; DB row created. |
| Firebase card | Gone — page content ends at the send button. |
| Notification center | Shows `حذف الجميع` + per-item `حذف الإشعار` buttons; per-item delete removed the old `تست/تست١` row (DB confirmed); delete-all (with confirmation) emptied the table (**0 rows**) and rendered the empty state `لا توجد إشعارات`. Test data cleaned up. |

## Quality Gates

| Check | Result |
|-------|--------|
| `flutter analyze` | 0 errors |
| `flutter test` | 542/542 passing |
| APK build | `app-debug.apk` rebuilt (debug, `.env.dev`) + installed |
| Migration | ✅ 019 applied + verified via Management API |
| Live E2E | ✅ Send → device count → received button; per-item + delete-all verified |

## Decisions & Follow-ups

- **Decision:** the "devices received" metric counts `notification_tokens` of the recipients — the closest honest number without per-device delivery receipts, and consistent with realtime delivery (each token receives the row). See `docs/DECISION_LOG.md` ADR-038.
- **Decision:** removed the Firebase copy card — it was a manual/dead path now that the RPC send works.
- `Follow-up (external):` background/terminated FCM push still requires a Firebase service account (project `delwaqty0`); in-app realtime broadcast + counters/deletion are fully working.
- `Follow-up (optional):` a per-device delivery receipt would make "received" exact; needs a `push_deliveries` log + client ack.

**Commit:** (this session's docs commit — see `git log`)
