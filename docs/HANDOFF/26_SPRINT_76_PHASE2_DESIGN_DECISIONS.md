# Phase 2 Design Decisions — D1–D4 (Sprint 76)

> **Date:** 2026-08-15 — **Status:** RESOLVED (approved by user message)
> **Base:** `f65ab61` (Sprint 75) — audit: `docs/HANDOFF/25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`
> ADRs logged in `docs/DECISION_LOG.md` (ADR-049 … ADR-052).

---

## D1 — ADMIN IDENTITY / AUTHORIZATION (ONE canonical authority)

**Current state**
- `users.role` CHECK includes `'admin','owner'`; `public.is_admin()` (016) = `users.role IN ('admin','owner')`.
  Already consumed by: chat_rooms/chat_messages RLS (016), complaints/sanctions/location_updates RLS
  (016), notifications RLS (018/026), Flutter router (`app_router.dart:53–55`), `chat_providers.dart:24`,
  profile/sidebar gating.
- `admin_users` (002:100): `id` is a **separate generated UUID** (not `users.id`), plus `full_name`,
  `email`, `role` CHECK (`super_admin`,`admin`,`moderator`,`support`,`finance`), `status`, `last_login`,
  `created_at`. **No `user_id` FK to `users`.**
- `admin_users` has **no seed rows**. Its 005 RLS compares `admin_users.id = auth.uid()` — structurally
  impossible to satisfy (ids come from different generators), so the table is **inaccessible to every
  real authenticated user**. `admin_web` is an ungated MaterialApp that queries with the **anon key**, so
  it cannot perform admin_users CRUD either.

**Problem**
Two independent authorization authorities exist (`users.role` vs `admin_users`), the second of which is
dead-in-practice (broken identity linkage, no grants, no seeds). Risk of "two admin hierarchies".

**Options considered**
1. **Promote `admin_users` to the canonical authority** — requires a `user_id` migration, a new
   `is_admin()` that joins to `users`, rewiring every RLS policy, the router, and all provider gates.
2. **Promote the 016 model (`users.role`) to the single canonical authority** — zero rewiring; all
   consumers already use it. Treat `admin_users` as dormant/legacy metadata.
3. **Hybrid** — new third system. Rejected (explicitly forbidden; "DO NOT create a third admin system").

**Selected option: Option 2 — the 016 model is canonical; `admin_users` is preserved as legacy/dormant.**

**Why selected**
- It is the de-facto standard: every live RLS policy + the app router already authorize on it. Adopting
  it requires **no authorization rewiring** and eliminates the duplicate authority.
- `admin_users` carries no live authorization value today (broken linkage, empty, anon-key admin_web);
  deleting it is unnecessary and would violate AGENTS.md §12.1 (Dormant Infrastructure).
- Server-side authz remains intact: all admin-gated RLS still funnels through `public.is_admin()`
  (SECURITY DEFINER, 016 pattern). Clients only decide *which UI to show*; the server decides *access*.

**Migration impact**
- Phase 2.1: **none** (regions use `public.is_admin()` for write policies; no admin table changes).
- Phase 2.2 (deferred): add `user_id UUID REFERENCES users(id)` to `admin_users` to *link* legacy
  metadata records to canonical identities — **connect, not fork**. New admin hierarchy will extend the
  canonical identity model (e.g., an `admin_profiles` table keyed by `users.id`), not `admin_users.role`.

**Security impact** — Improved: one authority; `admin_users` (previously holding broken policies) is
left with RLS intact and no grants change. All admin decisions remain server-side.

**Backward compatibility** — None broken: `users.role` semantics unchanged; `admin_users` rows
untouched; `admin_web` continues to work exactly as before (read-only effectively).

**Flutter impact** — None for D1 itself; router/provider gates stay as-is.

**Supabase impact** — No DDL in 2.1. 2.2 adds the link column + hierarchy tables.

**Testing impact** — 2.1 regions tests assert admin-only region writes via RLS policy presence; 2.2 adds
hierarchy/identity tests.

---

## D2 — CANONICAL EGYPT REGION MODEL

**Current state** — No region tables exist. `GeoLocation` (commerce) holds `city`/`district` free strings
from geocoding. Location providers reverse-geocode only. Region/governorate keywords match nothing
structural.

**Problem** — No canonical region source; cannot route (support routing, region scoping) on anything.

**Options considered**
1. Flutter-only dataset (asset JSON as source of truth). Rejected — Supabase must be authoritative.
2. Single flat governorate table. Rejected — cannot express parent-child hierarchy for 2.x scoping.
3. **Recursive self-referencing `regions` table + per-user region state** (selected).

**Selected option: Option 3**

**Final ER model**

```
regions
  id              UUID PK            (stable, deterministic for seed rows)
  code            TEXT UNIQUE NOT NULL (canonical stable id; ISO 3166-2:EG for governorates)
  parent_region_id UUID NULL REFERENCES regions(id)
  country_code    TEXT NOT NULL DEFAULT 'EG'
  type            TEXT CHECK ('country','governorate','city','district','area')
  name_ar         TEXT NOT NULL
  name_en         TEXT NULL
  is_active       BOOLEAN NOT NULL DEFAULT TRUE
  metadata        JSONB NULL         (e.g. {"iso3166_2":"EG-C"})
  created_at / updated_at TIMESTAMPTZ

user_region_preferences
  user_id    UUID PK REFERENCES users(id) ON DELETE CASCADE
  region_id  UUID NOT NULL REFERENCES regions(id)
  source     TEXT CHECK ('detected','manual','verified')
  updated_at TIMESTAMPTZ
```

Hierarchy: `Egypt(country) → governorate → city/district → area`. Only **country + all 27 governorates**
are seeded now (authoritative public dataset — see below). City/district/area **must not be fabricated**;
they are added in later sub-phases from a verified source.

**Why selected**
- Self-referencing parent keeps lookup (`getChildren`, `getRegion`) generic for any depth.
- Stable deterministic UUIDs + ISO codes → immutable references usable across detections/assignments.
- Separate `user_region_preferences` keeps region *catalog* (shared) and region *state* (per-user,
  with source semantics) cleanly separated; region catalog never polluted by user state.

**Dataset source (authoritative):** ISO 3166-2:EG governorate codes + the official Arabic/English
governorate names (27 governorates; Egypt's current official subdivision). No city/area data is
invented — coverage gap reported below.

**Region detection model**

```
Device GPS → coordinates → (permission denied / GPS disabled / low accuracy / offline) → handled:
   permission denied / disabled / no fix / geocode failure → resolution returns null (no record)
coordinates + reverse geocode (existing location_provider) → governorate-name candidates
   → RegionResolver.normalize() (strip diacritics, normalize hamza/alef, strip "محافظة"/"governorate")
   → exact governorate match across candidates
   → 0 matches  ⇒ null (ambiguous/no match ⇒ no record, no overwrite)
   → >1 matches ⇒ null (ambiguous ⇒ no record, no overwrite)
   → 1 match    ⇒ canonical region_id = DETECTED
optional user confirmation ⇒ VERIFIED   |   manual pick ⇒ MANUAL
```

**State preservation policy (never silently overwrite):**

| Existing source | incoming detected | incoming manual | incoming verified |
|-----------------|-------------------|-----------------|-------------------|
| none            | save detected     | save manual     | save verified     |
| detected        | save (refine)     | save manual     | save verified     |
| manual          | **keep manual**   | save manual     | save verified     |
| verified        | **keep verified** | save manual (explicit user change) | save verified |

Detection layer never creates duplicate region records — it only ever references existing canonical
`regions` rows by id.

**Migration impact** — New `030_regional_system.sql` (regions + user_region_preferences + seed + RLS +
indexes + grants). No changes to existing tables.

**Security impact** — Regions: SELECT for `anon`+`authenticated` (public reference data); write only via
`public.is_admin()` (016). `user_region_preferences`: owner rw (RLS `auth.uid() = user_id`) + admin
select. No SECURITY DEFINER RPCs needed in 2.1.

**Backward compatibility** — Purely additive; no existing code depends on regions.

**Flutter impact** — New `features/regions` module (entities, resolver, repo, data source, providers,
selection page, module registered). No changes to existing features.

**Supabase impact** — One new migration; idempotent, deterministic seed (`ON CONFLICT (id) DO NOTHING`).

**Testing impact** — New tests: dataset integrity (parses the migration seed: 27 governorates, unique
IDs, valid hierarchy, no orphans), resolver (normalization, match, no-match, ambiguity, Arabic/English),
state-preservation policy, repository (mocktail), selection page (widget test).

---

## D3 — CHAT ARCHITECTURE (extend, don't fork)

**Current state** — `chat_rooms` (014/015): `id`, `room_type` CHECK (`support`,`complaint`,`order`,
`general`), `participant_ids UUID[]`, `order_id`, `complaint_id`, `is_active`, `last_message_at`,
`created_at`, `updated_at`; GIN index on participants. `chat_messages` (014/015): `sender_id`, `message`,
`message_type` (`text`,`image`,`file`), `attachment_url`, `is_read`, `read_at`. Deterministic RLS in 016
(admins full; participants own). Full Flutter `support_chat` stack exists.

**Problem** — `chat_rooms` lacks: priority, region (routing), assigned admin, conversation status,
escalation state, audit reference.

**Options considered**
1. New parallel `support_conversations` table. Rejected — would duplicate conversations/messages and
   fragment RLS; explicit requirement: never duplicate conversation source of truth.
2. **Extend `chat_rooms` with additive columns via a new migration (selected).**

**Selected option: Option 2 — extend `chat_rooms`.**

**Final conversation model (deferred to 2.3; columns added there)**

```
chat_rooms (existing) +=
  priority     TEXT NOT NULL DEFAULT 'normal' CHECK ('normal','high','urgent','emergency')
  region_id    UUID NULL REFERENCES regions(id)          -- routing target (D2 ids)
  assigned_admin_id UUID NULL REFERENCES users(id)       -- current owner/admin
  status       TEXT NOT NULL DEFAULT 'open'
               CHECK ('open','awaiting_customer','awaiting_admin','escalated','closed')
  escalated_to_admin_id UUID NULL REFERENCES users(id)
  escalated_at TIMESTAMPTZ NULL
  closed_at    TIMESTAMPTZ NULL
  audit_reference TEXT NULL
```

**Why selected**
- `participant_ids` already models customer identity; `room_type='support'` already exists; RLS already
  distinguishes admin vs participant. Adding routing/priority columns is purely additive and keeps one
  conversation store.
- Escalation/assignment belong as columns + server RPCs (2.5), not as a second table.

**Migration impact** — New additive migration in 2.3 (`ALTER TABLE ... ADD COLUMN`), plus RLS policy
update to keep `assigned_admin_id` visible to its admin and blocked for others.

**Security impact** — New RLS: assignee-admin scoped access; region-scoped admin visibility in 2.2/2.3.
All assignment/escalation writes via SECURITY DEFINER RPCs (016 pattern).

**Backward compatibility** — Additive; existing rooms keep `normal`/`open` defaults.

**Flutter impact** — 2.3/2.6 extend the existing `support_chat` module; no parallel feature.

**Supabase impact** — 2.3 migration + RLS; no new conversation tables.

**Testing impact** — 2.3 adds chat assignment/priority/persistence + RLS isolation tests.

---

## D4 — EMERGENCY CHAT (explicit conversation state, no second engine)

**Current state** — `complaints.priority` (`low/medium/high/urgent`) and ride-bound `sos_alerts` exist;
no emergency concept on chat.

**Decision** — Emergency support is a **conversation-level state** on `chat_rooms.priority`
(`normal|high|urgent|emergency`), not a separate transport/engine. Emergency affects priority,
notification urgency, routing (highest-available admin / escalation), and admin visibility (filter) —
all through the extended chat + existing notification infra.

**Why selected** — One chat engine; single source of truth; escalation semantics map naturally to
parent-chain routing (2.5).

**Migration/security/Flutter/Supabase/backward-compat/testing impact** — Same as D3 (additive column in
2.3; urgency mapping in 2.4; routing/escalation in 2.5). No standalone emergency system.

---

## Final Notification Flow (reuse 026/018 infra; no duplicate tables)

| Flow | Trigger (server, service_role/RPC) | Delivery |
|------|-----------------------------------|----------|
| Customer → admin | new chat message → notification to `assigned_admin_id` | realtime + FCM local |
| Admin reply → customer | new message → notification to customer `user_id` | realtime + FCM local |
| Escalation → next admin | escalation RPC → notification to `escalated_to_admin_id` | realtime + FCM local |
| Emergency | `priority='emergency'` → high-urgency notification (dedicated channel) | realtime + FCM high-priority |

All rows persist in `notifications` (idempotency_key) referencing a `deep_link`
(`/support-chat/<room_id>`). **2.4 work**: deep-link target + admin-side send RPC + urgency mapping.

## Final Authorization Flow

- **Customer**: reads/writes own rows only (`auth.uid() = user_id` RLS) — chat (participant), regions
  (preference), notifications (own).
- **Admin**: `public.is_admin()` (016) on every admin-gated RLS policy; router/providers only control
  UI visibility. Region writes admin-only. Admin hierarchy + region scoping introduced in 2.2 (canonical
  identity via `users.role`; `admin_users` linked as legacy metadata only).
- **Service role**: server-side sends/inserts only.

---

## Phase 2.7 Security Debt (recorded)

- `029` SECURITY DEFINER functions lack `SET search_path = public, pg_temp` → harden in 2.7 to the 016
  pattern. Not touched in this gate.
- All new RPCs (2.2+) MUST follow the 016 pattern (search_path + REVOKE PUBLIC + GRANT authenticated).

---

## D2 Dataset Coverage Report (required)

- **Seeded now:** 1 country (Egypt) + all **27 governorates** (ISO 3166-2:EG codes, official Arabic +
  English names). Authoritative source: ISO 3166-2:EG / official Egyptian administrative divisions.
- **Not seeded (missing, must come from a verified source later, NOT fabricated):** cities, districts,
  and areas for every governorate; country-level aliases are handled by the resolver, not the dataset.
- Repository audit: **no existing region/governorate data anywhere in the repo** (assets, lib, SQL).
