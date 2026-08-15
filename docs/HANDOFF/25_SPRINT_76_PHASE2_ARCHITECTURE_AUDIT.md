# Sprint 76 — Phase 2.0 Architecture Audit (Emergency Support, Notifications, Regions, Admin Escalation)

> **Date:** 2026-08-15 — **Type:** Audit only (no migrations, no tables, no production code)
> **Base:** `f65ab61` (Sprint 75, master, clean tree)
> **Method:** evidence-based read of `supabase/migrations/001–029`, `lib/features/{support_chat,complaints,notifications,admin,admin_web,location,safety}`, `lib/services/{push_notification,supabase,admin}`, `lib/core/router`, tests.

---

## 1. Executive Verdict

### 🟡 **REQUIRES DESIGN DECISION — AUDIT COMPLETE, READY TO PROCEED**

Phase 2 is fundamentally **buildable on the existing platform**: the chat, complaint, notification,
and admin foundations already exist and are RLS-protected. Nothing is 🔴 BLOCKED. However, **four
design decisions must be resolved inside the sub-phases** before production code is written (each
resolved at its own STOP gate per the phase plan):

| # | Design decision | Resolved in |
|---|-----------------|-------------|
| D1 | **Canonical admin identity**: `users.role IN ('admin','owner')` (016 `is_admin()`, Flutter router, chat RLS) **conflicts** with the `admin_users` table system (005 `is_admin(uid)`, admin_web, roles `super_admin/admin/moderator/support/finance`). One authority must win. | 2.2 Admin hierarchy |
| D2 | **Region canonical model**: no regions exist today; must define governorate→city→district→area hierarchy, stable IDs, and detection→manual→verified resolution semantics. | 2.1 Regions |
| D3 | **Chat room extension**: existing `chat_rooms` uses `participant_ids UUID[]` + room_type; emergency chat needs priority/region/assignment. Decide extend vs. new `support_conversations` table. | 2.3 Chat backend |
| D4 | **Emergency flag**: `complaints.priority` + `sos_alerts` exist; decide whether emergency support chat lives as a `room_type`/`priority` column or a separate flow. | 2.5 Escalation engine |

---

## 2. What Already Exists (Verified, Reuse-first)

### 2.1 Auth & users — `001`, `002`, `005`, `006`, `020`, `028`
- `users`: `id` UUID PK, `email` unique, `full_name`, `phone`, `avatar_url`, `language`,
  `is_onboarded`, `role` CHECK (`customer`,`merchant`,`driver`,`admin`) extended by `020`
  (`provider`,`delivery`,`owner`) — **role here is the customer-facing account type**, not admin rank.
- `020` adds `user_type` (default `customer`), `verification_status`, `id_card_url`, `profile_photo_url`;
  `028` adds `trade_license_url`, `driving_license_url`.
- Trigger `handle_new_user()` (SECURITY DEFINER) on `auth.users` insert (`006`).
- RLS (005): `users_select_own` / `users_update_own` / `users_insert_own`.

### 2.2 Admin — `002`, `005`, `016`, `028`
- `admin_users` (002:100): `id` (independent UUID), `full_name`, `email` unique, `role` CHECK
  (`super_admin`,`admin`,`support`,`finance`) extended by `028` with `moderator`; `status` default `pending`.
- Flutter `AdminRole` enum `{superAdmin, admin, moderator, support}` (`admin_models.dart:9`) —
  **camelCase and missing `finance`; mismatches the DB snake_case CHECK.**
- Admin repository covers dashboard/users/merchants/orders/rides/deliveries/verification + `admin_web`
  shell (`admin_web_shell.dart`). Verification approve/reject exists.
- **Conflict (D1):** `016` `is_admin()` ⇒ `users.role IN ('admin','owner')`; `005` `is_admin(uid)` ⇒
  `admin_users.status='active'`. Both overloads live in the DB. 016's comment explicitly rejects the
  `admin_users` route because `admin_users.id ≠ users.id`.

### 2.3 Complaints — `014`, `016`
- `complaints`: `order_id`, `complainant_id`, `respondent_id`, `complaint_type` CHECK
  (`driver`,`merchant`,`customer`,`provider`,`other`), `status` CHECK
  (`pending`,`investigating`,`resolved`,`rejected`,`escalated`), `priority` CHECK
  (`low`,`medium`,`high`,`urgent`), `admin_notes TEXT[]`, `resolution_note`, `resolved_at`.
- RLS (016): admins full CRUD; users own complaints only (`complainant_id`/`reporter_id`).
- RPC `add_admin_note` + legacy `add_complaint_admin_note` (SECURITY DEFINER, `SET search_path = public, pg_temp`,
  REVOKE PUBLIC, GRANT authenticated) — **the Sprint-72 pattern to replicate for all new RPCs.**
- UI: `admin_complaints_page.dart` filters/updates status incl. `escalated`; `my_complaints_page`,
  `new_complaint_page`; data source `updateComplaintStatus`, `addAdminNote`, `deleteComplaint`.

### 2.4 Chat — `014`, `015`, `016`
- `chat_rooms`: `room_type` CHECK (`support`,`complaint`,`order`,`general`), `participant_ids UUID[]`,
  `order_id`, `complaint_id`, `is_active`, `last_message_at`, `updated_at`; GIN index on
  `participant_ids`, index `last_message_at DESC`.
- `chat_messages`: `sender_id`, `message`, `message_type` CHECK (`text`,`image`,`file`),
  `attachment_url`, `is_read`, `read_at`; indexes `room_id`, `created_at`.
- RLS (016): admins full CRUD; participants select/insert/update own rooms & messages
  (`users insert own room messages` enforces `sender_id = auth.uid()`).
- Storage buckets exist: `complaints` (50 MB) + `chat_attachments` (10 MB), private, authenticated access.
- Flutter full stack: `support_chat` module (`supabase_chat_data_source`, repository, `ChatMessage`/
  `ChatRoom` entities, providers, `client_support_page`, `admin_support_chat_page`,
  `support_chat_room_page`). Admin view gated by `users.role` (`chat_providers.dart:24`).
- **No realtime on chat today** — no `channel()`/`onPostgresChanges` anywhere in the chat feature.

### 2.5 Notifications & push — `002`, `018`, `019`, `026`
- `notifications` (026): `idempotency_key` (unique partial index), `read_at`, `deep_link`,
  `image_url`; indexes `created_at`, `(user_id,is_read,created_at DESC)`. RLS: users update/delete/read
  own, `service_role` insert, admins read all (via `is_admin()`).
- `notification_tokens` (002:449 `token TEXT` + `user_id`; 026 adds `device_id`, `app_version`,
  `is_active`, `last_seen_at`; 018 adds `updated_at` + auto-trigger + `user_id` index).
- `PushNotificationService` (`lib/services/push_notification/`): FCM + `flutter_local_notifications`;
  **realtime proven**: channel `in-app-notifications` + `onPostgresChanges`(insert on `notifications`)
  → local notification + invalidates `notificationsProvider`/`unreadCountProvider`.
- `SupabaseNotificationDataSource`: `getNotifications(unreadOnly, limit 20, offset)`, `getUnreadCount`;
  `AppNotification` entity. Admin broadcast path + device-count RPC exist (`018`/`019`).

### 2.6 Location — `012`, `014`, `029` + app
- `location_updates` table (014) with RLS own/admin; `sos_alerts` (012, 029 RPCs) — emergency-adjacent
  but ride-bound and **not chat-connected**.
- App: `location_provider.dart` — GPS via geolocator → reverse geocode → `detailedAddress`; prefs cache
  `location_geocode_cache_v2` (TTL 24 h, max 200); `GeoLocation` entity (commerce) carries `city`/
  `district` as **free strings** from geocoding. Google Places search exists (`search` feature).
- **No canonical regions (D2):** no governorate/region/area tables, no stable region IDs, no hierarchy.
  `region`/`governorate` keywords match only geocode address parts + Places API.

### 2.7 Realtime (platform-proven)
- `Supabase.initialize` in `supabase_initializer.dart`; realtime used by push notifications
  (`in-app-notifications` channel) and driver dispatch (`dispatch_providers.dart`). Subscription
  pattern is established and correct.

### 2.8 Security baseline
- 016 sets the RLS/RPC pattern: `SECURITY DEFINER` + `SET search_path = public, pg_temp` + `REVOKE ALL
  FROM PUBLIC` + `GRANT EXECUTE ... TO authenticated`; explicit per-table grants to `authenticated`.
- **Gap:** `029` RPCs (`resolve_sos_alert`, `start/stop_live_share`, etc.) are SECURITY DEFINER **without**
  `SET search_path` — flag for hardening in 2.7 (align to 016 style).

---

## 3. What Is Missing (Confirmed NOT FOUND)

| Item | Evidence |
|------|----------|
| Regions / governorates / cities / areas tables, canonical IDs, hierarchy | 0 matches in migrations; `GeoLocation` city/district are free strings |
| Region↔admin assignment | `admin_users` flat; no region scoping |
| Admin hierarchy (parent/child, escalation parent pointer) | none |
| Escalation engine / escalation events table / escalation RPC | `escalated` exists only as complaint/sos **status string**; no events, no server logic |
| Emergency support conversation (priority/emergency flag on chat) | none — `complaints.priority` is the only priority field; `sos_alerts` ride-bound |
| Conversation assignment / assignee / ticket / queue | `assignment` matches only driver dispatch (007/008) |
| `device_token` column | `notification_tokens.token` covers it (naming: keep `token`) |
| Chat realtime subscription | none in chat feature |
| Chat / complaints automated tests | `test/features/` has no `chat`/`complaints` dirs |
| Region detection→region mapping (governorate match service) | none |

---

## 4. Proposed Final Schema (decision points, resolved per sub-phase)

```
regions                        ← 2.1  id (stable code), type (country/governorate/city/district/area),
                                      parent_id self-FK, name_ar, name_en, lat/lng bounds, is_active
user_regions                   ← 2.1  user_id, region_id, source (detected/manual/verified), status
admin_region_assignments       ← 2.2  admin_user_id, region_id, role-level (reuse/extend admin_users)
support_conversations / ext.   ← 2.3  D3: extend chat_rooms (priority, region_id, assigned_admin_id,
                                      status) vs new table — DECIDE
escalation_events              ← 2.5  conversation_id, from_admin, to_admin/parent, reason, at
notifications                  ← REUSE 026 (+ attach conversation_id deep_link)
notification_tokens            ← REUSE
chat_rooms/chat_messages       ← REUSE + additive columns (never drop 016 RLS)
complaints                     ← REUSE (add assignment FK if needed)
audit_logs                     ← 2.2/2.5  admin actions (exists partially as AdminActivityLog UI)
```

## 5. Routing / Escalation Algorithm (target, server-side)

1. Customer chats → conversation auto-assigned to the admin mapped to the user's **detected/verified region**.
2. No region-admin → fall back to nearest **parent region** admin → up to highest available → **global admin**.
3. Escalation (priority/emergency or admin-triggered) → next **parent** admin → global. Global cannot escalate above itself.
4. Customers never choose admins and cannot set/manipulate priority. All assignment/escalation via SECURITY DEFINER RPCs validated server-side.
5. Realtime + push remain **delivery acceleration**; `chat_messages`/`notifications` tables are the source of truth.

## 6. Notification Flow (target)

Create (server, service_role or RPC) → insert `notifications` (+ `idempotency_key`) → realtime channel
delivers to online app → local notification via FCM for offline → unread counter invalidated → deep-link
to conversation/room.

## 7. Flutter Module Structure (target)

- `lib/features/regions/` (2.1) — repository + detection mapper + providers + data (seed JSON or DB-backed)
- `lib/features/admin/` extended (2.2) — hierarchy, region scope, assignment
- `lib/features/support_chat/` extended (2.3/2.6) — realtime subscription, priority/emergency UI
- `lib/features/notifications/` extended (2.4) — server-side admin send path, conversation deep links
- `lib/features/escalation/` (2.5) — engine RPC client + events UI
- Register each in `lib/module_registry.dart`; independent test file per module.

## 8. Migration Sequence

`030_regions` → `031_admin_hierarchy_region_assignments` → `032_support_conversations_priority`
→ `033_escalation_engine` → `034_notification_chat_deeplinks` (+ RLS rebuild per 016 pattern on each).

## 9. Test Strategy (no inflation; mandatory)

- **Regions**: all 27 governorates + hierarchy + detection mapping + manual fallback + GPS-denied/offline/failure/ambiguous.
- **Admin**: role/permission/region/hierarchy restrictions (unit + RLS integration).
- **Chat**: create/send/reply/persistence; unauthorized blocked.
- **Escalation**: regional assign, no-admin fallback, parent walk, global cap, unauthorized rejected.
- **Notifications**: customer/admin/escalation sends, read state, idempotency.
- **RLS**: customer isolation, regional admin isolation, hierarchy authz, anonymous blocked.
- **Realtime**: authorized delivery + reconnect.

## 10. Complexity Estimate (relative, additive)

| Sub-phase | Est. size | Risk |
|-----------|-----------|------|
| 2.1 Regions | L | M (canonical data + detection accuracy) |
| 2.2 Admin hierarchy | M | M (D1 conflict) |
| 2.3 Chat backend | M | L (reuses 016 RLS) |
| 2.4 Notifications | S | L (reuses 026/018) |
| 2.5 Escalation engine | M | M (server-side correctness) |
| 2.6 Chat UI + realtime | M | M (authz filtering on realtime) |
| 2.7 Integration/security/tests | M | L (028/029 hardening included) |

---

## 11. STOP — Awaiting Approval

Audit only. **No Phase 2.1 work has been performed, no migrations/tables written, nothing committed.**
Working tree remains clean at `f65ab61`. On approval: begin **Phase 2.1 — Regions** (canonical
Egypt governorate dataset, hierarchy, detection mapping, manual fallback) and STOP at its review gate.
