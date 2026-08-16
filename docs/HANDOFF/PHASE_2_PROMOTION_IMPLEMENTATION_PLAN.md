# Phase 2 — Promotion/Content Platform — Final Implementation Plan

> **Session:** 50 · 2026-08-16 · Owner decisions O1–O6 approved · Baseline HEAD `b1081d2`
> **Gate:** This plan is the implementation contract. **Migration 039 is written and gated first; no
> migration 040+ and no Flutter changes until the 039 gate passes owner review.**

---

## 1. Approved Decisions (recap)

| # | Decision | Verdict |
|---|----------|---------|
| O1 | `regional_offers` **MERGE/REPLACE** into the campaign platform | ✅ Approved (ADR-059) |
| O2 | Migration range **039–042** reserved for promotion; 033–038 = Phase 2.3 | ✅ Approved |
| O3 | Reuse generic `approval_requests`; **no** `campaign_approval_requests` | ✅ Approved |
| O4 | Frequency control in core schema; free delivery config-flagged + audited | ✅ Approved |
| O5 | Dedicated `campaign-media` storage bucket, strict policies | ✅ Approved |
| O6 | **No auto-published seeds**; production content via admin workflow only | ✅ Approved |

---

## 2. Pre-Implementation Verification (re-run this session, evidence-based)

| Check | Result |
|---|---|
| `regional_offers` / `offer_reviews` tables live | **Absent** (never created) → no data to preserve |
| Code references to `regional_offers`/`offer_reviews` | **Zero** in `lib/` + `supabase/` (rg verified) |
| `approval_requests` table live | **Absent** → created by promotion 040 (2.3 034 amended) |
| Any campaign/banner/content table live | **Absent** (69-table inventory) |
| Storage buckets | 5 buckets; **no `campaign-media`** → no conflict |
| Home carousel | **100% hardcoded** (`home_page.dart:146,1012–1285`) → Flutter phase E/F |
| Admin hierarchy live | `is_admin()`, `is_admin_for_region()`, `admin_region_assignments` (0 rows; 0 admins → owner routes approvals) |
| Regions/geo live | 6,157 regions, types: country/governorate/markaz/city/area/district/village/new_city; `geo_region_for_point` |
| Apply mechanism | Management API `POST /database/query` `{"query": <sql>}` (verified via 028/030/031 artifacts + `sq.py`) |
| Credential | `~/.supabase/access-token` present, mode `600` (never printed) |

---

## 3. Migration Responsibility Map (O2 boundary)

| Migration | Responsibility | Tables / objects |
|---|---|---|
| **039** `promotion_campaign_schema` | Core campaign domain (schema + RLS + validate helpers) | `campaigns`, `campaign_banners`, `campaign_reviews`, `campaign_cta_routes`, `campaign_seen` |
| **040** `promotion_targeting_media_approval` | Targeting, media, actions, approval integration | `campaign_targets`, `campaign-media` bucket + policies, CTA/benefit validation, **`approval_requests`** (generic), lifecycle/approval RPCs |
| **041** `promotion_security_hardening` | RLS/RPC/index/security hardening | `get_active_campaigns` (public feed, server-authoritative), `get_admin_campaigns`, `run_campaign_engines`, hardening indexes/RLS/privileges |
| **042** `promotion_analytics_config` | Analytics, retention, final hardening | `campaign_events`, `campaign_metrics`, `track_campaign_event`, `aggregate_campaign_metrics`, `get_campaign_analytics`, `platform_settings.promotions`, retention wiring |

Rules: **no** migration solely to reach four files (owner O2); each migration has one clear
responsibility and its own gate; migrations are additive/idempotent/non-destructive.

---

## 4. Domain Model (039 core)

### `campaigns`
- `id uuid PK`, `code text UNIQUE`, `campaign_type` CHECK (commercial: `offer`, `promotion`,
  `coupon`, `product_promotion`, `service_promotion`; content: `announcement`, `informational`;
  operational: `service_announcement`, `outage`, `important_notice`; emergency: `emergency_notice`,
  `safety_notice`).
- `priority` CHECK (`normal`|`important`|`critical`) — the **separate lane** for
  operational/emergency content; emergency types force `critical` (RPC-enforced) and are exempt from
  marketing frequency limits.
- Bilingual: `name_ar/name_en`, `subtitle_ar/en`, `description_ar/en`.
- Schedule: `starts_at`, `ends_at`, `published_at` (server-enforced window).
- Lifecycle: `status` CHECK (`draft`,`pending_review`,`approved`,`rejected`,`scheduled`,`published`,
  `paused`,`expired`,`archived`,`cancelled`).
- Governance: `proposed_by FK users`, `reason`, timestamps (`created_at`, `updated_at`, `archived_at`).
- Benefit: `benefit jsonb` (`none | coupon | promo_code | offer | code_copy | free_delivery`),
  referential + validated; free_delivery requires config flag + explicit approval.
- Frequency: `frequency jsonb` (per-campaign override of platform defaults).
- Provenance: `created_by`, `updated_by` (FK users) for audit.

### `campaign_banners`
- `campaign_id FK`, `placement` CHECK (`home_carousel`,`home_hero`,`market_top`,`campaign_detail`),
  `locale` CHECK (`ar`|`en`), `image_path` (storage reference — **no binary**), `cta jsonb`
  (controlled schema), `priority`, `is_active`, timestamps. `UNIQUE(campaign_id, placement, locale)`.

### `campaign_reviews`
- Immutable transition ledger: `campaign_id FK`, `reviewer_id FK`, `action` CHECK
  (`submit`,`approve`,`reject`,`publish`,`pause`,`resume`,`cancel`,`archive`,`expire`), `reason`
  (NOT NULL for reject/approve/publish/cancel), `previous_state`, `new_state`, `created_at`.

### `campaign_cta_routes`
- Route allowlist reference data (`route text PK`, `description`), seeded from the `FeatureRegistry`
  route set (go_router). Used by CTA validation at publish + feed time.

### `campaign_seen`
- Frequency control: `user_id FK`, `campaign_id FK`, `last_seen_at`, `impressions`, PK
  `(user_id, campaign_id)`. Upserted by ingestion (040/042 path), read by feed RPC (041).

RLS/grants: `REVOKE ALL … FROM anon, authenticated` → explicit grants; **no client SELECT on
campaign tables**; admin read via `is_admin()`; functions are the only write path.

---

## 5. Targeting (040)

- `campaign_targets(campaign_id FK, region_id FK regions, UNIQUE(campaign_id, region_id))`.
  - One row with `region_id NULL` = **national (Egypt)**.
  - Multiple rows = **multi-region** campaign (no duplicated campaigns).
  - A regional admin may target only their assigned region + authorized descendants (validated with
    `is_admin_for_region` + ancestor CTE); owner may target any valid region.
  - No hardcoded governorate strings anywhere; canonical `regions.id` only.
- Audience (on `campaigns`): `target_roles text[]` (validated against `users.role` CHECK set),
  `min_orders`, `min_spend` — evaluated in the feed RPC only.

---

## 6. Approval (040, O3)

- Generic **`approval_requests`** created here verbatim from 2.3 §19 (the ONE approval center).
- RPCs: `submit_campaign`, `review_campaign(action, reason)`, `publish_campaign`,
  `pause_campaign`, `resume_campaign`, `cancel_campaign`, `archive_campaign`.
- Authority: `is_admin()` + `is_admin_for_region()` + scope (owner implicit global). `required_approver`
  NULL = owner. **No self-approval, no self-elevation, cross-region approval prohibited.** Reason
  mandatory on every rejection. Actor + timestamp on every approval (`campaign_reviews` +
  `approval_requests`).
- Every decision → `campaign_reviews` row + `approval_requests` state + `activity_logs` (via
  SECURITY DEFINER, never direct client INSERT) + `notifications` to requester (type `promotion`).
- 2.3 amendment (documented): when 2.3 ships, its 034 must not recreate `approval_requests`.

---

## 7. Media (040, O5)

- Bucket `campaign-media`: public SELECT; INSERT/UPDATE/DELETE `WITH CHECK is_admin() OR
  service_role`; MIME `image/png|jpeg|webp`, ≤ 5 MB; object names
  `campaigns/<campaign_id>/<placement>_<locale>.<ext>`. Orphan cleanup: engine deletes objects whose
  campaign was archived/cancelled. No executables; no video in v1 (optional/controlled later).

---

## 8. Feed / Caching (041, owner visibility rules)

- `get_active_campaigns(p_region_id, p_user_id)` — SECURITY DEFINER, `SET search_path public,pg_temp`,
  STABLE. Eligibility = `status='published'` AND window open AND not paused AND audience matches AND
  region matches (via `campaign_targets`) AND frequency not exceeded (via `campaign_seen`) AND RLS.
  **No client-side filtering of downloads**; DB/backend is authoritative.
- Emergency/critical: exempt from frequency limits; optionally broadcast via `notifications`
  (realtime already wired). Ordinary promotion: **fetch + cache** (Hive 15-min TTL + in-memory
  `TtlCache`), no realtime subscription, no Redis.

---

## 9. Analytics (042)

- `campaign_events` (impression/click, service-role insert only) → daily `campaign_metrics`
  (impressions/clicks/conversions/spend). Client buffers + batch-POSTs to `track_campaign_event`
  (edge fn, service_role); **no per-impression sync DB write**. `get_campaign_analytics` mirrors
  `get_admin_analytics`. Raw events retained ≤ 90 days (2.3 retention wiring); metrics 5 years.
- Privacy: store only `user_id` where required for frequency/unique-viewer; no PII payloads; document
  retention.

---

## 10. Implementation Order (owner phases) + Exit Gates

| Phase | Scope | Migration | Exit gate |
|---|---|---|---|
| A | Schema + core campaign domain | **039** | **039 gate (this session):** schema/RLS/ACL/function-privilege/idempotency/existing-data/attack-matrix/analyzer/secret-scan/diff → 🟢/🟡/🔴 |
| B | Targets + regions + audience | 040 | per-migration gate + targeting test matrix |
| C | Approval + permissions + lifecycle | 040 | approval workflow + self-approval/elevation attack matrix |
| D | Media + storage | 040 | storage authz matrix |
| E | Home banner/carousel integration | Flutter | carousel renders only published/eligible; empty-by-design until admin content (O6) |
| F | Campaign detail page + CTA/deep links | Flutter | CTA allowlist + deep-link navigation tests |
| G | Analytics + frequency control | 042 | event ingestion + frequency limits tests |
| H | Realtime/critical announcements | 041/042 | emergency lane exempt from frequency; realtime only for critical |
| I | Full security + performance + migration gate | all | full attack matrix, analyzer, tests, secret scan, diff check |

Rule: **do not jump from schema to UI without security validation** (owner). Each migration gates
independently; **039 passes before 040 is written.**

---

## 11. Compatibility Strategy (O1/O2)

- `regional_offers`: never existed in code or DB → nothing to migrate, no data to preserve, no silent
  deletion. Superseded in ADR-059 (ADR-058 amendment). Zero code references (verified).
- `approval_requests`: not live → created by promotion 040 with the 2.3 §19 contract; 2.3's 034
  amended to not recreate it. Promotion is additive; existing migrations 030/031/032 untouched.
- No renumbering of any existing migration.
- Flutter home changes are confined to the promotions module + `home_page` carousel/hero; no changes
  to regions/admin/support/notification architecture.

---

## 12. Risks (carried from audit §39 + new)

| # | Risk | Mitigation |
|---|---|---|
| R1 | Two lifecycle machines if regional_offers rebuilt | O1 merge, ADR-059 |
| R2 | Unpublished leak | No client SELECT on campaign tables; feed RPC only |
| R3 | CTA injection | Allowlist + publish/feed-time validation |
| R4 | Free-delivery entitlement via banner | Config flag + explicit approval + order engine authoritative |
| R5 | approval_requests double-creation (2.3 034) | 040 owns it; 2.3 034 amended; documented |
| R6 | Empty carousel after hardcode removal | By design (O6); admin workflow creates content |

---

## 13. Migration 039 — exact scope (written next)

`supabase/migrations/039_promotion_campaign_schema.sql`:
- `campaigns`, `campaign_banners`, `campaign_reviews`, `campaign_cta_routes`, `campaign_seen`
- `CREATE EXTENSION IF NOT EXISTS pgcrypto` guard; revoke-before-grant; `is_admin()`-gated RLS
- Validate helpers: `campaign_validate_cta`, `campaign_validate_benefit`, `campaign_validate_priority`
  (SECURITY DEFINER, `SET search_path public,pg_temp`, anon EXECUTE revoked)
- cta_routes seed (FeatureRegistry route set)
- All additive/idempotent (`IF NOT EXISTS`); non-destructive; no data changes to existing tables
- **No lifecycle/approval RPCs yet** (they require `approval_requests` → 040) and **no feed RPC** (041)
  — 039 is pure core schema + RLS + validators.

Then: apply → run the 039 gate → produce
`docs/HANDOFF/PHASE_2_PROMOTION_MIGRATION_039_GATE.md` → **STOP for owner approval.**
