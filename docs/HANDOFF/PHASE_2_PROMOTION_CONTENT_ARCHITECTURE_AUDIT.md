# Phase 2 — Promotion, Content & Campaign Architecture Audit

> **Session:** 50 · 2026-08-16 · Project `bttnlkmwhorjamzemwda` · Baseline HEAD `b1081d2` (sprint 76)
> **Gate:** Architecture Audit ONLY — **no product code, no migration 039+, no commit, no push, no Phase 2.4/2.5.**
> **Verdict:** **🟡 REQUIRES OWNER DECISION** — 6 owner decisions at §40, headed by the **regional_offers merge** (the directive-mandated checkpoint).

---

## 1. Scope & Gate

This audit designs a production-grade **Promotion + Campaign + Content + Targeting + Approval + Analytics** platform on top of the existing Supabase backend, and answers the directive's mandatory checkpoint: **what happens to `regional_offers`**.

| Boundary | Included | Excluded |
|----------|----------|----------|
| Backend | `campaigns`, banners/content, targeting, lifecycle, approval wiring, analytics, media, RLS/RPCs | No schema/migration writes now (design only) |
| Client | Home feed contract, CTA handling, campaign detail, admin Campaign Manager contract | No Dart code now |
| Reuse | Regions, admin hierarchy, `is_admin()`/`is_admin_for_region()`, `approval_requests` (2.3 §19), notifications, storage, caching, localization | No second region model, no second authz model |

The directive's non-negotiables are treated as hard constraints (not preferences) — see §5.

---

## 2. Directive Checklist (evidence-based compliance)

| # | Directive mandate | Where satisfied in this audit |
|---|---|---|
| 1 | Reuse existing regions / admin hierarchy / RLS / approvals / notifications / realtime | §13, §24–§31 |
| 2 | No second region system | §13, §26 |
| 3 | No second admin authorization system | §13, §25, §29 |
| 4 | No hardcoded governorates / campaign targeting in Flutter | §20, §26, §32, §37 |
| 5 | Server-side RLS authoritative (client never decides visibility) | §29, §30 |
| 6 | No arbitrary executable actions — controlled CTA schema | §23 |
| 7 | Media in Supabase Storage, no binary in DB rows | §18, §28 |
| 8 | Arabic + English localization per existing convention | §32 |
| 9 | `regional_offers` MUST be reviewed → keep / extend / merge verdict | §15 (recommendation: **merge/replace**) |
| 10 | No `offer_approval_requests` duplicate — reuse generic `approval_requests` unless audit proves otherwise | §25 (proved: reuse is correct) |
| 11 | No unlimited realtime subscriptions | §27 (feed is fetch + TTL cache, not realtime) |
| 12 | No premature analytics complexity — efficient event model + async aggregation | §22, §35 |
| 13 | No auto-grant of free-delivery/financial benefits — config-driven, business-approved | §21, §37 |
| 14 | Review existing `offers`, `coupons`, `promo_codes`, `promo_redemptions`, home/banner code, storage | §8–§12 |
| 15 | Verify whether campaigns/banners exist already | §7 (none exist) |
| 16 | Migration numbers proposed, must not collide | §38 |

---

## 3. Evidence & Live Verification

All facts below were re-verified live this session against project `bttnlkmwhorjamzemwda` (read-only) and the repository at HEAD `b1081d2`.

### 3.1 Repo baseline
- `git status`: master == origin/master at `b1081d2` (`sprint 76: complete Egypt geographic coverage`).
- Work-in-progress is **docs only**: `ROADMAP.md`, `SESSION_STATUS.md`, `docs/DECISION_LOG.md` modified; untracked `docs/HANDOFF/32_…`, `PHASE_2_3_MEMBER_MANAGEMENT_SUPPORT_ARCHITECTURE_AUDIT.md`, `PHASE_2_3_DECISION_LOCK_REPORT.md`.
- Migrations present: `001…032` + `032_egypt_geographic_seed`. **No migration ≥ 033 exists** (free and uncontested).
- Phase 2.3 (033–038) is **designed, awaiting owner approval** (`PHASE_2_3_…AUDIT.md` + `DECISION_LOCK_REPORT.md` — 🟡).

### 3.2 Live platform state
- `users`: 5 rows — 3 customer, 1 provider, **1 owner** (`8a23b719-…`), **0 admins**, **0 `admin_region_assignments`**.
- `regions`: **6,157** rows (governorates → markaz/aqsam → cities → villages → new cities), `type`-typed hierarchy, `parent_region_id`, `name_ar/name_en`; RLS: public SELECT, admin write; PostGIS `geo_region_for_point` live (confidence HIGH/MEDIUM/LOW).
- `notifications`: columns `type` (unconstrained text), `data jsonb`, `deep_link text`, `idempotency_key text`, `image_url text`, `is_read`, `read_at`; already published on `supabase_realtime`.
- Realtime publication `supabase_realtime` carries **23 public tables incl. `notifications`** (chat_rooms, chat_messages, complaints, sanctions, sos_alerts, location_updates, driver_locations, rides, wallets, …). **No campaign/banner table anywhere** — verified over the full 69-table inventory.
- Storage buckets (5): `category-images` (public, images), `profiles` (public, avatars), `chat_attachments` (private), `complaints` (private), `service-audio-logs` (public). **No banner bucket.**
- RPCs relevant to reuse: `is_admin()`, `is_admin(uuid)` (legacy `admin_users`), `is_admin_for_region(uuid)`, `get_admin_analytics(from,to)`, `admin_broadcast_notification(...)`, `validate_promo`, `get_unread_notification_count(uuid)`, `geo_region_for_point`.
- `platform_settings`: single row (`id='default'`) — app-level config; no `promotions` block yet (added by 042).

### 3.3 Live findings that shape the design
1. **`offers` RLS is read-only for clients** — only SELECT policies exist (`offers_select_public`, `offers_view`, both `USING true`). There is **no INSERT/UPDATE/DELETE policy**, so the merchant offer management screen cannot write today (would silently no-op / fail). This is evidence the platform's promotion content is **admin-governed**, not merchant self-serve.
2. **`activity_logs` INSERT policy is `TO public` WITH CHECK `true`** — any anon client can poison the audit log (already flagged in 2.3 §21, fix in 033). The promotion domain must NOT reproduce this: all writes go through SECURITY DEFINER RPCs.
3. **`coupons` / `promo_codes` / `promo_redemptions` exist and are reusable** as benefit references; `promo_redemptions` is owner-scoped (`user_id = auth.uid()`), `validate_promo` is the ride-promo precedent.
4. **The home promo carousel is 100% hardcoded in Dart** (`lib/features/home/presentation/pages/home_page.dart` `_PromoCarousel`, lines 1012–1285): three static slides, hardcoded `DELWAQTY30` coupon, auto-advance, CTA = copy code or `push('/market')`. Nothing is served from the backend. This is the primary directive violation the platform replaces.

---

## 4. Baseline Inventory (promotion-adjacent assets)

| Asset | Location | State | Promotion relevance |
|---|---|---|---|
| Merchant `offers` | `public.offers` | Live, read-only RLS | Candidate for benefit reference (§21); **not** reused as campaign container (§8) |
| `coupons` | `public.coupons` | Live, public SELECT when active | Benefit reference (§21) |
| `promo_codes` / `promo_redemptions` | `public.promo_codes` / `promo_redemptions` | Live, ride-scoped | Benefit reference (§21) |
| Home carousel | `home_page.dart` `_PromoCarousel` | Hardcoded | Replaced by campaign feed (§27, §37) |
| Notifications + deep links + push | `notifications`, push service, notification center | Live | Publish-time notifications, zero schema change (§31) |
| Regions / geo | `regions`, `geo_region_for_point`, `user_region_preferences` | Live (6,157) | Region targeting, server-side (§13, §26) |
| Admin hierarchy | `is_admin()`, `is_admin_for_region()`, `admin_region_assignments` | Live | Campaign CRUD authority (§13, §25) |
| Approval center (planned) | `approval_requests` (2.3 §19, migration 034) | Designed, not live | Campaign approval (§25) |
| Caching | `HiveCacheService` (15-min TTL), `TtlCache` (in-memory) | Live | Campaign feed caching (§27) |
| Analytics precedent | `get_admin_analytics`, `activity_logs` read (`admin_repository.dart:525`) | Live | Campaign analytics (§35) |
| Localization | `l10n` ARB (AR/EN) + `name_ar/name_en` columns | Live convention | Campaign content (§32) |
| Routing | go_router via `FeatureRegistry` (module-registered routes) | Live | CTA route allowlist (§23, §31) |

---

## 5. Constraint Map (non-negotiable)

1. Reuse the canonical Egypt `regions` model and the Phase 2.2 admin hierarchy — **no second region system, no second authorization system**.
2. RLS is authoritative; clients never decide which campaigns are visible; **unpublished campaigns are never exposed**.
3. **No hardcoded promotion content or targeting in Flutter** — the `_PromoCarousel` hardcode and `DELWAQTY30` are removed from code and become seed data.
4. **No arbitrary executable actions** — CTA is a controlled, validated schema (§23).
5. Media lives in Supabase Storage; **no binary payloads in DB rows**.
6. **No `offer_approval_requests`-style duplicate** — one generic `approval_requests` center (2.3 §19) handles campaign approvals.
7. **No unlimited realtime subscriptions** — campaign feed is fetch + cache, not realtime.
8. **No synchronous per-impression analytics write on the client path** — batched events, async aggregation.
9. **No auto-grant of free-delivery/financial benefits** — benefits are referential/config-driven and business-approved.
10. Do not modify migrations `030/031/032`; do not begin Phase 2.3 implementation; no migration ≥ 033 written now.

---

## 6. Objectives & Non-Goals

**Objectives**
- One platform object — the **campaign** — that covers: banners, offers, coupon-code promotions, announcements, scheduled pushes, region-targeted content, and full approval + audit + analytics.
- Replace every hardcoded promotion surface in the app (carousel first) with server-driven content.
- Full Arabic/English content, region targeting, approval chain, controlled CTAs, and cost-per-campaign analytics, all inside existing platform conventions.

**Non-goals (explicit)**
- No payments/checkout coupling (benefits are references; redemption remains in commerce/ride code).
- No personalization/AI audience scoring, no loyalty tiers (Phase 2.5+ extension points only).
- No push-send engine (FCM send path is Phase 2.4; the platform only inserts `notifications` rows + realtime).
- No self-serve merchant promotions UI in this phase (admin-governed; merchant CRUD is a later phase).
- No A/B testing engine, no SEO/canonical URLs, no CMS for rich-text pages (content = structured banner + localized text).

---

## 7. Requirement Decomposition

| Requirement | Delivered by |
|---|---|
| Create/manage promotion content (AR/EN) | `campaigns` + `campaign_banners` (§17–§18, §32) |
| Home/banner delivery | `get_active_campaigns` feed → home carousel (§27, §37) |
| Region targeting | `regions.region_id` + server-side hierarchy match (§20, §26) |
| Audience targeting (min viable) | structured target columns (§20) |
| Approval workflow | `approval_requests` + `campaign_reviews` (§19, §25) |
| Lifecycle/scheduling/expiry | state machine + server-enforced window (§24, §37) |
| CTA (no arbitrary actions) | controlled CTA schema + route allowlist (§23) |
| Analytics (impressions/clicks/conversions) | `campaign_events` → `campaign_metrics` → `get_campaign_analytics` (§22, §35) |
| Frequency/cooldown | `campaign_seen` + platform config (§36) |
| Benefits (no auto-grant) | referential benefit block (§21) |
| Admin UI | Campaign Manager under `/admin/campaigns` + Approval Center (§33) |
| Customer UI | campaign detail page + carousel (§37) |

---

## 8. Existing Asset Review — merchant `offers`

- **Schema (live):** `merchant_id`, `branch_id`, `category_id`, `title`, `description`, `discount_type`, `discount_value`, `minimum_order`, `maximum_discount`, `product_ids jsonb`, `is_active`, `is_automatic`, `starts_at`, `expires_at`. Commerce-shaped: one merchant's discount on their catalog.
- **RLS (live):** SELECT only, `USING true`; no write policies → **merchant offer CRUD is non-functional today**.
- **Client (repo):** `supabase_offer_data_source.dart` reads `offers` for merchant/restaurant pages; creates/updates/deletes would fail under RLS.
- **Verdict for promotion:** `offers` stays as the **commerce discount table**; it is a *benefit target*, not a campaign container. Campaigns with type `offer` **reference** `offers.id` (or an equivalent) rather than duplicating discount math. Rationale: mixing approval/lifecycle/region columns into `offers` contaminates a working commerce contract; the campaign layer is the governance wrapper, the offer is the discount payload.

---

## 9. Existing Asset Review — `coupons`, `promo_codes`, `promo_redemptions`

- `coupons`: code, discount_type/value, minimum_order, maximum_discount, usage_limit, used_count, merchant_id, is_active, expires_at. RLS: public SELECT when `is_active`.
- `promo_codes`: ride promos (min_fare, per_user_limit, valid_from/until) with `validate_promo` + `increment_coupon_usage`. RLS: public SELECT when active; `promo_redemptions` owner-rw.
- **Reuse decision:** campaign **benefit** block may reference any of these by id (`coupon_id` / `promo_code_id` / `offer_id`). Campaigns never mint codes or grant discounts themselves; redemption stays in commerce/ride code (unchanged). This satisfies directive §13 (no auto-grant) and avoids a second redemption engine.

---

## 10. Existing Asset Review — home promo carousel (the violation)

- `_PromoCarousel` (`home_page.dart:1012–1285`): 3 hardcoded slides — `30% OFF` + `DELWAQTY30` (hardcoded, `_copyCoupon` clipboard), "free delivery", "discount"; auto-advances 4s; slide 1 tap copies code, others `push('/market')`.
- `_HeroOrderCard` (lines 812–982): static "order directly" gradient hero — also hardcoded promotional copy.
- `HomePage.couponCode = 'DELWAQTY30'` constant (line 146).
- **Action:** these become campaign-driven. Seed campaigns reproduce the three current slides (plus the hero copy as a `home_hero` banner) so the UI is visually unchanged while data moves to the backend.

---

## 11. Existing Asset Review — notifications, deep links, push

- `notifications` columns include `type` (unconstrained → `promotion` needs **zero schema change**), `data jsonb`, `deep_link`, `idempotency_key`, `image_url`; already on `supabase_realtime`.
- Flutter `NotificationType` enum already has `promotion`.
- Deep-link resolution: `data.deep_link` wins; fallback by `entity_type` (`order→/market/orders/:id`, `merchant→/market/merchant/:id`, `service→/service-booking/:id`, `ride→/ride/:id`, default `/notifications`).
- `admin_broadcast_notification` (SECURITY DEFINER, `is_admin()` gate) inserts `notifications` rows for a target role/user with `data.deep_link` — the publish-notification precedent.
- **Reuse:** campaign publish/approval notifications insert into `notifications` with `type='promotion'`, `deep_link` to `/campaign/:id` (new route), `idempotency_key` from campaign_id+event to prevent dupes. Realtime delivery works today; FCM send remains Phase 2.4.

---

## 12. Existing Asset Review — storage buckets & policies

- `category-images` (public read; INSERT `WITH CHECK auth.role()='service_role'`) — **admin-only upload precedent**.
- `profiles` (public read; user-owned avatar upload) — the loose-policy precedent to avoid.
- **No banner bucket exists** → `campaign-media` bucket added in 039 with: public SELECT; INSERT/DELETE `WITH CHECK is_admin() OR auth.role()='service_role'` (mirrors category-images but opens to authenticated admins, still not to arbitrary users).
- Media files referenced by **storage path** in `campaign_banners.image_path`; no binary in DB rows (directive §7).

---

## 13. Existing Asset Review — regions, admin hierarchy, geo

- `regions` (6,157; type-typed hierarchy, `name_ar/name_en`, `is_active`) + `geo_region_for_point` (PostGIS, confidence HIGH/MEDIUM/LOW) + `user_region_preferences` → the **only** region model. Campaign region targeting references `campaigns.region_id`; national campaigns are `region_id IS NULL`.
- Admin authority: `is_admin()` (canonical `role IN ('admin','owner')`, ADR-049), `is_admin_for_region(region_id)` (owner implicit global; scope `self`/`descendants`), `admin_region_assignments`. **No new authz machinery** — campaign permissions ride `has_permission` (2.3 §034, migration 034) + region scope.
- Geo confidence is a *detection* signal (used for user→region resolution in the feed RPC), **not** a targeting dimension.

---

## 14. Existing Asset Review — caching & analytics precedents

- `HiveCacheService` (merchants/products/categories, 15-min TTL, metadata-timestamp invalidation) and `TtlCache` (in-memory LRU) → campaign feed caching pattern (§27).
- `get_admin_analytics(from,to)` returns count aggregates (orders/revenue/users/drivers/merchants) — the shape to mirror for `get_campaign_analytics` (admin + region-scoped).
- `activity_logs` read at `admin_repository.dart:525` (order by `timestamp` desc, `is_admin()` SELECT policy) — campaign actions append `activity_logs` via RPCs.
- **No analytics event pipeline exists** → the promotion domain introduces the first one (§22), deliberately minimal.

---

## 15. THE DECISION — `regional_offers`: keep, extend, or merge?

**Directive checkpoint answer: MERGE / REPLACE — do not build `regional_offers` as a separate table.**

### 15.1 What `regional_offers` was
Phase 2.3 §18 (migration 037, not yet implemented) proposed `regional_offers` + `offer_reviews`: a region-scoped, admin-proposed offer with lifecycle `draft → submitted → under_review → approved → rejected → published → expired → cancelled`, `proposed_by`, `reason`, approval via supervision chain, `offer_reviews` as the transition audit. The Phase 2.3 decision-lock (D7) approved it as distinct from merchant `offers`.

### 15.2 Why merge
1. **Conceptual superset.** A campaign with `type='offer'`, `region_id`, lifecycle, approval chain and `campaign_reviews` *is* the regional offer. Building `regional_offers` AND the campaign system means two parallel approve→publish→expire machines with near-identical audit tables — the exact "duplicate concept" the directive forbids.
2. **Duplicated machinery:** lifecycle state machine, approval wiring to `approval_requests`, transition-audit table, region-scope authorization, expiry engine, notifications. Every one of these would exist twice.
3. **Migration 037 is unimplemented** — nothing is lost by folding its scope into the campaign schema. This is the cheapest point in time to merge.
4. **Merchant `offers` remains untouched** — the merge only replaces the *admin-proposed* offer concept, which is precisely the campaign's `type='offer'`.

### 15.3 Consequences (owner must ratify)
- Phase 2.3 migration **037 (`regional_offers` + `offer_reviews`) is cancelled and absorbed** into promotion migration **039** as `campaigns` (type `offer`) + `campaign_reviews`.
- Phase 2.3's `approval_requests` request_type vocabulary gains `campaign_approve` / `campaign_publish` (superseding `offer_approve`/`offer_publish`).
- Phase 2.3 D7 / M-D7 wording updates from "regional_offers" to "campaigns"; member-rewards `campaign_id` FK points at `campaigns.id` instead.
- If the owner prefers **keeping** `regional_offers`, the promotion audit still proceeds (campaigns stay generic for banners/content) but the directive's duplicate-concept clause is violated and the extra table must be justified — **not recommended**.

### 15.4 Classification (per AGENTS.md §12.1)
`regional_offers` is **Dormant Infrastructure** (designed, never deployed). Rule: "Keep or archive cleanly, do NOT delete" — here the superior replacement exists (the campaign system, this audit), so replacement is permitted **provided the reason is recorded in `docs/DECISION_LOG.md`** (owner approval → ADR-059).

---

## 16. Target Architecture Overview

```
                         ┌────────────────────────────────────────────┐
                         │             Admin Platform                 │
                         │  Campaign Manager (/admin/campaigns)       │
                         │  Approval Center (/admin/approvals)        │
                         └──────┬──────────────────────────┬──────────┘
                                │ RPC (SECURITY DEFINER)    │ RPC
                        ┌───────▼───────┐           ┌───────▼────────┐
                        │   campaigns   │◄─────────►│ approval_requests │  (2.3 §19)
                        │ campaign_banners│  approve │  (generic)     │
                        │ campaign_reviews│  publish │                │
                        │ campaign_seen  │           └────────────────┘
                        │ campaign_metrics│
                        └───────┬───────┘
                                │  insert (service_role only, edge fn)
                        ┌───────▼───────┐
                        │ campaign_events│ ← batched client events (async)
                        └───────────────┘
        ┌─────────────────────────────────────────────────────────────┐
        │  Public surface:  get_active_campaigns() RPC (server-auth)  │
        │   → returns only status='active' + within window + region   │
        │   → CTA validated, images = storage URLs                    │
        │  Customer app: home carousel + /campaign/:id (TTL-cached)   │
        └─────────────────────────────────────────────────────────────┘
```
- **All client-facing reads go through `get_active_campaigns`** (SECURITY DEFINER, `search_path public,pg_temp`). The campaign tables themselves expose **no public SELECT** — RLS returns nothing to clients directly (defense in depth, and guarantees unpublished campaigns are invisible even if the RPC is bypassed).
- All writes go through RPCs; no table-level public INSERT/UPDATE/DELETE except owner-scoped `campaign_seen` upserts via the ingestion path.

---

## 17. Data Model — `campaigns`

```sql
CREATE TABLE public.campaigns (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text NOT NULL UNIQUE,             -- stable slug for seeds/deep links
  campaign_type  text NOT NULL CHECK (campaign_type IN
                   ('banner','offer','coupon_code','announcement')),
  name_ar        text NOT NULL,
  name_en        text NOT NULL,
  subtitle_ar    text, subtitle_en    text,
  description_ar text, description_en text,

  -- targeting (server-authoritative)
  region_id      uuid REFERENCES public.regions(id),   -- NULL = national
  target_roles   text[] DEFAULT NULL,                  -- NULL = all; validated against users.role CHECK set
  min_orders     integer, min_spend numeric(10,2),     -- audience filters (nullable)

  -- schedule (server-enforced window)
  starts_at      timestamptz NOT NULL,
  ends_at        timestamptz NOT NULL,
  published_at   timestamptz,

  -- governance
  proposed_by    uuid NOT NULL REFERENCES public.users(id),
  reason         text,
  status         text NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','submitted','under_review',
                                     'approved','rejected','scheduled',
                                     'active','paused','expired','cancelled')),
  -- benefit (config-driven, referential — NO auto-grant)
  benefit        jsonb NOT NULL DEFAULT '{"type":"none"}'::jsonb,
  -- frequency control override (NULL = platform default)
  frequency      jsonb,                                -- {"impression_limit_per_user":n,"cooldown_minutes":n}
  -- budget/limits (informational + analytics guard)
  budget         numeric(12,2), budget_currency text DEFAULT 'EGP',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX campaigns_status_starts ON public.campaigns (status, starts_at);
CREATE INDEX campaigns_region_status  ON public.campaigns (region_id, status);
```

Design notes:
- `status` set extends the 2.3 offer set with `scheduled`/`active`/`paused` — the campaign machine is a superset of the offer machine, reinforcing §15.
- `campaign_type` is CHECK-constrained (controllable set, precedent: `complaints.priority`). New types = migration, not ad-hoc rows.
- Bilingual content follows the `service_categories.name_ar/name_en` + `description_ar/en` convention (directive §8).
- `benefit` shapes are validated server-side in the lifecycle RPCs (whitelisted keys; free-delivery only when a config flag is set — §21).

---

## 18. Data Model — `campaign_banners` (content/media/CTA)

```sql
CREATE TABLE public.campaign_banners (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id  uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  placement    text NOT NULL CHECK (placement IN
                 ('home_carousel','home_hero','market_top','campaign_detail')),
  locale       text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar','en')),
  image_path   text NOT NULL,              -- storage object path in campaign-media bucket
  cta          jsonb,                      -- controlled CTA schema (§23)
  priority     integer NOT NULL DEFAULT 0, -- higher = earlier
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, placement, locale)
);
CREATE INDEX campaign_banners_feed ON public.campaign_banners
  (placement, is_active, priority DESC) WHERE is_active;
```
- **No binary in DB** — only storage paths (directive §7).
- One banner row per (campaign, placement, locale) → AR/EN images served by feed locale.
- `campaign_detail` placement = the campaign's detail-page hero (optional).
- CTA validation (§23) is enforced at publish/activate time and re-validated on every feed call (belt and braces).

---

## 19. Data Model — `campaign_reviews` (transition audit)

```sql
CREATE TABLE public.campaign_reviews (          -- replaces offer_reviews (2.3 §18)
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id   uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  reviewer_id   uuid NOT NULL REFERENCES public.users(id),
  action        text NOT NULL CHECK (action IN
                  ('submit','approve','reject','publish','pause','resume','cancel','expire')),
  reason        text,                            -- NOT NULL for approve/reject/publish
  previous_state text NOT NULL,
  new_state      text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX campaign_reviews_campaign ON public.campaign_reviews (campaign_id, created_at);
```
- Immutable audit trail: every transition recorded with actor + reason (directive: no silent approval).
- Retained 5-year policy (mirrors 2.3's audit retention).
- **Not** the approval *center* — decisions still flow through `approval_requests` (§25). `campaign_reviews` is the state ledger.

---

## 20. Data Model — targeting (region + audience)

- **Region:** `campaigns.region_id` (NULL = national). Server resolves the user's region from `user_region_preferences` then location (`geo_region_for_point`) then falls back to ancestor region match. A campaign is visible to a user if `campaign.region_id` is NULL **or** the user's region equals `region_id` **or** descends from it (uses the same CTE ancestor logic as `is_admin_for_region`, reversed).
- **Audience (min viable, structured):** `target_roles text[]` (validated against the `users.role` CHECK set), `min_orders`, `min_spend` (from `orders`/`rides` aggregation). Evaluated **in the feed RPC** only.
- **Extension point:** `campaigns` carries no free-form "audience JSON" in v1 — adding ad-hoc rules risks arbitrary logic (directive §6). Loyalty/behavioral targeting is a Phase 2.5+ capability appended as structured columns, not JSON.
- **No hardcoded governorates anywhere in Flutter** — the app only passes its resolved region id; the server decides.

---

## 21. Data Model — benefits (config-driven, no auto-grant)

`campaigns.benefit` — referential, validated JSON. Allowed shapes (whitelisted by `campaign_validate_benefit`):

| `type` | payload | Effect |
|---|---|---|
| `none` | `{}` | Informational campaign (default) |
| `coupon` | `{ "coupon_id": uuid }` | Reference to existing `coupons.id` (merchant/global coupon) |
| `promo_code` | `{ "promo_code_id": uuid }` | Reference to existing `promo_codes.id` (ride promo) |
| `offer` | `{ "offer_id": uuid }` | Reference to existing merchant `offers.id` |
| `code_copy` | `{ "code": "DELWAQTY30" }` | Display/copy-only code (no redemption engine) |

- **Free delivery / any financial benefit is never auto-granted** (directive §13). A `free_delivery` benefit type is **blocked** unless the owner sets `platform_settings.promotions.free_delivery_enabled = true` (added in 042) AND the specific campaign has an explicit approved `benefit` block — business-approved, never implicit.
- Redemption stays in commerce/ride code; campaigns only *link* benefits. No second redemption engine.

---

## 22. Data Model — analytics (`campaign_events` → `campaign_metrics`)

```sql
CREATE TABLE public.campaign_events (           -- append-only, service_role insert only
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES public.users(id),
  event_type  text NOT NULL CHECK (event_type IN ('impression','click')),
  locale      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX campaign_events_campaign_time ON public.campaign_events (campaign_id, created_at);

CREATE TABLE public.campaign_metrics (          -- async-aggregated, read model
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  metric_date date NOT NULL,
  impressions bigint NOT NULL DEFAULT 0,
  clicks      bigint NOT NULL DEFAULT 0,
  conversions bigint NOT NULL DEFAULT 0,
  spend       numeric(12,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (campaign_id, metric_date)
);

CREATE TABLE public.campaign_seen (             -- frequency control (denormalized, idempotent)
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  impressions bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, campaign_id)
);
```
- **Client never writes these tables.** Client buffers impressions/clicks locally and batch-POSTs to an edge function (Phase 2.4 infra, `track_campaign_event` contract) which inserts with `service_role`. No synchronous per-impression client write (directive §12).
- `campaign_seen` is upserted by the ingestion path (one row per user+campaign, not per impression) and read by the feed RPC for frequency/cooldown (§36).
- Daily aggregation RPC `aggregate_campaign_metrics` (edge timer + app-open best-effort, mirroring `run_member_engines`) rolls events → `campaign_metrics`; `get_campaign_analytics` (admin, region-scoped) mirrors `get_admin_analytics`.

---

## 23. CTA Schema (controlled — no arbitrary actions)

```json
{ "action_type": "internal_route" | "entity" | "external_url" | "copy_code",
  "route":       "/market/merchant/:id",   // internal_route only — MUST be on the allowlist
  "entity_type": "merchant|product|service|ride|offer|coupon|campaign",
  "entity_id":   "<uuid>",
  "url":         "https://...",             // external_url only, https-required
  "code":        "DELWAQTY30" }             // copy_code only
```
- `action_type` CHECK-constrained; keys whitelisted.
- **Route allowlist** lives in the DB (table `campaign_cta_routes` seeded with the `FeatureRegistry` route set: `/home`, `/market`, `/market/merchant/:id`, `/market/orders`, `/search`, `/direct-delivery`, `/campaign/:id`, …). `campaign_validate_cta` rejects any route/entity not allowlisted **at publish time** and again on every feed response.
- Flutter renders CTA from the schema only — it never executes arbitrary strings (directive §6).
- `external_url` is `https`-only and opened via `url_launcher` (no in-app webview execution).

---

## 24. Campaign Lifecycle (state machine)

```
draft ──submit──► submitted ──review──► under_review ──approve──► approved
   ▲                │  ▲                    │   │                       │
   └──cancel/reject─┴──┘  reject───────────┘   └──────► rejected       │
                                                                        │ publish (owner final)
   scheduled ◄─────────────── (starts_at in future)                     │
      │ time arrives (engine/RPC)                                        ▼
   active ──pause──► paused ◄──resume── active                     published
      │                                                               │ (starts_at ≤ now → active)
      └──ends_at < now / cancel──► expired / cancelled
```
- Transitions are RPC-only (`create_campaign`, `submit_campaign`, `review_campaign(action, reason)`, `publish_campaign`, `pause_campaign`, `resume_campaign`, `cancel_campaign`), each validating authority (`has_permission(CAMPAIGN_*)` + region scope) and writing `campaign_reviews` with a reason.
- **No self-publish** (mirrors 2.3 §18); `approved`→`published` requires an approver with superior authority.
- `expired` is a derived state enforced **server-side**: the feed RPC never returns `ends_at < now()` regardless of status; `run_promotion_engines` flips status to `expired` for bookkeeping (edge timer + app-open best-effort, no pg_cron — consistent with 2.3's C6).

---

## 25. Approval Flow — reuse generic `approval_requests`

- **Decision:** campaign approvals are rows in the generic **`approval_requests`** (2.3 §19, migration 034): `request_type IN ('campaign_approve','campaign_publish')`, `entity_id = campaigns.id`, `payload` = campaign snapshot, `required_approver` per supervision chain (NULL = owner). **No `campaign_approval_requests` / `offer_approval_requests` table.** This audit proves reuse is correct (§15.2), satisfying directive §9/§10.
- Pipeline: `submit_campaign` → creates `approval_requests(campaign_approve)` + status `submitted`; `review_campaign('approve')` → marks request approved + status `approved`; `publish_campaign` → creates `approval_requests(campaign_publish)`; decision → status `active`/`scheduled`, `published_at`, `approval_requests` closed.
- Every decision also writes `campaign_reviews` (state ledger) + `activity_logs` (via RPC, SECURITY DEFINER — never direct client INSERT) + `notifications` to requester (type `promotion`).
- **Approval Center (`/admin/approvals`, 2.3 §20) surfaces campaign items** with the same approve/reject (reason mandatory) UX — no scattered approval UI.
- Permissions use `has_permission(CAMPAIGN_APPROVE / CAMPAIGN_PUBLISH)` from 2.3 §034; owner implicit global; region scope via `is_admin_for_region`.

---

## 26. Region Targeting (server-side authoritative)

- `get_active_campaigns(p_region_id uuid)` — SECURITY DEFINER, `search_path public,pg_temp`, **STABLE**:
  1. `status = 'active'` (or `scheduled` whose window is live) AND `starts_at <= now()` AND `ends_at > now()`.
  2. Region match: `region_id IS NULL` OR user region is `region_id` or descendant (recursive CTE over `regions.parent_region_id`).
  3. Audience match: `target_roles` contains user role (or NULL), `min_orders`/`min_spend` satisfied.
  4. Frequency: exclude campaigns the user saw within cooldown (`campaign_seen` join).
  5. Strip non-public fields; **re-validate every CTA** against the allowlist; attach storage URLs.
- The RPC is `public`-EXECUTE only for read of *published* content; table-level RLS on `campaigns` returns nothing to clients (defense in depth — unpublished can never leak even via direct table access).
- No client-side region logic; no hardcoded governorates (directive §4/§5).

---

## 27. Feed Delivery (no realtime spam)

- Customer home calls `get_active_campaigns` → Riverpod `FutureProvider` → cached via `HiveCacheService` (15-min TTL, same pattern as merchants) + `TtlCache` for the current session. Pull-to-refresh + app-open invalidation. **No `supabase_realtime` subscription for campaigns** (directive §11).
- `campaign_banners` for `placement='home_carousel'` replace the hardcoded `_PromoCarousel` slides (locale-aware). `home_hero` placement carries the hero copy; `market_top` optional.
- Push-based announcements still flow through `notifications` (already realtime-published) — a campaign may opt into a one-time notification at publish time (type `promotion`, `deep_link=/campaign/:id`, `idempotency_key=campaign:<id>:publish`), not a realtime feed.

---

## 28. Media & Storage

- New bucket **`campaign-media`**: `public` SELECT; INSERT/DELETE `WITH CHECK (is_admin() OR auth.role()='service_role')`; UPDATE admin/service-role only. Mirrors `category-images` but adds the authenticated-admin path.
- File naming: `campaigns/<campaign_id>/<placement>_<locale>.<ext>`; validated MIME (png/jpeg/webp), size ≤ 5 MB.
- All image loads use Supabase Storage URLs (public bucket) or `imagePath` resolved in feed RPC; **no binary in DB rows** (directive §7).

---

## 29. RLS Design

Every new table follows the 030/016 lessons: `revoke` before `grant`, **no anon EXECUTE**, authenticated-only grants, `is_admin()` everywhere.

| Table | Policy |
|---|---|
| `campaigns` | SELECT: **none for clients** (only via `get_active_campaigns` RPC); INSERT/UPDATE/DELETE: none for clients (RPC-only) |
| `campaign_banners` | SELECT: none for clients; write via RPC/`service_role` |
| `campaign_reviews` | SELECT: `is_admin()`; write: none (RPC-only) |
| `campaign_events` | INSERT: `service_role` only (edge function); SELECT: none for clients |
| `campaign_metrics` | SELECT: `is_admin()`; write: none (aggregation RPC, service_role) |
| `campaign_seen` | SELECT: `user_id = auth.uid()` (own only); upsert via edge function `service_role` |
| `campaign_cta_routes` | SELECT: public (read-only reference data); write: `is_admin()` |
| `approval_requests` (2.3) | unchanged from 2.3 §21 (`is_admin()` ALL) |

Notes: `activity_logs` INSERT stays `service_role`-only after 033; campaign RPCs append via SECURITY DEFINER — never direct client writes (avoids reproducing the live §3.3.2 hole).

---

## 30. RPC Design (016 pattern)

| RPC | Authority | Notes |
|---|---|---|
| `create_campaign` | `has_permission(CAMPAIGN_CREATE)` + region scope | validates benefit shape, CTA (if provided), dates, locale completeness |
| `update_campaign` | `CAMPAIGN_EDIT` + scope, draft/scheduled only | immutable after `published` except pause |
| `submit_campaign` | creator | → `submitted`, creates `approval_requests(campaign_approve)` |
| `review_campaign(action, reason)` | `CAMPAIGN_APPROVE` + supervision chain | approve/reject; reason NOT NULL; writes `campaign_reviews` |
| `publish_campaign` | `CAMPAIGN_PUBLISH`, owner/upper chain | → `scheduled`/`active`; `approval_requests(campaign_publish)`; optional notification |
| `pause_campaign` / `resume_campaign` | `CAMPAIGN_EDIT` + scope | active↔paused |
| `cancel_campaign` | `CAMPAIGN_EDIT` + scope | any non-terminal → cancelled, reason required |
| `get_active_campaigns(p_region_id)` | public, read-only, **STABLE** | §26 — the only public surface |
| `track_campaign_event` (edge fn) | service_role | batch ingestion; upserts `campaign_seen` |
| `aggregate_campaign_metrics` | service_role/engine | daily rollup events→metrics |
| `get_campaign_analytics(from,to)` | `has_permission(CAMPAIGN_ANALYTICS)` + scope | mirrors `get_admin_analytics` |
| `campaign_validate_cta` | internal | allowlist enforcement |

All: `SECURITY DEFINER`, `SET search_path TO public,pg_temp`, **no `SECURITY INVOKER`**, anon `REVOKE EXECUTE`, explicit grants (016 lesson).

---

## 31. Notifications & Deep-Links Integration

- Publish/approval/rejection events insert into `notifications` (type `promotion`), `data.deep_link = '/campaign/:id'`, `idempotency_key = 'campaign:<id>:<event>'`, `image_url = banner image` (column exists). Realtime delivery works unchanged; FCM send is Phase 2.4.
- New route `/campaign/:id` registered via the promotions module in `FeatureRegistry` (pattern: `admin_module.dart`).
- Customer CTA to campaign → `/campaign/:id` detail page (campaign content + `campaign_detail` banner + benefit copy-code/CTA).
- `admin_broadcast_notification` remains for ad-hoc admin pushes; campaign notifications use the campaign RPC path (so they carry correct idempotency and audit).

---

## 32. Localization (AR/EN)

- Content columns are bilingual by design (§17), following `service_categories.name_ar/name_en` + `description_ar/en` precedent.
- `campaign_banners.locale` per locale; feed RPC returns the row for the requesting locale (`Accept-Language` / app locale) with AR fallback.
- Dart side adds ~12 l10n keys (campaign list, detail, "terms", "copy code", "ends in", admin campaign manager labels) via the existing ARB pipeline (`app_ar.arb` / `app_en.arb`).
- No hardcoded campaign text in Dart — the seed campaign reproduces today's slides as data (§10).

---

## 33. Admin Platform Integration

- **Campaign Manager** — new admin subroute `/admin/campaigns` (pattern: `admin_module.dart` sub-routes): list (status filter), create/edit wizard (AR/EN content, type, placement+locale banners with `campaign-media` upload, targeting, schedule, benefit, CTA with allowlist picker), actions (submit/review/publish/pause/cancel with reason), read-only timeline from `campaign_reviews`.
- **Approval Center** `/admin/approvals` (2.3 §20) shows campaign requests via `approval_requests` — no separate approval UI.
- **Analytics tab** per campaign: `get_campaign_analytics` (impressions/clicks/CTR/conversions/spend by day).
- Access gated by the existing `admin_access.dart` admin gate + `is_admin_for_region` scope; `0 admins` today → all campaign work is owner-level until Phase 2.3 admin delegation ships (034).

---

## 34. Flutter Home Integration (replace the hardcode)

- Delete hardcoded `_PromoCarousel` slides and `DELWAQTY30` constant; replace `_PromoCarousel` with a `campaignsProvider`-fed widget (placement `home_carousel`), keeping the existing visual language (gradient cards, auto-advance, dots).
- `_HeroOrderCard` text becomes config-driven content of the `home_hero` banner (visual stays).
- CTA taps route through a `CampaignCtaHandler` that resolves the validated schema (`internal_route`/`entity`/`copy_code`/`external_url`) — clipboard for `copy_code` (replacing `_copyCoupon`).
- New `/campaign/:id` detail page; pull-to-refresh invalidates the campaign provider; Hive TTL cache (15 min) as offline fallback.

---

## 35. Analytics & Reporting (async, minimal)

- Client: buffer impressions/clicks per session → batch POST to `track_campaign_event` edge function (Phase 2.4 infra) → `campaign_events` (service_role). **No synchronous per-event DB write from the app** (directive §12).
- Aggregation: daily `aggregate_campaign_metrics` (edge timer + app-open best-effort) → `campaign_metrics`; `get_campaign_analytics` for admin UI (mirrors `get_admin_analytics` counts + CTR/spend).
- Events table row-growth handled by the 2.3 retention engine (`retention_policies`, 2.3 §038) — raw events retained ≤ 90 days, metrics retained 5 years.

---

## 36. Frequency Control & Limits

- Platform defaults: `platform_settings.promotions = {"impression_limit_per_user":1, "cooldown_minutes":0}` (added in 042; single-row config).
- Per-campaign override: `campaigns.frequency` (validated keys only).
- Enforcement in `get_active_campaigns` via `campaign_seen` (upserted by ingestion): a campaign whose impression count ≥ limit and last_seen within cooldown is excluded.
- **Extension-ready:** v1 = per-campaign impression cap + cooldown; per-placement and per-user global caps are future columns, not JSON logic.

---

## 37. Scheduling & Expiry (server-enforced, no cron)

- `starts_at`/`ends_at` windows enforced in **every** `get_active_campaigns` call (status `active`/`scheduled` is not sufficient — window is the truth). A published campaign with `ends_at < now()` is invisible instantly, then `run_promotion_engines` flips status to `expired` (idempotent; edge timer Phase 2.4 + app-open best-effort — same contract as 2.3's `run_member_engines`, no `pg_cron`).
- `publish_campaign` with `starts_at > now()` → `scheduled`; feed activates it only when the window opens (no timer needed).
- No hardcoded dates in Dart; the home carousel honors server windows automatically.

---

## 38. Migration Plan (exact numbers — no collisions)

| Migration | Content |
|---|---|
| **039** `promotion_campaign_schema` | `campaigns`, `campaign_banners`, `campaign_reviews`, `campaign_seen`, `campaign_cta_routes` + `campaign-media` bucket + storage policies + RLS (revoke-before-grant) |
| **040** `promotion_workflow_and_feed` | lifecycle RPCs (create/submit/review/publish/pause/resume/cancel), `campaign_validate_cta`/`campaign_validate_benefit`, `get_active_campaigns`, `approval_requests` wiring (request_type vocabulary `campaign_*`), publish notifications |
| **041** `promotion_analytics` | `campaign_events`, `campaign_metrics`, `track_campaign_event` (service_role), `aggregate_campaign_metrics`, `get_campaign_analytics` |
| **042** `promotion_benefits_and_config` | `platform_settings.promotions` block (frequency defaults, `free_delivery_enabled` flag), benefit seed data (reproduces today's 3 carousel slides + hero copy), notification templates |

Numbering rationale:
- Phase 2.3 owns **033–038** (pending owner approval; 033 written first). Phase 2.4=034 and 2.5=035 in ROADMAP **already collide** with 2.3's map — a pre-existing issue the owner must resolve independently of this audit.
- Promotion takes **039–042**, strictly after every existing/mapped number, so it can be implemented and merged **in any order** with 2.3/2.4/2.5 without collision.
- **2.3 migration 037 (`regional_offers`/`offer_reviews`) is cancelled/absorbed** by 039 (§15) — requires owner ratification.
- No migration in this audit is written before its gate's approval (architecture-first, evidence-first).

---

## 39. Risk Register

| # | Risk | Sev | Mitigation |
|---|---|---|---|
| R1 | Two "offer lifecycle" machines if `regional_offers` kept | High | §15 merge; owner decision O1 |
| R2 | Unpublished campaign leak via direct table access | High | No client SELECT on `campaigns`; RPC-only + revalidation (§26, §29) |
| R3 | Hardcoded promo content regressions (carousel) | Med | Single feed source; seeds reproduce current UI; analyzer keeps Dart clean of campaign strings |
| R4 | CTA injection / arbitrary route navigation | High | Allowlist in DB + publish-time + feed-time validation (§23) |
| R5 | Event pipeline misuse (impression fraud) | Med | Service-role-only ingestion; server-side campaign-window validation in `track_campaign_event`; rate caps via `campaign_seen` |
| R6 | Analytics bloat from per-impression writes | Med | Batched client events + daily aggregation; 90-day raw retention (§35) |
| R7 | Free-delivery benefit misconfiguration | High | Blocked unless `platform_settings.promotions.free_delivery_enabled=true` AND explicit approved benefit (§21) |
| R8 | Migration numbering collision (2.3/2.4/2.5) | Med | Promotion at 039+; owner resolves the pre-existing 2.3-vs-2.4/2.5 overlap (§38) |
| R9 | No scheduler → stale statuses | Low | Window is the truth in the feed; status flip is cosmetic via engine (§37) |
| R10 | Banner storage abuse (loose INSERT like `profiles`) | Med | `WITH CHECK is_admin() OR service_role` on `campaign-media` (§28) |
| R11 | Admin platform complexity growth | Med | Campaign Manager + Approval Center only; no scattered approval UI (§33) |

---

## 40. Test Strategy

- **RLS matrix:** client SELECT on `campaigns`/`campaign_banners` returns zero rows in every role; anon cannot EXECUTE any campaign RPC; unpublished/expired never visible via `get_active_campaigns`.
- **Targeting:** national vs governorate vs city vs village; user in descendant region sees ancestor campaign; wrong region does not; `target_roles`/`min_orders`/`min_spend` filters.
- **Lifecycle:** full happy path draft→…→active; each transition authority matrix (self-publish fails, cross-region fails, cross-branch fails, owner succeeds); reason-mandatory on approve/reject/publish; `campaign_reviews` continuity.
- **CTA:** allowlist pass/fail; malformed schema rejected at publish and stripped at feed; `external_url` https-only.
- **Frequency:** impression cap + cooldown respected via `campaign_seen`; reset after cooldown.
- **Analytics:** event batch ingestion; idempotent re-run; aggregation correctness; `get_campaign_analytics` region-scoped; 90-day raw retention.
- **Benefits:** referential integrity (coupon/promo/offer ids must exist); `free_delivery` blocked without flag; redemption unchanged (commerce/ride tests untouched).
- **Migration ordering:** 039–042 apply cleanly over 033 (2.3) when merged either order; no object-name collisions.

---

## M — Final Verdict Letter

**Verdict: 🟡 REQUIRES OWNER DECISION.** The architecture is complete and self-consistent, but per the gate rule approval must not be invented — the 6 decisions below are binding.

### A. Final recommendation
Build the **campaign platform** (039–042) as the single promotion/content surface: one `campaigns` object covering banners, offers, coupon-code promos and announcements, with bilingual content, server-authoritative region/audience targeting, a supervised approval chain through the generic `approval_requests`, an immutable `campaign_reviews` audit ledger, controlled CTAs, storage-backed media, batched event analytics, and config-driven referential benefits. Replace the hardcoded home carousel (incl. `DELWAQTY30`) with the `get_active_campaigns` feed. No code, no migration, no commit/push produced in this gate.

### B. regional_offers verdict (directive checkpoint)
**MERGE/REPLACE.** `regional_offers` + `offer_reviews` (2.3 §18, migration 037) are absorbed into `campaigns` (type `offer`) + `campaign_reviews` (039). Classification: Dormant Infrastructure replaced by a superior existing design — reason to be recorded in `docs/DECISION_LOG.md` (ADR-059) on approval. Merchant `offers` is untouched and becomes a benefit reference. Building both is a duplicate concept (directive §1/§9).

### C. New tables
`campaigns` · `campaign_banners` · `campaign_reviews` · `campaign_seen` · `campaign_cta_routes` · `campaign_events` · `campaign_metrics`. Bucket: `campaign-media`. (Nothing pre-existing is deleted; 2.3's 037 is simply never built.)

### D. Permissions
`has_permission(CAMPAIGN_*)` (2.3 §034) over the supervision tree + `is_admin_for_region` scope; owner implicit global. Actions: CREATE/EDIT/APPROVE/PUBLISH/ANALYTICS. No second authorization system.

### E. RLS
Campaign tables: no client SELECT except owner-scoped `campaign_seen`; all reads via `get_active_campaigns` (SECURITY DEFINER); writes RPC/service_role only; `campaign_reviews`/`campaign_metrics` admin-only; revoke-before-grant; anon EXECUTE revoked.

### F. Region targeting
`campaigns.region_id` over the canonical `regions` tree (NULL = national), user region from preferences → `geo_region_for_point` fallback, ancestor-match in feed RPC; structured audience columns; no hardcoded governorates in Flutter.

### G. Approval flow
Generic `approval_requests` (`campaign_approve`/`campaign_publish`), supervision-chain routing, reason mandatory, `campaign_reviews` state ledger, Approval Center `/admin/approvals`, notifications to requester. No `campaign_approval_requests`/`offer_approval_requests` table.

### H. Lifecycle
draft → submitted → under_review → approved → rejected | scheduled → active ⇄ paused → expired | cancelled; RPC-only transitions; no self-publish; window is the truth; expiry via engine (no pg_cron).

### I. Phases / implementation order
2-P-A (039 schema+storage+RLS) → 2-P-B (040 workflow+feed) → 2-P-C (041 analytics) → 2-P-D (042 benefits/config/seeds) → Flutter (carousel replacement, campaign detail, Campaign Manager UI) → pre-commit gate (pub get / analyze / test). Each sub-phase independently testable.

### J. Migration numbers
**039–042** as §38; 2.3's 037 cancelled/absorbed; pre-existing 2.3(034–038) vs 2.4(034)/2.5(035) overlap flagged for owner resolution.

### K. Complexity
**Phase: High.** New domain (5+ tables, 12 RPCs, feed + analytics pipelines) but deliberately minimal: no realtime feed, no per-impression sync writes, no free-form audience JSON, no second redemption engine. Fits existing patterns (016/030/032, `get_admin_analytics`, Hive caching, ARB l10n).

### L. Risks
R1–R11 (§39); top: dual-lifecycle duplication (R1), unpublished leak (R2), CTA injection (R4), free-delivery misconfig (R7). All mitigated by design; none blocking.

### M. Owner decisions required (before implementation)
1. **O1 — ratify the `regional_offers` merge** (B) and the cancellation of 2.3 migration 037, recorded as ADR-059.
2. **O2 — approve the 4-migration plan 039–042** and the placement of promotion after 2.3's range.
3. **O3 — approve reusing generic `approval_requests`** for campaign approvals (no campaign-specific approval table) + extending its vocabulary with `campaign_*`.
4. **O4 — approve the frequency defaults** in `platform_settings.promotions` (`impression_limit_per_user`=1, cooldown=0) and the block on free-delivery benefits unless the explicit flag is set (directive §13).
5. **O5 — approve media bucket `campaign-media`** with admin/service-role-only upload (public read), 5 MB / png-jpeg-webp.
6. **O6 — confirm the customer-visible content seeds** (today's 3 carousel slides + hero copy) so the UI is visually unchanged on day one.

On confirmation of O1–O6, this audit flips to 🟢 READY FOR IMPLEMENTATION and migration 039 may be written. **No code, no migration, no commit/push produced in this gate.**
