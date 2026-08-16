# PHASE 2 — PROMOTION PLATFORM — MIGRATION 039 GATE REPORT

> **Session:** 50 · 2026-08-16 · **Baseline:** HEAD `b1081d2` (sprint 76) · **Project:** `bttnlkmwhorjamzemwda`
> **Migration:** `supabase/migrations/039_promotion_campaign_schema.sql` (promotion core schema)
> **Verdict:** 🟢 **PASS — ready for owner approval. STOP. No migration 040, no Flutter changes until approved.**
> **Authority:** owner O1–O6 (approved) · ADR-059 · `PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md` §13

---

## 1. Scope of 039 (as contracted)

Core campaign domain ONLY — schema + RLS + validators:

| Object | Purpose |
|---|---|
| `campaigns` | Single promotion/content container (`regional_offers` MERGE target, O1); 12 types; priority lane (normal/important/critical); lifecycle status superset; bilingual; referential `benefit`; `frequency` config; audience (`target_roles`/min_orders/min_spend) |
| `campaign_banners` | placement+locale banner refs (storage paths, no binary); controlled CTA |
| `campaign_reviews` | immutable transition audit ledger |
| `campaign_cta_routes` | CTA route allowlist (reference data, seeded from FeatureRegistry) |
| `campaign_seen` | frequency control (impressions per user/campaign) |
| Validators | `campaign_validate_priority` · `campaign_validate_cta` · `campaign_validate_benefit` · `campaign_validate_target_roles` (SECURITY DEFINER, `SET search_path = public, pg_temp`) |
| Trigger | `campaigns_guard_status_change` (whitelist lifecycle transitions; emergency types forced critical via CHECK) |

**Deliberately NOT in 039:** lifecycle/approval RPCs (need `approval_requests` → 040), feed RPC
(`get_active_campaigns` → 041), analytics (042), `campaign-media` bucket (040), config seeds (042),
realtime publication, auto-published content (O6 — 0 campaign rows).

---

## 2. Apply + Idempotency

| Check | Result |
|---|---|
| Apply via Management API (`POST /database/query`) | ✅ HTTP 201, `[]` |
| Idempotent re-run | ✅ HTTP 201, `[]` — no errors, no duplicates |

---

## 3. Schema Presence

| Check | Result |
|---|---|
| 5 tables live | ✅ `campaigns` `campaign_banners` `campaign_reviews` `campaign_cta_routes` `campaign_seen` |
| Indexes (13) | ✅ 5 PK + `campaigns_code_key` UNIQUE + `campaign_banners_unique` + 6 secondary (`idx_campaigns_status_priority`, `idx_campaigns_schedule`, `idx_campaigns_type`, `idx_campaign_banners_placement_active`, `idx_campaign_reviews_campaign`, `idx_campaign_seen_last_seen`) |
| `campaigns` constraints | ✅ type CHECK (12) · status CHECK (10) · priority CHECK (3) · `campaigns_emergency_critical` (emergency ⇒ critical) · `campaigns_window_order` (ends_at > starts_at) · code UNIQUE · 3 FK → users |
| Functions | ✅ 4 validators (SECURITY DEFINER, `prosecdef=true`) + 1 trigger fn |
| `campaign_cta_routes` seed | ✅ **39 routes** (idempotent, additive) |
| Row counts | ✅ campaigns 0 · banners 0 · reviews 0 · seen 0 · **cta_routes 39** (O6: no auto-published seeds) |

---

## 4. RLS + Policies

| Table | RLS | Policies |
|---|---|---|
| `campaigns` | ✅ ON | `campaigns admin select` — SELECT `USING (public.is_admin())` (**only** policy; no write policies — RPC-only write path) |
| `campaign_banners` | ✅ ON | `campaign_banners admin select` — SELECT `is_admin()` |
| `campaign_reviews` | ✅ ON | `campaign_reviews admin select` — SELECT `is_admin()` |
| `campaign_cta_routes` | ✅ ON | `campaign_cta_routes public select` (USING true) + `campaign_cta_routes admin manage` (ALL, `is_admin()`/`WITH CHECK is_admin()`) |
| `campaign_seen` | ✅ ON | **none** — no client access at all (feed/ingestion RPC only) |

Defense in depth: **no client SELECT on campaign content tables as a feature** — customers read ONLY via
`get_active_campaigns` (041). Direct table access by non-admins yields 0 rows (RLS) or 42501 (no grant).

---

## 5. ACL Audit (grants per role)

| Table | postgres | anon | authenticated | service_role |
|---|---|---|---|---|
| `campaigns` | ALL | **none** | SELECT | ALL |
| `campaign_banners` | ALL | **none** | SELECT | ALL |
| `campaign_reviews` | ALL | **none** | SELECT | ALL |
| `campaign_cta_routes` | ALL | SELECT | SELECT | ALL |
| `campaign_seen` | ALL | **none** | **none** | ALL |

Function privileges (`has_function_privilege`): **anon EXECUTE = false** on all 4 validators;
authenticated + service_role EXECUTE = true; all `SET search_path = public, pg_temp` verified via
`proconfig`. Realtime publication: **not subscribed** (fetch + TTL cache model).

---

## 6. Security Attack Matrix (functional, live)

All probes executed against the live project (Management API `SET ROLE` + JWT-claim simulation; REST
anon-key probes with current project keys).

| # | Probe | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | anon SELECT `campaigns` | 42501 | 42501 "permission denied for table campaigns" | ✅ |
| 2 | anon SELECT `campaign_cta_routes` | 200 + rows | 200, routes returned | ✅ (public allowlist) |
| 3 | anon RPC `campaign_validate_priority` | 42501 | 42501 "permission denied for function" | ✅ |
| 4 | customer (non-admin) SELECT `campaigns` | 0 rows (RLS) | 0 rows (`is_admin()`=false) | ✅ |
| 5 | owner SELECT `campaigns` | row visible | 1 row visible | ✅ |
| 6 | customer INSERT `campaigns` | 42501 | 42501 | ✅ |
| 7 | customer SELECT `campaign_seen` | 42501 | 42501 | ✅ |
| 8 | CTA internal route allowlist (`/market`) | true | true | ✅ |
| 9 | CTA unknown route (`/evil`) | false | false | ✅ |
| 10 | CTA `javascript:alert(1)` | false | false | ✅ |
| 11 | CTA `https://delwaqty.app` | true | true | ✅ |
| 12 | CTA copy_code `DELWAQTY30` | true | true | ✅ |
| 13 | benefit `free_delivery` (config absent) | false | false | ✅ (O4 — not enabled until 042 flag) |
| 14 | benefit `coupon` with non-existent UUID | false | false | ✅ |
| 15 | priority emergency+critical | true | true | ✅ |
| 16 | priority emergency+normal | false | false | ✅ |
| 17 | target_roles `[customer,driver]` | true | true | ✅ |
| 18 | target_roles `[hacker]` | false | false | ✅ |
| 19 | trigger draft→published direct | blocked | P0001 "Invalid campaign status transition draft -> published" | ✅ |
| 20 | trigger draft→pending_review | allowed | allowed | ✅ |
| 21 | CHECK emergency_notice + priority=normal | blocked | 23514 `campaigns_emergency_critical` | ✅ |

All fixtures cleaned after probes (campaign tables back to 0 rows).

---

## 7. Non-Destruction / Existing Data

| Check | Before | After | Result |
|---|---|---|---|
| `regions` | 6,157 | 6,157 | ✅ untouched |
| `users` | 5 | 5 | ✅ untouched |
| `coupons` / `offers` / `promo_codes` | 0 / 0 / 1 | 0 / 0 / 1 | ✅ untouched |
| Storage buckets | 5 | 5 (no `campaign-media`) | ✅ bucket creation correctly deferred to 040 |
| `platform_settings` | single row | unchanged | ✅ untouched |

---

## 8. Analyzer / Scan / Diff

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **0 errors** (546 issues = pre-existing baseline only; 0 in promotion files — SQL-only change, no Dart touched) |
| Secret scan (migration + ADR-059 + plan + SESSION_STATUS + ROADMAP) | ✅ clean — 0 hits in migration; doc hits are prose ("OpenAI"/"Supabase" library names in prior ADRs) |
| `git diff --check` | ⚠️ pre-existing CRLF artifact in `DECISION_LOG.md` (documented repo file format since Session 47); new files LF-clean with 0 trailing whitespace |
| Git scope | Docs + `supabase/migrations/039_promotion_campaign_schema.sql` only; zero production Dart/Flutter changes |

---

## 9. Verdict

**🟢 PASS.** Migration 039 is live on `bttnlkmwhorjamzemwda`, idempotent, non-destructive, and hardened
(RLS-only reads, no client SELECT on content tables, anon EXECUTE revoked, SECURITY DEFINER + search_path,
server-enforced lifecycle). Owner decisions O1 (regional_offers merged into `campaigns`), O4 (frequency/
free-delivery config), O6 (no auto-published seeds) are all enforced at the schema level.

**STOPPING HERE.** No migration 040, no lifecycle/approval RPCs, no feed RPC, no `campaign-media` bucket,
no Flutter changes until owner reviews and approves this gate.

**Next on approval:** migration 040 — `promotion_targeting_media_approval` (targets + `approval_requests` +
lifecycle RPCs + `campaign-media` bucket) per `PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md` §3/§5/§6/§7.
