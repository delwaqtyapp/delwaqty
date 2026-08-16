# HANDOFF 34 — PHASE 2.4 IMPLEMENTATION PLAN: NOTIFICATION DELIVERY LAYER (FCM + REALTIME + DEEP-LINKS + TOKEN LIFECYCLE + NOTIFICATION CENTER)

> **Date:** 2026-08-16 (Session 52)
> **Author:** Lead Software Architect (autonomous run, owner-authorized Phases 2.3–2.9)
> **Status:** PROPOSED — awaiting owner approval. No code, schema, migration, commit, or push until approval.
> **Phase 2.4 directive:** deliver the production-grade notification delivery layer on top of the **existing** notification infrastructure (inspection-first, reuse-over-rebuild, additive-only migrations).
> **Stop conditions:** do NOT start Phase 2.5 (Emergency Command Center) or Phases 2.6–2.8. Do NOT modify migrations 030–040. Do NOT create a parallel notification system.

---

## 0. Executive Summary

Phase 2.4 upgrades Delwaqty's **existing** notification stack (`notifications` + `notification_tokens` + `supabase_realtime` publication + admin broadcast RPC) into a complete delivery layer:

- **Backend (additive migration 041):** notifications enrichment columns (priority/sender/push-state), a `notification_destinations` deep-link allowlist, device-scoped FCM token lifecycle RPCs, a `dispatch_push` RPC + `AFTER INSERT` trigger that pushes notifications **server-side to FCM** via a new `send-push` Edge Function through `pg_net` (graceful no-op until FCM credentials exist), realtime delivery reuse, security hardening (read-state-only UPDATE, authz-hardened unread counter, `search_path`-pinned redefinitions), and automatic notifications for **support chat, complaints, emergency (SOS), campaigns (039/040), rewards (038)**.
- **Flutter:** device-scoped token registration/rotation/logout, realtime-first unread badge (replacing 1-min polling), Notification Center pagination + localized grouping + priority visuals, **controlled deep-link resolution** (allowlist, no arbitrary routes), cold-start/background/foreground/logged-out tap handling, and route landing pages for campaign notifications.
- **Tests:** 24 backend probes + 10 Flutter tests. **Live verification** against the linked project. **Physical-device verification marked PENDING** (DNP-NX9 not connected).
- **Commit:** `sprint 78: implement notification delivery and deep links`.

Every claim below was verified against the **live** Supabase project (`bttnlkmwhorjamzemwda`) and the repository during the Phase 2.4 inspection. Nothing is assumed.

---

## 1. Current State — `notifications` Table (Verified Live)

Verified via `information_schema.columns` and `pg_policies` on the live project:

**Columns (12):** `id uuid PK`, `user_id uuid NULL`, `title text NOT NULL`, `body text NOT NULL`, `type text NULL`, `data jsonb NULL`, `is_read bool NULL DEFAULT false`, `created_at timestamptz NULL DEFAULT now()`, `idempotency_key text NULL`, `read_at timestamptz NULL`, `deep_link text NULL`, `image_url text NULL`.

**Indexes:** `pkey`, `idx_notifications_user_id`, `idx_notifications_is_read`, `idx_notifications_created_at (DESC)`, `idx_notifications_idempotency_key (UNIQUE, partial WHERE idempotency_key IS NOT NULL)`, `idx_notifications_user_read (user_id, is_read, created_at DESC)`.

**RLS policies (live):**
| Policy | Cmd | Qual / WithCheck | Notes |
|---|---|---|---|
| Users can view own notifications | SELECT | `auth.uid() = user_id` | |
| Users update own notifications | UPDATE | qual+check `auth.uid() = user_id` | **Any column** can be changed by the owner — not just read state. **Security gap to close.** |
| Users delete own notifications | DELETE | `auth.uid() = user_id` | |
| Admins can select notifications | SELECT | `is_admin()` | |
| Admins can insert notifications | INSERT | WITH CHECK `is_admin()` | |
| Admins can delete notifications | DELETE | `is_admin()` | |
| Service role can insert notifications | INSERT TO service_role | `true` | |

**Row count: 0.** `data` historically carries `{'deep_link': '...'}` (018/019 pattern) and/or entity ids; `deep_link` column also set directly by 033/038/040.

**Realtime:** `notifications` is already in the `supabase_realtime` publication (verified via `pg_publication_tables`) — **reuse, no change needed**.

**Insert pattern in use (033/038/040):** `INSERT INTO notifications (user_id,title,body,type,data,deep_link,idempotency_key) ... ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING`. This is the **existing dedup mechanism** — 2.4 extends it, does not replace it.

**Conclusion:** the `notifications` table is **fully reusable** as the core. 2.4 only ADDs columns/constraints for priority/push-tracking and closes the read-state UPDATE gap. No parallel system is created.

---

## 2. Current State — `notification_tokens` + FCM (Verified Live)

**Columns (10):** `id uuid PK DEFAULT gen_random_uuid()`, `user_id uuid NULL`, `token text NOT NULL`, `platform text NOT NULL`, `created_at timestamptz DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()` (auto-updated by trigger from 018), `device_id text NULL`, `app_version text NULL`, `is_active bool DEFAULT true`, `last_seen_at timestamptz DEFAULT now()`.

**Constraints/indexes:** `UNIQUE (user_id, token)` (conflict target for client upsert), `notification_tokens_user_id_idx`, `idx_notification_tokens_active (user_id, is_active) WHERE is_active`, `idx_notification_tokens_last_seen`.

**RLS policies (live):** "Users can manage own tokens" (FOR ALL `auth.uid() = user_id`), "Admins can select all tokens" (SELECT `is_admin()`), "Service role manage tokens" (FOR ALL `true`).

**Row count: 13. Users: 5 (roles present: customer, provider, owner; admin/owner distinguished via `is_admin()`).**

**FCM server-side status (verified):**
- `supabase/functions/` is **EMPTY** — no Edge Functions exist.
- **No** Firebase service-account JSON, no gcloud auth, no FCM server key, no Supabase FCM secrets anywhere in the environment/repo. Only live secret: `SUPABASE_DB_URL`.
- `android/app/google-services.json` exists with `project_id: delwaqty0`. Flutter reads Firebase config via `FirebaseConfig`/`.env.dev` (`FIREBASE_PROJECT_ID/API_KEY/APP_ID/MESSAGING_SENDER_ID/STORAGE_BUCKET`).
- `pg_net` **IS installed and verified live**: `net.http_post(url jsonb body, jsonb headers, int timeout_milliseconds)` + `http_get/http_delete/http_collect_response` present (one-shot `[]` rollback-style API; single-statement via `oneq.py`).

**Client token lifecycle today (`push_notification_service.dart`):** direct `notification_tokens.upsert({user_id, token, platform, is_active, last_seen_at, updated_at}, onConflict: 'user_id,token')` — **no `device_id`, no RPC**, 5-min heartbeat re-upserts, `onTokenRefresh` re-upserts, `deactivateTokensOnLogout()` deactivates **ALL** of the user's tokens (not device-scoped), `_initialized` guard prevents re-init after re-login.

**Gaps to close in 2.4:** no device-scoped lifecycle RPCs; logout kills every device; no server-side FCM send path; token upsert doesn't record `device_id`/`app_version` consistently; no invalid-token cleanup from FCM responses.

---

## 3. Realtime — Current + Reuse Plan (Verified Live)

**Publication `supabase_realtime` currently includes:** wallets, rides, notifications, driver_documents, ride_requests, driver_earnings, driver_locations, delivery_pricing, complaints, sanctions, location_updates, chat_rooms, chat_messages, sos_alerts, live_share_sessions. **`notification_tokens` is NOT published** (correct — tokens must never stream).

**Client today (`push_notification_service.dart:184-215`):** single unscoped channel `'in-app-notifications'` with `onPostgresChanges(insert, notifications)` + client-side `recordUserId == userId` filter, then `_showLocalNotification` + `onRealtimeNotification` (invalidates `notificationsProvider` + `unreadCountProvider`). No reconnect handling, no duplicate guard, one shared channel name.

**Reuse plan (no new infra):**
- Keep `notifications` in the publication (already there).
- Replace the ad-hoc channel with a **centralized channel-name registry** (`NotificationChannels.inApp`) shared by the service and the module; keep RLS to filter server-side (policy already scopes to `auth.uid() = user_id`; the client-side filter becomes a belt-and-suspenders duplicate guard keyed by `notification_id`).
- Add **reconnect/resubscribe** handling (`.onStatusChanged` → resubscribe, and on auth change subscribe/unsubscribe).
- Feed the **unread badge and list from realtime events** (insert/update of `is_read`) + a periodic reconcile (30–60s) as fallback — replacing the current 1-min pure polling `unreadCountStreamProvider`.
- `notification_tokens` stays unpublished.

---

## 4. Notification Types Required in Phase 2.4

The `type` column is free text; the Flutter `NotificationType` enum has **13 values** (`system, order, payment, promotion, service, account, security, message, info, warning, success, reminder, reward`). Server writers currently emit: `info` (018/019), `chat_assigned`, `chat_escalated` (033 — **not in the enum → parsed as `system`**), `promotion` (040), `reward` (038).

Phase 2.4 standardizes and documents the canonical vocabulary. **Additive only** — existing writers keep their type strings (033's `chat_assigned`/`chat_escalated` are retained and mapped on the client; no 033 file changes):

| Type | Producer | Recipient | Payload / deep-link | Priority |
|---|---|---|---|---|
| `system` / `info` | 018/019 broadcast | users | `data.deep_link` | normal |
| `promotion` | 040 campaign approve/reject (+ publish) | requester/owner | `/campaign/:id` (new landing, §19) | normal |
| `reward` | 038 engine | member | `/rewards` (client remaps 038's `/profile`) | normal |
| `chat_assigned` / `chat_escalated` | 033 routing | admin | `/admin/support-chat/room/:roomId` | high (escalation) / normal |
| `message` | **NEW** chat-message trigger (§16) | counterpart user | `/support/room/:roomId` | normal |
| `complaint` | **NEW** complaint-status trigger (§17) | complainant/respondent/reporter/admin | `/my-complaints` or `/admin/complaints` | normal |
| `emergency` | **NEW** SOS notification (§18) | assigned admin + trusted contacts | `/safety` (user) / admin SOS landing (2.5 placeholder) | **high** |
| `account` / `security` / `order` / `payment` / `service` | future/existing callers | user | allowlisted route | normal |
| `admin` | **NEW** admin→user notices | user | allowlisted route | normal |

Client mapping additions in the data source `_fromRow`: `chat_assigned → message`, `chat_escalated → message` (kept for compatibility; DB type string unchanged). New enum additions if we want distinct colors/icons: `NotificationType.chatAssigned`? **Decision: NO new enum values.** `chat_assigned/chat_escalated` map to existing `message`; `emergency` maps to existing `security`; `complaint` maps to existing `system`; `admin` maps to existing `account`. This keeps the enum stable (tests asserting `values.length == 13` unchanged) and the DB free-text vocabulary canonical. Only the **data source mapping** and **type→icon/color** are extended via a map rather than an exhaustive switch — actually the page uses an exhaustive `switch` on the enum; since we add NO enum values, **no exhaustive switch changes and no test-count changes**. This is the lowest-risk path and honors "no code churn for reuse".

Wait — canonical-vocabulary documentation lives in the migration header comment + this plan; enforcement is NOT a CHECK constraint (would break existing writers). Enforcement point = the `dispatch`/allowlist + client mapping.

---

## 5. Notification Payload Design

**Database row (after migration 041):** `id, user_id, title, body, type, data jsonb, is_read, read_at, deep_link, image_url, priority, sender_id, send_push, push_status, push_sent_at, push_error, idempotency_key, created_at`.

**`data` jsonb shape (new canonical, writers MAY keep existing keys):**
```jsonc
{
  "entity_type": "campaign|room|complaint|sos|reward|order|ride|delivery|service|none",
  "entity_id": "uuid",
  "action": "open|approve|reject|publish|assigned|escalated|resolved|reply|new",
  "deep_link": "/campaign/<id>",          // legacy writers (018/019) already do this
  "priority": "normal|high"                // optional; column is authoritative
}
```

**FCM data payload (sent by `send-push` Edge Function per token):**
```jsonc
{
  "notification_id": "<uuid>",
  "type": "<canonical type>",
  "deep_link": "<allowlisted route or empty>",
  "entity_id": "<uuid or empty>",
  "entity_type": "<... or empty>",
  "action": "<... or empty>",
  "priority": "normal|high"
}
```
This matches the existing `NotificationPayload` (notification_id/type/deep_link/entity_id/entity_type/action) — **client `NotificationPayload.fromMap` stays compatible**.

**AppNotification entity additions (Flutter):** `priority` (`NotificationPriority { low, normal, high }` parsed from column; default `normal`), `senderId` (`String?`), `pushStatus` (String?, informational). New values are additive to the freezed model; `fromJson` tolerant (`?? default`). No enum-count tests affected (priority is a NEW enum with its own length test = 3).

---

## 6. FCM Token Lifecycle (Device-Scoped)

**Server RPCs (new, in migration 041, all `SECURITY DEFINER SET search_path = public, pg_temp`):**

| RPC | Signature | Caller | Behavior |
|---|---|---|---|
| `register_device_token(p_token text, p_platform text, p_device_id text, p_app_version text DEFAULT null)` | returns void | authenticated (client on init + refresh + heartbeat) | Upsert `(user_id, token)` with `device_id`, `app_version`, `is_active=true`, `last_seen_at=now()`; then deactivate any OTHER active token with the same `device_id` (device re-install/token-rotation cleanup). Uses `auth.uid()`. |
| `deactivate_device_tokens(p_device_id text)` | returns int | authenticated (client logout) | Sets `is_active=false` for `auth.uid()` tokens matching `device_id` (falls back to ALL user tokens when `device_id` is null/empty for backwards compatibility). |
| `refresh_token_heartbeat(p_token text, p_device_id text)` | returns void | authenticated (5-min heartbeat) | `UPDATE ... SET last_seen_at = now() WHERE user_id = auth.uid() AND token = p_token` (and refresh device_id if provided). Cheaper than full upsert. |
| `cleanup_invalid_token(p_token text)` | returns void | service_role (edge function on FCM 404/410) | `UPDATE notification_tokens SET is_active=false, last_seen_at=now() WHERE token = p_token`. |
| `deactivate_stale_tokens(...)` | existing (026) | service_role | **Kept as-is** (re-`CREATE OR REPLACE` only to pin `search_path`). 30-day window. |

**Client flow (`push_notification_service.dart`):**
1. On init (post-login): generate/persist a stable **`device_id`** (UUID, stored via a new tiny `deviceIdProvider` backed by `shared_preferences`) → `register_device_token(token, platform, deviceId, appVersion)`.
2. `onTokenRefresh` → `register_device_token` (rotation).
3. Heartbeat (5 min) → `refresh_token_heartbeat`.
4. **Logout:** `deactivate_device_tokens(deviceId)` — only THIS device, not all. `auth_provider.signOut()` already calls `pushNotificationService.deactivateTokensOnLogout()` (verified line 197); the implementation switches from table-update to the RPC.
5. **Re-login:** the `_initialized` guard is replaced by an **auth-state listener** (`ref.listen(authStateProvider)` or subscription in `_setupRealtimeNotifications`): on authenticated → (re)init token+realtime; on signed-out → cancel heartbeat, unsubscribe channel. No stale "initialized" flag after logout.
6. Guest: no token registration; badge hidden (verified `primary_header_actions.dart:28-30`).

---

## 7. Secure Backend→FCM Send Mechanism (Verified Feasible)

**Verified facts:** `pg_net` installed live; `net.http_post(url jsonb body, jsonb headers, timeout)` available; FCM project id `delwaqty0`; no FCM credentials yet.

**Architecture (Flutter → RPC → server sender → FCM):**

```
Client App
  │  (in-app display via Realtime, §8 — always works, no FCM)
  ▼
notifications INSERT (any existing writer: 033/038/040/019/trigger)
  │
  ▼
AFTER INSERT trigger `notify_notification_push` (SECURITY DEFINER, service context)
  │  only when NEW.send_push IS TRUE AND NEW.user_id IS NOT NULL AND NEW.push_status='pending'
  │  → calls net.http_post(
  │        url = '<SUPABASE_URL>/functions/v1/send-push',
  │        body = jsonb_build_object('notification_id', NEW.id),
  │        headers = {'Authorization': 'Bearer <SEND_PUSH_TOKEN>', 'Content-Type':'application/json'},
  │        timeout_milliseconds = 5000)
  │  (fire-and-forget; pg_net records the http job; trigger never blocks/throws)
  ▼
Edge Function `send-push` (NEW, supabase/functions/send-push/index.ts)
  │  - rejects if Authorization != env SEND_PUSH_TOKEN
  │  - loads notification row + recipient's ACTIVE tokens
  │  - if NO FCM credentials configured (FIREBASE_SERVICE_ACCOUNT / FCM_SERVER_KEY / GOOGLE_APPLICATION_CREDENTIALS all absent)
  │      → UPDATE push_status='unconfigured' → return {status:'unconfigured'}   // graceful no-op, realtime still delivers
  │  - idempotency: if push_status IN ('sent') OR push_sent_at IS NOT NULL → return {status:'already_sent'}
  │  - builds FCM v1 message per token: {notification:{title,body}, data:{...§5}, android:{priority:'high', channelId}, apns:{}}
  │    POST https://fcm.googleapis.com/v1/projects/delwaqty0/messages:send
  │  - success → UPDATE push_status='sent', push_sent_at=now()
  │  - 404/410 Unregistered → cleanup_invalid_token(token)
  │  - other error → UPDATE push_status='failed', push_error=<safe msg>
  ▼
FCM → Android/iOS device
```

**Credential-ready + graceful:** the function is deployed now (no secrets needed for the `unconfigured` no-op). When the owner supplies FCM credentials (manual step, §28/§30), only Supabase function secrets are added — **no code change**.

**Why pg_net trigger (not a service-worker/poll loop):** existing writers (033/038/040/019) insert notifications directly and must NOT be edited (rule: no modifications to applied migrations). A trigger is the only non-invasive integration point that captures 100% of inserts with zero writer changes. The trigger is `AFTER INSERT`, SECURITY DEFINER, wrapped so any pg_net failure is swallowed (audit via `net._http_response`), keeping notification inserts non-fatal.

**Backstop:** a manual `dispatch_push(p_notification_id uuid)` service_role RPC + an admin "resend failed" path is included for operators; it re-enqueues any `push_status='failed'|'unconfigured'` notification. (No scheduled cron required in this phase.)

---

## 8. Realtime Inside the App

- Reuse `notifications` publication (verified present).
- **Central registry:** `lib/core/notifications/notification_channels.dart` exposing `NotificationChannels.inApp` (const `'in-app-notifications'`). Both `push_notification_service.dart` and any future consumers reference it (no string drift).
- `_setupRealtimeNotifications()` hardened: subscribe only when authenticated (gate on `authStateProvider`, re-subscribe on login, `channel.unsubscribe()` on logout); `onStatusChanged` → `rejoin()` on `reconnected`/`subscribed`; duplicate event guard (last-seen `notification_id` per channel); keep RLS as the primary filter.
- Realtime events drive: new list item (prepend + invalidate `notificationsProvider`), unread count increment (invalidate `unreadCountProvider`), read-state changes (UPDATE event when `is_read` flips → decrement badge + refresh row).
- Realtime remains the **primary** in-app delivery; FCM is the **offline/background** channel. Foreground messages are NOT re-shown by FCM if the realtime event already displayed them (dedup by `notification_id` in `_handleForegroundMessage`).

---

## 9. Unread / Read Architecture

- **Source of truth:** `notifications.is_read` + `read_at`. No separate read-tracking table needed.
- **Read semantics:** opening a notification (tap in center, tap on push) → `markAsRead(id)` → updates `is_read=true, read_at=now()`. "Mark all read" updates the whole page-set (or all own rows) via existing `markAllAsRead`.
- **`get_unread_notification_count(p_user_id)`:** **hardened in 041** (CREATE OR REPLACE): add `SET search_path = public, pg_temp`, and enforce `p_user_id = auth.uid() OR is_admin()` (today it counts ANY user id — info-leak gap). Signature unchanged → no client change.
- **Badge:** `unreadCountProvider` (FutureProvider) + `unreadCountStreamProvider` reworked to emit from realtime events (insert of own row / update of own row to read) with periodic 30–60s reconcile fallback. `primary_header_actions.dart` already watches `unreadCountProvider` — becomes live. Drawer badge reuses the same provider (removes the duplicated polling stream in `notifications_module.dart`).
- **Pagination:** `getNotifications(unreadOnly, limit=20, offset)` already exists in repo+DS. Notification Center gets load-more (page size 20–50 → **chosen: 25**).

---

## 10. Deduplication & Idempotency

- **DB layer (existing, extended):** partial UNIQUE index `idx_notifications_idempotency_key` + `ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING` in 033/038/040 writers — **kept**. 041 keeps the convention for NEW writers:
  - chat reply: `chat-msg-<message_id>`
  - complaint status: `complaint-<id>-<status>-<to_uid>`
  - SOS notify: `sos-notify-<sos_id>-<to_uid>`
  - campaign (040 existing): `campaign-approve/-reject-<request_id>` (unchanged)
- **Push send idempotency:** `push_status` state machine `pending → sent | failed | unconfigured` + `push_sent_at` guard in the edge function (never double-sends a given notification; re-dispatch of `failed` is explicit via `dispatch_push`).
- **Realtime duplicate guard:** client-side last-seen `notification_id` per channel.
- **FCM duplicate display:** foreground handler checks `notification_id` against the realtime-displayed set before `_showLocalNotification`.
- **Read idempotency:** `markAsRead` sets read state unconditionally (no-op on second call).

---

## 11. Notification Center

Current (`notification_center_page.dart`): loads `notificationsProvider` (first 20, no pagination), groups by **hardcoded Arabic** labels (`اليوم/أمس/أقدم`), renders icon/color per type, mark-all-read / delete-all / per-item delete, tap → `context.push(notification.deepLink!)` — **raw deep-link, no validation** (gap).

**2.4 upgrades:**
- **Pagination:** infinite-scroll / "load more" (25/page) via `notificationsProvider` → family on `offset`, or a local stateful list with `getNotifications(limit, offset)`. (Repository/DS already parameterized.)
- **Localized grouping:** l10n keys `notificationToday / notificationYesterday / notificationOlder` (AR/EN), replacing hardcoded strings.
- **Read/unread visuals:** existing unread background tint kept; add unread badge dot already present; tapping marks read first (existing).
- **Priority visuals:** new `priority` field → priority chip/border for `high` (e.g., `emergency`/escalation) in the card; `_getTypeColor`/`_getTypeIcon` extended only via the existing map for the mapped types (no enum change).
- **Actions:** keep mark-all-read, delete-all (with confirm), per-item delete. Tap handling uses the **controlled resolver** (§14) instead of raw `deepLink`.
- **Empty/loading/error:** existing `PremiumEmptyState` + skeleton + retry kept.
- **Realtime live-update:** already invalidated by `onRealtimeNotification`; pagination list refreshes on invalidation (top page reload — acceptable; noted in §30).

---

## 12. Unread Badge

- `primary_header_actions.dart` already renders `Badge` from `unreadCountProvider` (verified lines 47-52). Gate: guest → 0.
- 2.4 changes the **source of truth timing** only: `unreadCountProvider` is re-invalidated on realtime insert/update events (via `PushNotificationService.onRealtimeNotification` and a new `onRealtimeReadChanged`), plus a periodic reconcile stream (replaces the 1-min polling).
- Drawer badge (`notifications_module.dart` drawer entry) refactored to consume the **same** provider/stream — removing the duplicated polling block.
- Cap display at `99+` (already handled).

---

## 13. Push Notification Tap

- **Foreground:** `FirebaseMessaging.onMessage` → local notification (with dedup vs realtime, §10).
- **Background/terminated:** `onMessageOpenedApp` + `getInitialMessage` (already wired) → resolve deep-link (§14) → mark read → navigate.
- **Local-notification tap (when app suppressed/background):** `onDidReceiveNotificationResponse` already decodes payload → same resolver.
- **Cold start:** `getInitialMessage` handled inside `initialize()`; router may not be ready at the exact frame — navigation is deferred to post-frame/next tick after router is live (`rootNavigatorKey.currentContext` guard already present; add retry-window).
- **Route resumption:** target page must read its own id from path params (existing pages already do: `support_chat_room_page`, etc.).

---

## 14. Controlled (Safe) Deep-Link Architecture

**Today:** `NotificationPayload.resolveDeepLink()` returns the raw `deep_link` or a `_defaultDeepLink` that references **non-existent routes** (`/market/orders/:id`, `/service-booking/:id`, `/ride/:id`) → `GoRouter` error page. `notification_center_page.dart` pushes raw `deepLink`. **Unvalidated → arbitrary navigation.**

**2.4 design:**
1. **Server allowlist table (new, migration 041):** `notification_destinations(route_pattern text PK, description text, allowed_roles text[] NULL, is_active bool DEFAULT true)` seeded with the real routes:
   - `/notifications`, `/profile`, `/rewards`, `/wallet`, `/orders`
   - `/support/room/:roomId`
   - `/admin/support-chat/room/:roomId`
   - `/campaign/:id` (new landing, §19)
   - `/my-complaints`, `/admin/complaints`
   - `/safety`
   - `/admin/live-tracking` (emergency landing placeholder)
2. **`validate_notification_deep_link(p_deep_link text)` RPC** (SECURITY DEFINER): returns the input iff it matches a **prefix/pattern** of an active row (parameterized, no `LIKE '%..%'` wildcard injection), else NULL. Never returns `javascript:`/`http(s)://`/arbitrary paths.
3. **Client resolver** (`NotificationPayload.resolveDeepLink`) rewritten to:
   - accept ONLY: an allowlisted route resolved via a local static mirror of `notification_destinations` (fetched once via `notification_destinationsProvider`), or a **mapping table** for known types/entities → real routes;
   - fall back to `/notifications` when nothing resolves;
   - **never** push an arbitrary string.
4. **Server-side writer hardening:** new canonical writers always pass through validation; legacy writers (033/040) store safe, known routes already (`/admin/support-chat/room/:id`, `/campaign/:id`) — no change to those files; a trigger-level check is NOT added (would block legacy inserts) — validation is enforced at **consumption** (client) + **production** (allowlist). Documented as accepted risk with mitigation (routes are static, no user-controlled input).

---

## 15. Foreground / Background / Cold Start / Logout

| State | Behavior (2.4) |
|---|---|
| **Foreground** | Realtime insert → update center + badge + local notification (deduped). FCM onMessage → local notification only if not already shown. |
| **Background** | FCM data message → `firebaseMessagingBackgroundHandler` shows local notification (existing) with `NotificationPayload` in payload. Tap → resolver + mark read. |
| **Terminated/cold start** | `getInitialMessage` (existing) → after router ready → resolver + navigate + mark read. |
| **Logged out** | Push service unsubscribes channel, cancels heartbeat; tokens deactivated **per device** (RPC). Cold-start deep-link with no session → route redirect already sends `/login`/`/welcome` (router redirect verified); resolver falls back to `/notifications` after auth. |
| **Guest** | No FCM token, no badge, notification icon → `/login` (existing behavior in `primary_header_actions`). |

---

## 16. Support Chat Notifications

**Verified existing (033):** `_assign_chat_to_admin` inserts `chat_assigned`/`chat_escalated` notifications for the assigned admin with `/admin/support-chat/room/:roomId` + idempotency `chat-assign-<room>-<admin>`. RLS: `chat_rooms`/`chat_messages` published to realtime.

**2.4 adds:**
- **NEW trigger `notify_chat_message_reply`** on `chat_messages` AFTER INSERT, SECURITY DEFINER: when a message is inserted by a participant and the room is open, notify the **counterpart user** (customer or admin) with `type='message'`, `data {entity_type:'room', entity_id, action:'reply'}`, `deep_link = /support/room/:roomId` (customer) or `/admin/support-chat/room/:roomId` (admin), idempotency `chat-msg-<message_id>`, `send_push=true`. This powers "customer gets a push when the admin replies (and vice versa)". **Push only if the recipient has the app installed (active token) — RLS is not a factor; the trigger runs in service context and only creates notification rows.** To avoid noise: suppress when the recipient is currently viewing the room is NOT determinable server-side in this phase — **mitigation:** only notify on the FIRST message of a turn (admin→customer transition), i.e., when the previous message author differs; documented in §30.
- Admin assignment notifications (033) now also reach the device automatically via the new push trigger (§7) — **no 033 edit**.
- `chat_assigned`/`chat_escalated` client mapping → `NotificationType.message`.

---

## 17. Complaints Support

**Verified state:** `complaints` table (complainant_id, respondent_id, reporter_id, status, priority, admin_notes, resolution_note, resolved_at) — **no region_id, no notification writes today**; routes `/my-complaints`, `/admin/complaints` exist; complaint detail page does NOT exist.

**2.4 adds:**
- **NEW trigger `notify_complaint_status`** on `complaints` AFTER UPDATE OF `status`, SECURITY DEFINER: on `open`/`resolved`/`closed`, notify `complainant_id` (and, where present, `reporter_id`) with `type='complaint'` (client maps → `system` icon, or mapped color), `data {entity_type:'complaint', entity_id, action:status}`, `deep_link = /my-complaints`, idempotency `complaint-<id>-<status>-<to_uid>`, `send_push=true`.
- **NEW notification to admins** when a complaint is filed: `type='complaint'`, `deep_link=/admin/complaints`, `sender_id = complainant`, idempotency `complaint-new-<id>`, only for admins with region scope where determinable (fallback: all admins). Complaint detail page remains out of scope (2.4 = notifications; admin already reviews from the list page).

---

## 18. Emergency (SOS) Support

**Verified state:** `sos_alerts` (user_id, lat/lng, address, status active/escalated/resolved/false_alarm, notified_contact_ids, notes, created_at, resolved_at); RLS fixed in 033 for admin command-center; `activeSosAlertsProvider` exists but unused; **no assigned_admin column**; no admin emergency page (that is Phase 2.5 scope).

**2.4 adds (notifications ONLY — no Emergency Command Center):**
- **NEW trigger `notify_sos_alert`** on `sos_alerts` AFTER INSERT, SECURITY DEFINER:
  - Notify the user's **trusted contacts** (`sos_contacts` — existing table) with `type='emergency'`, `priority='high'`, `deep_link=/safety`.
  - Notify **admins** in scope (via `has_permission('EMERGENCY_VIEW', region)` where a region can be derived from the user's region; fallback: all admins) with `type='emergency'`, `priority='high'`, `deep_link=/admin/live-tracking` (landing placeholder until 2.5), idempotency `sos-notify-<id>-<to_uid>`.
  - **Priority ≠ authorization:** the notification is informational; all admin screens remain permission-gated by existing RLS/RPC guards. The trigger inserts rows; RLS still controls reads.
- **Flutter:** `emergency` client type → `NotificationType.security` (red icon). No new admin page in 2.4.

---

## 19. Campaign Support (039/040)

**Verified state:** `campaigns` lifecycle (submit/decide/publish/expire) from 039/040; 040 writes `promotion` notifications (`campaign-approve/-reject-<request_id>`, deep-link `/campaign/<id>`); **no customer/merchant campaign detail route exists** in the Flutter router.

**2.4 adds:**
- **NEW route `/campaign/:id`** → a minimal read-only `CampaignDetailPage` (from `campaigns` via existing RLS; shows name/type/status/dates/image). This makes 040's `deep_link` resolve to a real page (today it hits the router error page).
- Client mapping: `promotion` → existing `NotificationType.promotion` (icon/color already present).
- 040 notification texts stay server-provided (Arabic) — §24 documents l10n approach.
- Campaign **publish** broadcast notifications to eligible users: reuse `admin_broadcast_notification` (018/019) with `type='promotion'` + deep-link `/campaign/:id` — no new table.

---

## 20. Rewards Support (Phase 2.3 / 038)

**Verified state:** 038 writes `reward` notifications with idempotency `reward-<type>-<period>-<uid>` and `deep_link = /profile` (config-driven); `NotificationType.reward` exists with icon/color in the center + admin push page; `/rewards` route exists.

**2.4 changes:**
- 038 rows get push automatically via the new trigger (§7) — no 038 edit.
- Client resolver maps `reward` notifications to `/rewards` (deep-link `/profile` → remapped to `/rewards` by the resolver, since the reward lives in the rewards page). Optional: leave `/profile` — resolver decision documented: map to `/rewards` for better UX.

---

## 21. Permissions by Role (client / provider / driver / admin / owner)

| Capability | customer/provider/driver | admin | owner | service_role |
|---|---|---|---|---|
| Read own notifications | ✅ RLS `auth.uid()=user_id` | ✅ own + all via `is_admin()` | ✅ own + all | ✅ |
| Update own read state | ✅ (via `markAsRead` RPC or policy) | ✅ | ✅ | ✅ |
| Change own notification content | 🔒 **BLOCKED (new guard §22)** | ✅ | ✅ | ✅ |
| Delete own notifications | ✅ | ✅ | ✅ | ✅ |
| Delete any/all notifications | ❌ | ✅ (`is_admin()`) | ✅ | ✅ |
| Manage own device tokens | ✅ `register_device_token`/`deactivate_device_tokens`/`refresh_token_heartbeat` | ✅ own | ✅ own | ✅ |
| List all device tokens | ❌ | ✅ (admin page) | ✅ | ✅ |
| Broadcast to users (admin push page) | ❌ | ✅ `admin_broadcast_notification` | ✅ | ✅ |
| Read unread count for self | ✅ | ✅ self; ⚠️ all (hardened to admin-only for other ids) | ✅ | ✅ |
| Create notifications | ❌ (except admin broadcast RPC) | ✅ (RPC) | ✅ | ✅ |
| Trigger SOS/emergency notifications | via SOS trigger (trusted contacts) | receives | receives | ✅ |
| `SEND_PUSH_TOKEN` / FCM call | ❌ | ❌ | ❌ | ✅ (edge function only) |

`is_admin()` = role IN ('admin','owner') (verified 016/018). Provider/driver are ordinary authenticated users for notification purposes (they receive member-level notifications). Admin surface permission checks continue via `is_admin()` and `has_permission()` (034).

---

## 22. RLS & RPC Security

**Verified gaps → fixed in 041 (additive):**

1. **UPDATE-any-column gap:** "Users update own notifications" allows owners to rewrite `title/body/type/deep_link` of their own rows. **Fix:** keep the policy for read-state convenience BUT add `BEFORE UPDATE` trigger `guard_notifications_user_update` (SECURITY DEFINER) that RAISEs unless: only `is_read`/`read_at` changed, OR caller is admin, OR caller is service_role. (Non-invasive; no policy churn that could break existing clients.)
2. **`get_unread_notification_count` info-leak:** counts ANY passed user id, no `search_path`. **Fix:** `CREATE OR REPLACE` + `SET search_path` + `p_user_id = auth.uid() OR is_admin()`.
3. **`deactivate_stale_tokens`:** no `search_path`. **Fix:** `CREATE OR REPLACE` + `SET search_path = public, pg_temp`.
4. **`admin_broadcast_notification`:** already SECURITY DEFINER + `search_path` pinned + `is_admin()` gate + authenticated-only EXECUTE (verified 019) — **no change**.
5. **New RPCs** all `SECURITY DEFINER SET search_path = public, pg_temp`; EXECUTE granted: token RPCs → `authenticated`; `cleanup_invalid_token`, `dispatch_push`, `validate_notification_deep_link` → `service_role`/`authenticated` respectively as designed; `public` always `REVOKE`.
6. **Grants on tables:** keep existing (`authenticated` SELECT/INSERT/UPDATE/DELETE on notifications + notification_tokens via RLS). Add nothing that widens access.
7. **Realtime security:** RLS filters channel rows (policy `auth.uid()=user_id`) — no `notification_tokens` publication (verified absent) — keep.
8. **Secrets:** `SEND_PUSH_TOKEN` and FCM credentials exist only as Supabase function secrets / env — never in code, repo, logs, or this document. PAT at `~/.supabase/access-token` used only for live verification, never printed/committed.

**RPC EXECUTE audit matrix (probe table):** every notification RPC is probed for anon/authenticated/admin/service_role × expected allow/deny (see §27).

---

## 23. Token Security

- Tokens stored **encrypted-by-default** only if app adds encryption; DB stores raw (current). 2.4 adds **no new storage**; relies on RLS (own-token only) + service_role RPC boundaries.
- FCM HTTP v1 requires **OAuth2 service-account token** (Google `auth` lib) or legacy server key; the edge function holds the credential server-side (function secret), never on-device. Client only ever holds its own FCM token.
- `cleanup_invalid_token` ensures revoked/unregistered tokens are deactivated promptly (FCM 404/410) to prevent send-lists growing stale.
- No token ever leaves the DB through realtime (table unpublished), no admin page exposes raw tokens beyond platform/updated_at (verified admin page selects `token, platform, updated_at` — token visible to admins only, consistent with "Admins can select all tokens").
- `deactivate_device_tokens` uses `auth.uid()` (server-derived) — clients cannot deactivate another user's tokens.

---

## 24. Localization AR/EN

- **UI chrome (client):** Notification Center grouping labels (`اليوم/أمس/أقدم` → `notificationToday/notificationYesterday/notificationOlder`), priority labels, empty/error/retry/confirm strings — all added to `l10n/app_en.arb` + `app_ar.arb` (generated via `flutter gen-l10n`), reusing existing keys where present.
- **Notification content (title/body):** server-generated strings stay **as-is** (033/038/040 already write Arabic; 018/019 broadcast accepts arbitrary text). The canonical `data` shape carries structured `entity_type/entity_id/action` so the client CAN render localized fallback text when a row lacks a localized body. Full client-side template rendering of server notifications is **out of scope** (would require rewriting 033/038/040 writers = prohibited). Documented decision.
- New l10n keys: ~8 (3 date sections, 2 priority labels, 1 new-empty-state text if any, 1 "campaign" page title/desc, 1 emergency title). AR/EN both.

---

## 25. Flutter Modules / Files Affected

**New files:**
- `lib/core/notifications/notification_channels.dart` — channel-name registry.
- `lib/core/notifications/notification_route_resolver.dart` — allowlist deep-link resolver + destination mirror provider.
- `lib/features/notifications/presentation/widgets/notification_card.dart` — extract/extend card (priority chip) if needed (or edit in place).
- `lib/features/campaigns/` (new feature module) — `CampaignDetailPage` + provider + repository/DS read from `campaigns` via RLS (+ register in `lib/module_registry.dart`). **Minimal, read-only.**
- `supabase/functions/send-push/index.ts` + `supabase/functions/send-push/deno.json`.

**Modified files (additive changes only):**
- `lib/services/push_notification/push_notification_service.dart` — device-id, register/heartbeat/logout RPCs, auth-gated realtime, reconnect, dedup, auth-state reset of `_initialized`.
- `lib/features/notifications/notifications_module.dart` — realtime-first unread stream, single badge source, drawer refactor.
- `lib/features/notifications/presentation/pages/notification_center_page.dart` — pagination, l10n grouping, priority visuals, resolver-based tap.
- `lib/data/datasources/remote/supabase_notification_data_source.dart` — map `priority`/`sender_id`/`push_status`; type alias mapping (`chat_assigned/chat_escalated→message`, `emergency→security`, `complaint→system`, `admin→account`).
- `lib/domain/entities/app_notification.dart` — add `NotificationPriority` + fields; resolver rewrite; `NotificationPayload` gains `priority`.
- `lib/data/repositories/supabase_notification_repository_impl.dart` — new repo methods (registerToken/deactivateTokens/heartbeat/validateDeepLink) or delegate to dedicated `TokenRepository`; keep interface additions additive.
- `lib/domain/repositories/notification_repository.dart` — additive token/deep-link methods.
- `lib/features/auth/presentation/auth_provider.dart` — signOut already calls `deactivateTokensOnLogout()` (verified) → no change needed, but confirm device-scoped call.
- `lib/l10n/app_en.arb`, `app_ar.arb`, generated localizations.
- `lib/features/campaigns/...` registered in `lib/module_registry.dart`.
- Tests: `test/features/notifications/...`, `test/features/campaigns/...`, `test/services/push_notification/...` (new).

**NOT touched:** `app_router.dart` redirect logic (only new route registration via module registry), `primary_header_actions.dart` (already reads provider), `notification_preferences_page.dart` (kept as UI stub — wiring prefs to DB is out of scope, documented), reward module, support-chat module internals, admin module.

---

## 26. Migrations Required + Number (Verified)

**Verified numbering:** existing files `001`–`035`, then `038`, `039`, `040` (036/037 absorbed by promotion platform). **Next number = `041`.**

**ONE new migration file:** `supabase/migrations/041_notification_delivery_layer.sql` — additive, idempotent (`IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE`), live-applied via `apply.py`.

Contents (summary — full SQL written during implementation, NOT now):
1. `notifications` ADD COLUMN `priority text NOT NULL DEFAULT 'normal'` + CHECK (`low`,`normal`,`high`); `sender_id uuid` (nullable); `send_push bool NOT NULL DEFAULT true`; `push_status text NOT NULL DEFAULT 'pending'` + CHECK (`pending`,`sent`,`failed`,`unconfigured`); `push_sent_at timestamptz`; `push_error text`. Backfill: existing rows → `push_status='unconfigured'`.
2. Index: `(user_id, push_status)` partial for dispatch queries.
3. `notification_destinations` table + seeds (allowlist §14).
4. RPCs: `register_device_token`, `deactivate_device_tokens`, `refresh_token_heartbeat`, `cleanup_invalid_token`, `validate_notification_deep_link`, `dispatch_push`; hardened `CREATE OR REPLACE` of `get_unread_notification_count`, `deactivate_stale_tokens`.
5. Triggers (AFTER INSERT, SECURITY DEFINER): `notify_notification_push` (notifications → pg_net → send-push), `notify_chat_message_reply` (chat_messages), `notify_complaint_status` (complaints), `notify_sos_alert` (sos_alerts); `BEFORE UPDATE` guard `guard_notifications_user_update`.
6. RLS: no policy changes required EXCEPT drop/recreate if the read-state UPDATE policy is refined to be column-safe via the trigger (policy itself stays); grant/REVOKE tuning for new RPCs.
7. Comments documenting canonical type vocabulary + destinations.

**Explicitly NOT changed:** 030, 031, 032, 033, 034, 035, 038, 039, 040 (no edits; no re-runs that alter behavior; 027/028 historical applies untouched).

---

## 27. Test Plan

### Backend probes (24) — run live via `oneq.py`/`apply.py` + dedicated `probe_041` suite (mirrors probe_033/034/038 style):

1. Migration 041 applies idempotently (re-run → no error, no residue).
2. New columns exist with correct defaults (`priority='normal'`, `send_push=true`, `push_status='pending'`).
3. CHECK constraints reject `priority='urgent'` (invalid).
4. `notification_destinations` seeded (≥10 routes).
5. `validate_notification_deep_link` accepts `/support/room/<uuid>`.
6. `validate_notification_deep_link` rejects `javascript:...` / `http://...` / `/../../etc`.
7. `register_device_token` inserts new token for current uid.
8. `register_device_token` upserts same token (no duplicate row).
9. `register_device_token` with same device_id deactivates the old token (rotation).
10. `refresh_token_heartbeat` bumps `last_seen_at`.
11. `deactivate_device_tokens(deviceId)` deactivates only that device's tokens (other device stays active).
12. `deactivate_device_tokens(NULL)` (legacy) deactivates all user tokens.
13. `cleanup_invalid_token` marks token inactive.
14. Token RPCs reject anon / other-user device id.
15. `notify_notification_push` trigger creates a `net.http_post` job row (pg_net) for an inserted notification.
16. Trigger skips when `send_push=false` OR `user_id IS NULL`.
17. `dispatch_push` idempotent (re-call on `sent` → no-op).
18. RLS: user selects only own notifications.
19. RLS: user cannot select/delete another user's notification.
20. `guard_notifications_user_update`: user UPDATE of `title` → RAISE; UPDATE of `is_read`/`read_at` → allowed.
21. `get_unread_notification_count`: other-user id → denied (non-admin); own id → correct count.
22. `notify_chat_message_reply`: message from admin → notification for customer (idempotent per message); customer→admin likewise.
23. `notify_complaint_status`: status change → notification for complainant + admins (idempotent).
24. `notify_sos_alert`: SOS insert → emergency notification for trusted contacts + admins (idempotent, priority high), and does NOT grant any admin page access (authorization intact).

### Flutter tests (10):
1. `NotificationPayload.resolveDeepLink` allowlist: known routes pass; unknown/JS/http → `/notifications`.
2. `_fromRow` mapping: `chat_assigned→message`, `emergency→security`, `priority` parsed, `push_status` present.
3. Notification Center: pagination load-more appends page 2.
4. Notification Center: localized grouping labels (AR/EN) — no hardcoded Arabic.
5. Notification Center: priority-high card renders chip; tap marks read + resolves via resolver.
6. Unread badge: realtime insert event increments count; read event decrements.
7. `register_device_token`/`deactivate_device_tokens` RPC params (device_id included; logout device-scoped).
8. Cold start: `getInitialMessage` → resolver → correct route (mock).
9. Logged-out deep-link: guest tap → resolver fallback `/notifications` (no crash).
10. Duplicate guard: same `notification_id` realtime event not double-shown.

Existing suites re-run: `flutter analyze` 0 errors; full `flutter test` (759 → ~770 expected). Pre-commit gate per AGENTS.md §7.

---

## 28. Live Verification Plan

All backend probes above run against **live** project `bttnlkmwhorjamzemwda` via the Management API tools (`/tmp/opencode/oneq.py` single-statement, `apply.py` migration apply), with PAT from `~/.supabase/access-token` (never printed/committed). Residue checks (zero leftover rows/tokens/jobs) after each probe group. FCM end-to-end live send is **blocked on FCM credentials** → verified to the `unconfigured` boundary (push_status=unconfigured, edge function reachable, realtime delivery exercised). When owner supplies credentials, re-run the FCM group.

---

## 29. Physical-Device Verification Plan

**Status: PENDING — device not connected.** Per AGENTS.md §7, `flutter run --dart-define-from-file=.env.dev` on an Android device is part of the pre-commit gate; with no connected device, this step is recorded as PENDING in the final gate with the exact command to run. The verified matrix once a device is attached: FCM token registration, background push (test console/Firebase), tap deep-link, cold start, foreground dedup, logout device deactivation, AR/EN rendering.

---

## 30. Risks & Edge Cases

| # | Risk / edge case | Mitigation |
|---|---|---|
| 1 | FCM credentials absent → no real push | Graceful `unconfigured` no-op; realtime still delivers in-app; operator re-dispatch RPC; owner-credential step documented |
| 2 | Trigger network call could add latency to inserts | pg_net fire-and-forget; trigger never blocks/throws; wrapped in exception guard |
| 3 | Chat reply notifications too noisy | Only fire on author-change (first message of a turn) |
| 4 | `push_status` backfill semantics for 0 existing rows | No rows today (verified); default safe anyway |
| 5 | Legacy `deep_link` values not in allowlist | Client resolver falls back to `/notifications`; legacy writers already use known routes |
| 6 | Real-time duplicates on reconnect | Client dedup by `notification_id` |
| 7 | Pagination + realtime invalidation resets scroll | Acceptable v1 (page-1 reload); noted; future: incremental list |
| 8 | `_initialized` re-login bug today | Replaced with auth-state-driven init/reset |
| 9 | `NotificationType` enum churn breaking exhaustive switches | NO enum additions (mapping approach) — verified 2 switches + 2 length tests unaffected |
| 10 | Admin sees all tokens (privacy) | Existing behavior kept; admin-only SELECT retained |
| 11 | `get_unread_notification_count` hardened could break clients passing other uids | Only self-calls in app (verified) |
| 12 | Emergency notifications are not an authorization bypass | Notifications are rows; page access still RLS-gated (probe 24) |
| 13 | Multilingual body content | Server text kept; structured data enables future client templating |
| 14 | `notification_preferences_page` is a UI stub | Out of scope; documented (prefs persistence = later phase) |
| 15 | Edge function deploy needs `supabase` CLI (linked ✓) | Deploy with no secrets; no credentials required for no-op path |
| 16 | `validate_notification_deep_link` with parameterized patterns | No wildcard LIKE injection; exact pattern match |

---

## 31. Execution Sub-Phases with Exit Gates

| Sub-phase | Work | Exit gate (all green) |
|---|---|---|
| **SP-2.4.0** | Plan approval | Owner approval of this document |
| **SP-2.4.1** | Migration `041` authoring + live apply + probes 1–24 | Migration idempotent; 24/24 probes green; zero residue; RLS/RPC matrix green |
| **SP-2.4.2** | Edge Function `send-push` deploy + pg_net wiring verification | Function deployed; trigger enqueues; `unconfigured` no-op path verified; no secrets in repo |
| **SP-2.4.3** | Flutter layer: entity/DS/repo/resolver/service/module/center/pagination/badge/l10n/campaign page | `flutter analyze` 0 errors; 10 new Flutter tests pass; existing 759 still pass |
| **SP-2.4.4** | Full gate | `flutter pub get` + `analyze` + `test` clean; backend live suite re-run; secret scan (no PAT/keys in repo); scope check (no 2.5+); HANDOFF-35 final gate written |
| **SP-2.4.5** | Ship | Commit `sprint 78: implement notification delivery and deep links`; push; verify origin/master == local HEAD; docs updated (HANDOFF-35, SESSION_STATUS, ROADMAP, ADR if new architectural decision); final 22-item report ending `🟢 PHASE 2.4 COMPLETE`; STOP (no Phase 2.5) |

---

## 32. Explicitly NOT Changed (Preservation Contract)

- **Migrations 030, 031, 032, 033, 034, 035, 038, 039, 040** — files untouched, no behavioral re-runs. Phase 2.1 (geographic), 2.2 (support chat/admin management/member mgmt), 2.3 (rewards/engines/retention), and 039/040 (promotion campaign) architecture preserved.
- **`admin_broadcast_notification`, `has_permission`, `resolve_support_admin`, `_assign_chat_to_admin`, `write_audit`, `run_member_engines`, campaign lifecycle RPCs** — unchanged signatures/behavior.
- **`NotificationType` enum (13 values)** — unchanged; mapping layer handles server strings.
- **Existing realtime publication contents** — no table removed; `notification_tokens` remains unpublished.
- **Existing table/RPC/provider set** — no new parallel notifications system; no duplicate RPCs; `notifications` + `notification_tokens` are the single source of truth.
- **Flutter router redirect/auth logic, rewards module, support-chat module internals, notification preferences page** — untouched.
- **No credentials/secrets written anywhere** — PAT only used for live verification; FCM/`SEND_PUSH_TOKEN` secrets live only in Supabase function config when provided by owner.

---

*End of HANDOFF 34. Awaiting owner approval before SP-2.4.1. No code, schema, migration, commit, or push has been performed.*
