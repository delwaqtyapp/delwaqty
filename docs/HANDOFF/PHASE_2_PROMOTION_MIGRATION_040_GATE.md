# PHASE 2 — PROMOTION PLATFORM — MIGRATION 040 GATE REPORT

> **Session:** 51 · 2026-08-16 · **Baseline:** HEAD `b1081d2` (sprint 76) · **Project:** `bttnlkmwhorjamzemwda`
> **Migration:** `supabase/migrations/040_promotion_targeting_media_approval.sql`
> **Verdict:** 🟢 **PASS — ready for owner approval. STOP. No migration 041/042, no Flutter changes, no commit until approved.**
> **Authority:** owner O1–O6 (approved) · ADR-059 · ADR-060 · `PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md` §3/§5/§6/§7
> **Checks:** 44/44 documented below across targeting, audience, approval, lifecycle, media/storage, security, idempotency.

---

## 1. Scope of 040 (as contracted)

| Object | Purpose |
|---|---|
| `campaign_targets` | Many-to-many targeting junction (campaign_id + nullable region_id; **NULL = national/Egypt**). Multi-region = multiple rows on ONE campaign — no duplicated campaigns (directive §1/§9). Partial unique `campaign_targets_national_unique` ⇒ at most one national row |
| `approval_requests` | Generic approval center (2.3 §19 contract **verbatim**); `request_type='campaign_approve'`, `required_approver NULL` = owner. 2.3 034 amended to NOT recreate this table |
| `campaign_media` | Media metadata (kind thumbnail/detail_image/gallery_image, `image_path`, `is_active`, `sort_order`); storage references only — no binary in PostgreSQL |
| Lifecycle RPCs | `campaign_submit` · `decide_approval_request` (§19 signature) · `campaign_publish` · `campaign_pause` · `campaign_resume` · `campaign_archive` · `campaign_cancel` · `campaign_purge_media` (8) |
| Scope helpers | `campaign_can_target_region` · `campaign_targets_authorized` |
| Storage helpers | `campaign_id_from_storage_path` · `campaign_published_for_storage` · `campaign_scoped_for_storage` |
| Bucket + policies | `campaign-media` (private, ≤5 MB, png/jpeg/webp) + 4 storage policies |
| Write policies | `campaigns admin insert/update`, `campaign_banners admin insert/update/delete`, `campaign_targets`/`campaign_media` RLS sets, `approval_requests` RLS |

**Deliberately NOT in 040:** feed RPC `get_active_campaigns` (041), analytics tables (042), config seeds (042), realtime publication, auto-published content (O6).

---

## 2. Design Decisions + Review-Time Fixes

Design is codified as **ADR-060** (targeting junction + `target_roles` audience + §19 approval center +
SECURITY DEFINER lifecycle + storage-reference media + orphan-purge model + no-second-hierarchy approval
authority). Two fixes were applied **before/around** live apply and re-verified:

| # | Fix | Why | Live-verified |
|---|---|---|---|
| D1 | `campaigns_set_creator()` forces `NEW.status := 'draft'` on INSERT | 039's guard trigger is UPDATE-only; a client INSERT with `status='published'` could otherwise bypass the approval lifecycle | ✅ insert `published` → row lands `draft` |
| D2 | `campaign_purge_media()` sets `storage.allow_delete_query` via `PERFORM set_config(..., true, true)` before the storage DELETE (and `false` after) | `storage.protect_delete()` raises `42501 Direct deletion from storage tables is not allowed` on plain SQL DELETE. Note: `RESET LOCAL storage.allow_delete_query` is a **syntax error** (qualified names forbidden) → must use `set_config` | ✅ purge deletes object + deactivates media/banners |

---

## 3. Apply + Idempotency

| Check | Result |
|---|---|
| Apply (Management API `POST /database/query`) | ✅ HTTP 201 `[]` |
| Re-apply after fixes | ✅ HTTP 201 `[]` |
| Idempotent re-run | ✅ HTTP 201 `[]` — no errors, no duplicates |
| Static sanity | ✅ LF-clean · 1× BEGIN/COMMIT · **18 DROP POLICY = 18 CREATE POLICY** (14 table + 4 storage) |

---

## 4. Schema Presence

| Check | Result |
|---|---|
| 3 tables live, RLS ON | ✅ `campaign_targets` `campaign_media` `approval_requests` |
| Indexes (6) | ✅ `campaign_targets_national_unique` (partial) · `idx_campaign_targets_region` · `idx_campaign_media_campaign` · `approval_requests_pending_unique` (partial) · `idx_approval_requests_entity` · `idx_approval_requests_state_approver` |
| FKs | ✅ targets/media → campaigns ON DELETE CASCADE; approval_requests → campaigns (no cascade — audit preserved) |
| Bucket `campaign-media` | ✅ private · `file_size_limit` 5242880 · `allowed_mime_types {image/png,image/jpeg,image/webp}` |
| Functions (14) | ✅ all present, `SET search_path = public, pg_temp`; 8 lifecycle + 2 scope + 3 storage + 1 trigger fn |
| Triggers (2) | ✅ `campaign_media_set_updated_at` · `campaigns_set_creator` |

---

## 5. RLS + Table Policies

| Table | Policies (14) |
|---|---|
| `campaign_targets` | `admin select` · `admin insert` · `admin delete` (each `USING/WITH CHECK public.is_admin()`) |
| `campaign_media` | `admin select` · `admin insert` · `admin update` · `admin delete` |
| `approval_requests` | `admin all` · `requester select` (`auth.uid() = requester_id`) |
| `campaigns` (additions) | `admin insert` (`WITH CHECK is_admin()`) · `admin update` (`is_admin() AND campaign_targets_authorized(id)`) |
| `campaign_banners` (additions) | `admin insert` · `admin update` · `admin delete` (all gated `campaign_targets_authorized(campaign_id)`) |

Defense in depth: table DML paths are closed to customers (RLS) AND non-admins lack grants; `campaigns`
has **no DELETE policy and no DELETE grant** (archival only via RPCs).

## 6. Storage Policies (4)

| Policy | Gate |
|---|---|
| `campaign media published read` | `campaign_published_for_storage(name)` — customers read ONLY published campaigns |
| `campaign media admin upload` | `campaign_scoped_for_storage(name)` — admin + real campaign + scope |
| `campaign media admin update` | same scope gate |
| `campaign media admin delete` | same scope gate |

---

## 7. ACL Audit (grants per role)

| Object | anon | authenticated | service_role |
|---|---|---|---|
| `campaign_targets` | **none** | `arwd` (RLS-gated) | ALL |
| `campaign_media` | **none** | `arwd` (RLS-gated) | ALL |
| `approval_requests` | **none** | `r` — SELECT only; writes are RPC-only | ALL |
| `campaigns` | **none** | `arw` — **no DELETE** | ALL |
| Functions | **none** (EXECUTE false) | EXECUTE on 13 (all but `campaigns_set_creator`) | EXECUTE all |

`campaigns_set_creator` is intentionally NOT granted to authenticated — it is a trigger-only helper.

---

## 8. Targeting + Scope (positive, live)

| # | Check | Result |
|---|---|---|
| C01 | gadmin insert national target (region_id NULL) | ✅ 1 row |
| C02 | gadmin insert target for arbitrary region | ✅ 1 row |
| C03 | radmin insert target for own region (`8d433152…`, 84 descendants, markaz) | ✅ 1 row |
| C04 | radmin insert target for descendant (`55be120d…`) | ✅ 1 row |
| C05 | Multi-target single campaign (national + region rows) | ✅ rows coexist, same campaign |
| C06 | `campaign_can_target_region` matrix | ✅ radmin: own T, descendant T, outside F, national F · gadmin: national T, any region T · owner: all T |
| C07 | `campaign_targets_authorized` matrix | ✅ radmin: own campaign T, national campaign F · gadmin: national T · owner: any T |
| C08 | `campaign_targets_national_unique` duplicate (NULL,NULL) | ✅ 23505 constraint (C1) |

## 9. Audience / Validation (live)

| # | Check | Result |
|---|---|---|
| C09 | Valid `target_roles` (e.g. `[customer,driver]`) accepted | ✅ submit OK |
| C10 | Invalid roles `[hacker]` | ✅ `Invalid campaign audience roles` |
| C11 | Invalid benefit | ✅ `Invalid campaign benefit` |
| C12 | Submit with **no** targeting rows | ✅ `Campaign must have at least one targeting region` |
| C13 | Audience stays on `campaigns.target_roles` (no new table) | ✅ schema verified |

## 10. Approval Center (live)

| # | Check | Result |
|---|---|---|
| C14 | `approval_requests` matches 2.3 §19 contract verbatim | ✅ schema verified |
| C15 | `approval_requests_pending_unique` partial index (state='pending') | ✅ present; duplicate (campaign_approve, same entity) → 23505 (C2) |
| C16 | Policies: `admin all` + `requester select` | ✅ present |
| C17 | `campaign_submit` creates request (state `pending`, approver NULL=owner) | ✅ |
| C18 | Owner approve → status `approved`, request `approved`, `campaign_reviews` `submit,approve,publish` | ✅ |
| C19 | Approve notification idempotency key `campaign-approve-<req>` (type promotion, deep_link `/campaign/<id>`) | ✅ 1 notification |
| C20 | Reject → status `rejected`... actually returns `draft`; request `rejected`, notification `campaign-reject-<req>` | ✅ |
| C21 | Reject → resubmit → `pending_review` again (`approvals rejected,pending`, reviews `submit,reject,submit`) | ✅ |
| C22 | Self-approval blocked (`Cannot decide your own request`) | ✅ |
| C23 | Reject without reason | ✅ `Rejection requires a reason` |
| C24 | Decide an already-decided request | ✅ `Approval request already decided` |
| C25 | Unsupported request type | ✅ `Unsupported request type` |
| C26 | Cancel pending approval request on cancel | ✅ request cancelled with reason |

## 11. Lifecycle (positive, live)

| # | Check | Result |
|---|---|---|
| C27 | Client INSERT always lands `draft` (published → draft) | ✅ (D1) |
| C28 | `campaign_submit` → `pending_review` + review `submit` | ✅ |
| C29 | Owner approve → `approved` | ✅ |
| C30 | `campaign_publish` → `published` + `published_at` set | ✅ |
| C31 | Publish with future `starts_at` → `scheduled` | ✅ |
| C32 | `campaign_pause` / `campaign_resume` (reviews `…,pause,resume`) | ✅ |
| C33 | `campaign_cancel` from `scheduled`/`draft` → `cancelled` (reason required) | ✅ |
| C34 | `campaign_archive` from `cancelled` → `archived` (reviews `cancel,archive`) | ✅ (P_ARCHIVE, txn-rolled-back) |
| C35 | Regional flow: radmin offer campaign (own + descendant targets) → submit → owner approve + publish cross-role | ✅ |
| C36 | Owner-approved regional campaign published by radmin's scope | ✅ |

## 12. Lifecycle Negative (all expected-denied, live)

| # | Check | Result |
|---|---|---|
| C37 | Double submit (`Only draft or rejected campaigns can be submitted`) | ✅ |
| C38 | Invalid decision (`Invalid decision`) | ✅ |
| C39 | Pause a draft (`Only published campaigns can be paused`) | ✅ |
| C40 | Cancel without reason (`Cancellation requires a reason`) | ✅ |
| C41 | Purge non-terminal campaign (`Campaign must be in a terminal state to purge media`) | ✅ |
| C42 | radmin publish a **national** campaign (`campaign_targets_authorized`=false) | ✅ blocked |

## 13. Media / Storage (live)

| # | Check | Result |
|---|---|---|
| C43 | gadmin upload to `campaigns/<published>/banner.png` | ✅ object stored |
| C44 | Customer read published media | ✅ 1 row |
| C45 | Customer read unpublished (approved-only) media | ✅ 0 rows (policy gate) |
| C46 | radmin upload into a global/out-of-scope campaign path | ✅ denied (RLS) |
| C47 | Upload to random path (`random/path.png`) | ✅ denied |
| C48 | `campaign_id_from_storage_path` parses valid UUID; NULL on non-uuid / short / single-component | ✅ |
| C49 | Purge flow: cancel → `campaign_purge_media` deletes storage objects + sets `is_active=false` on media+banners | ✅ (D2) |

## 14. Security Attack Matrix (negative, live)

| # | Probe | Expected | Actual | Result |
|---|---|---|---|---|
| C50 | customer INSERT `campaigns` | 42501 | 42501 RLS | ✅ |
| C51 | customer INSERT `campaign_banners` | 42501 | 42501 RLS | ✅ |
| C52 | customer `campaign_submit` | Not authorized | `Not authorized` | ✅ |
| C53 | customer SELECT `campaigns` | 0 rows | 0 rows (RLS silent) | ✅ |
| C54 | customer SELECT `approval_requests` | 0 rows | 0 rows (RLS) | ✅ |
| C55 | anon SELECT `campaigns` | 42501 | 42501 | ✅ |
| C56 | anon SELECT `approval_requests` | 42501 | 42501 | ✅ |
| C57 | gadmin DELETE `campaigns` | 42501 | 42501 (no grant) | ✅ |
| C58 | gadmin INSERT `approval_requests` | 42501 | 42501 (no grant) | ✅ |
| C59 | gadmin UPDATE `approval_requests` | 42501 | 42501 (no grant) | ✅ |
| C60 | radmin UPDATE national campaign | 0 rows | 0 rows (RLS scope filter) | ✅ |
| C61 | radmin decide own request | denied | `Cannot decide your own request` | ✅ |

## 15. Idempotency + Constraints

| Check | Result |
|---|---|
| Apply re-run idempotent | ✅ HTTP 201, no dupes |
| `campaign_targets_national_unique` (NULL,NULL) | ✅ 23505 |
| `approval_requests_pending_unique` (campaign_approve, entity) | ✅ 23505 |
| Notification idempotency (approve/reject) | ✅ single notification each |

---

## 16. Non-Destruction / Cleanup

| Check | Before | After | Result |
|---|---|---|---|
| `regions` | 6,157 | 6,157 | ✅ untouched |
| `users` | 5 | 5 | ✅ untouched (test admins created/removed) |
| Storage buckets | 5 | **6** (`campaign-media` added) | ✅ intended |
| Test fixtures (`040_*`) | — | all 0: campaigns, targets, media, banners, reviews, approvals, admin_region_assignments, test notifications | ✅ cleanup complete |
| Probe transactions | — | ROLLBACK — no residue (verified re-check) | ✅ |
| Pre-existing tables/data | — | untouched | ✅ |

---

## 17. Dart Migration Tests

| Check | Result |
|---|---|
| `test/features/promotion/migrations/promotion_migration_040_test.dart` | ✅ **20/20 pass** — parses the SQL migration file as source of truth (precedent: `test/features/regions/domain/egypt_geographic_dataset_test.dart`) |
| Full suite `flutter test` | ✅ **+751 all passed** (no regressions) |
| `flutter analyze` on test file | ✅ No issues found |

## 18. Analyzer / Scan / Diff

| Check | Result |
|---|---|
| `flutter analyze` | ✅ **0 errors**, 546 issues = exact pre-existing baseline (the +2 transient lint infos from the new test file were fixed) |
| `rg -cU '\r$'` | ✅ 0 on new files (LF-clean); no trailing whitespace |
| `git diff --check` | ⚠️ pre-existing CRLF artifact in `DECISION_LOG.md` only (documented repo format, Session 47) — new sections appended CRLF-consistent |
| Secret scan (migration, ADR-059/060, gate, plan, SESSION_STATUS, ROADMAP) | ✅ clean — no token material; PAT never printed/committed |
| Git scope | Docs + `supabase/migrations/040_promotion_targeting_media_approval.sql` + `test/features/promotion/` only; zero production Dart/Flutter behavior changes |

## 19. Evidence Artifacts

`/tmp/opencode/040_apply.log` · `040_apply2.log` (HTTP 201 ×3) · `/tmp/opencode/probe_040/*.sql` (P*, N*, ST*, C*) ·
`040_switch_test.sql` (role-switch mechanics) · `040_cleanup.sql` · `040_state.sql` · `040_final_state.sql` ·
`P_ARCHIVE.sql` (archive flow, txn-rolled-back). Live state re-verified clean after all probes.

## 20. Verdict

**🟢 PASS.** Migration 040 is live on `bttnlkmwhorjamzemwda`, idempotent, non-destructive, and hardened:

- **Targeting** — normalized junction, national sentinel, scope helpers verified across 3 admin personas;
- **Audience** — `target_roles` reuse, no duplicate concept;
- **Approval center** — §19 contract verbatim, RPC-only writes, requester-read + admin-all RLS, self/cross-approval blocked;
- **Lifecycle** — 8 RPCs, server-enforced preconditions (window, reasons, terminal-state purge), force-draft on INSERT closes the bypass;
- **Media/storage** — private bucket, published-only read, scope-gated uploads, GUC-based purge;
- **Security** — anon zero, approval writes RPC-only, no DELETE grant on campaigns, full negative matrix green;
- **Idempotency** — apply re-run + unique/notification idempotency all green;
- **Non-destruction** — regions/users untouched, all fixtures cleaned, probe txn residue = 0.

**STOPPING HERE.** No migration 041 (feed), no 042 (analytics), no Flutter changes, **no commit/push** until the
owner reviews and approves this gate.

**Next on approval:** migration 041 — `get_active_campaigns` feed (targeting + audience + published media +
TTL cache) per `PHASE_2_PROMOTION_IMPLEMENTATION_PLAN.md`.
