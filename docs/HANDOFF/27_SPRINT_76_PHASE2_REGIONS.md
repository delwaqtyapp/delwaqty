# SPRINT 76 — PHASE 2.1: REGIONAL SYSTEM (REGIONS) — IMPLEMENTATION

> **Session 45 · 2026-08-15 · Base `f65ab61e6fec9920fab256f3a7049df91a5aa08f` (master)**
> Supersedes nothing; builds directly on the Phase 2.0 audit
> (`docs/HANDOFF/25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`) and the approved D1–D4 design
> decisions (`docs/HANDOFF/26_SPRINT_76_PHASE2_DESIGN_DECISIONS.md`).

---

## 1. Scope

Phase 2.1 delivers the **Egypt regional foundation** decided in ADR-050:

1. `regions` schema + canonical Egypt dataset (27 governorates + country root) — migration 030.
2. `user_region_preferences` (detected / manual / verified) with state-preservation policy.
3. Flutter `regions` feature module (domain → data → presentation) with detection mapping.
4. Full test coverage + Pre-Commit Gate + PHASE 2.1 VERDICT.

**Out of scope (next phases):** admin hierarchy unification (2.2), chat extension (2.3),
notifications for regions/emergency (2.4), emergency/escalation (2.5), RPC hardening (2.7).

---

## 2. Migration `supabase/migrations/030_regional_system.sql`

### 2.1 `regions`
| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | deterministic client-assigned UUIDs (stable across environments) |
| `code` | TEXT UNIQUE | `EG` (country) · `EG-ALX` … `EG-WAD` (governorates, ISO 3166-2) |
| `parent_region_id` | UUID NULL FK→regions | country root has NULL |
| `country_code` | TEXT DEFAULT 'EG' | |
| `type` | TEXT CHECK | `country / governorate / city / district / area` |
| `name_ar` / `name_en` | TEXT | bilingual canonical names |
| `is_active` | BOOL DEFAULT true | |
| `metadata` | JSONB | `iso3166_2`, `aliases`, `wikidata` (gov. only) |
| `created_at` / `updated_at` | timestamptz | `updated_at` via `public.set_updated_at()` (018) |

- Indexes: `parent_region_id`, `(type, is_active)`, `name_ar`, `name_en`.
- **RLS:** `SELECT` → anon + authenticated; INSERT/UPDATE/DELETE → `public.is_admin()` (016).
  Grants restricted to the same roles. No RPCs created in 2.1 (none needed).
- Seed is **idempotent** (`ON CONFLICT (id) DO NOTHING`) — safe to re-run.

### 2.2 `user_region_preferences`
| Column | Type | Notes |
|--------|------|-------|
| `user_id` | UUID PK FK→users(id) | on delete cascade |
| `region_id` | UUID NOT NULL FK→regions | |
| `source` | TEXT CHECK | `detected / manual / verified` |
| `updated_at` | timestamptz | via `public.set_updated_at()` (018) |

- **RLS:** owner read/write; admin SELECT-only.

### 2.3 Dataset coverage (per D2 — never fabricate)
- **27 / 27 Egyptian governorates** seeded with official Arabic + English names, ISO 3166-2
  codes, and alias metadata.
- **City / district / area = NOT FOUND in any authoritative source we verified** → left empty by
  design. The recursive schema + `getChildren`/`searchRegions` already support adding them later.
- Egypt country row id: `00000000-0000-0000-0000-000000000001`; governorate ids
  `00000000-0000-0000-0000-000000000101` … `…127` (deterministic, documented in ADR-050).

---

## 3. Flutter `regions` module

### Domain (`lib/features/regions/domain/`)
| File | Content |
|------|---------|
| `entities/region.dart` | Freezed `Region` (camelCase fromJson; DB snake_case rows mapped in the data source `_fromRow`), `RegionType`, `RegionPreferenceSource`, `UserRegionPreference`, `RegionException`, `displayName(language)`, `aliases` getter |
| `repositories/region_repository.dart` | `getGovernorates / getChildren / getRegion / getRegionByCode / searchRegions / setUserRegion / getUserRegion` |
| `services/region_resolver.dart` | Pure Dart `RegionResolver` (Arabic/English normalization: diacritics, hamza variants, teh marbuta, alef maqsura, tatweel, stop tokens) + `RegionPreferencePolicy.shouldUpdate` (detected never overwrites manual/verified) |

### Data (`lib/features/regions/data/`)
| File | Content |
|------|---------|
| `datasources/remote/supabase_region_data_source.dart` | `RegionDataSource` + `SupabaseRegionDataSource` (SQL ordering by `name_en`, `.maybeSingle()`, `.or()` ilike search, `upsert(..., onConflict: 'user_id')`) |
| `repositories/region_repository_impl.dart` | passthrough repository |

### Presentation (`lib/features/regions/presentation/`)
| File | Content |
|------|---------|
| `providers/region_providers.dart` | `governoratesProvider`, `regionChildrenProvider`, `regionSearchProvider`, `currentUserRegionProvider`, `selectRegionProvider` (manual/verified persist + invalidate), `detectedRegionProvider` (GPS `UserLocation.detailedAddress` → resolver), `applyDetectedRegionProvider` (policy-guarded) |
| `pages/region_selection_page.dart` | search field + governorate list + current-selection marker + save via `selectRegionProvider` + l10n SnackBars |

### Registration & l10n
- `lib/features/regions/regions_module.dart` → registered in `lib/module_registry.dart` (id `regions`, route `/region-selection`).
- `lib/l10n/app_en.arb` / `app_ar.arb`: +5 keys (`selectRegion`, `regionSearchHint`, `regions`, `regionSaved`, `regionSelectionFailed`), regenerated via `flutter gen-l10n`.

---

## 4. Tests (new — `test/features/regions/`)

| File | Coverage |
|------|----------|
| `domain/region_entity_test.dart` | enum mapping, fromJson (with defaults), displayName fallback |
| `domain/region_dataset_test.dart` | **parses migration 030 seed SQL** — 27+1 rows, unique ids/codes, exact ISO code set, exact official EN names, no orphans, active, type/country invariants |
| `domain/region_resolver_test.dart` | normalization (hamza, diacritics, teh marbuta, tatweel), Arabic/English/alias matching, composed geocode address, ambiguity → null, empty/null guards; policy matrix (detected×{none,detected,manual,verified}, manual/verified always) |
| `data/mock_region_repository.dart` | hand-rolled in-memory fake (repo-wide pattern) |
| `data/region_repository_impl_test.dart` | mocktail passthrough + error propagation for all 7 methods |
| `presentation/pages/region_selection_page_test.dart` | loading → list, current-region check, search filter, save-and-pop flow, failure SnackBar, no-results |

**Total new: 60 tests.** Full suite: **663/663 passing** (`flutter test --no-pub --concurrency=2`).

---

## 5. Pre-Commit Gate

| Check | Result |
|-------|--------|
| `flutter pub get` | ✅ |
| `flutter gen-l10n` | ✅ (only pre-existing AR gaps remain: `addBranch`, `branchName`) |
| `build_runner build --delete-conflicting-outputs` | ✅ (Freezed/JSON codegen) |
| `flutter analyze` | ✅ **0 errors**, 24 warnings + 519 info — all pre-existing in untouched files; **region files have 0 issues** |
| `flutter test --no-pub --concurrency=2` | ✅ **663/663** |

---

## 6. PHASE 2.1 VERDICT: 🟢 CODE-COMPLETE

- ✅ Schema + canonical dataset (migration 030, idempotent, RLS correct).
- ✅ Flutter module registered + routed + l10n (EN/AR).
- ✅ Detection mapping (resolver) + state-preservation policy.
- ✅ 60 new tests; full gate green.
- ⚠️ **NOT committed / pushed** (per instructions).
- ⚠️ **Migration NOT applied live** — no local Postgres, no Docker, no Supabase PAT in this
  session. Apply/verify in the SQL editor or a migration run, then re-verify `is_admin()`
  grants and the seeded 28 rows.

> ⬆️ That statement was accurate at the time of the original report. Migration 030 has since
> been applied and verified — see **Section 8 · FINAL LIVE VERIFICATION — 2026-08-15** below.

---

## 7. Remaining risks / next

1. ✅ ~~**Live apply of migration 030**~~ — **DONE 2026-08-15** (see Section 8). Remaining at
   this gate: user review/approval, then commit + push.
2. Pre-existing Arabic l10n gaps (`addBranch`, `branchName`) — unrelated debt.
3. Next gate: **Phase 2.2 — Admin hierarchy unification** (D1) at user approval.

---

## 8. FINAL LIVE VERIFICATION — 2026-08-15

Migration 030 was applied to the live Supabase project **`bttnlkmwhorjamzemwda`** (delwaqtyapp,
North EU Stockholm — matches `.env.dev` `SUPABASE_URL`) via the Management API
(`POST /projects/{ref}/database/query`, HTTP 201, no errors) and re-run to confirm idempotency.

### 8.1 Migration 030 — reviewed / applied / verified
- ✅ Reviewed against D1–D4 (docs 25/26) before apply; dependencies present live
  (`public.is_admin()` 016, `public.set_updated_at()` 018, `public.users`); both new tables absent.
- ✅ **Applied live** (HTTP 201, `[]` result) — deterministic seed, idempotent
  (`ON CONFLICT (id) DO NOTHING`).
- ✅ **Idempotency verified** — full migration re-run returned HTTP 201, no errors, 28/28 rows
  intact.

### 8.2 Live data
- ✅ **28 total regions**: 1 Egypt country root (`…000000000001`) + **27/27 governorates**
  (…101–…127, ISO 3166-2:EG `EG-ALX` … `EG-WAD`).
- ✅ 0 duplicates (`distinct id` = `distinct code` = 28) · 0 orphans (all children reference an
  existing parent) · exactly 1 root (`parent_region_id IS NULL`) · 28/28 `is_active`.
- ✅ Columns/constraints match the schema in §2: PKs, `UNIQUE(code)`, FK CASCADE
  (`regions.parent_region_id`, `preferences.user_id→users`, `preferences.region_id→regions`),
  `type`/`source` CHECKs, `updated_at` trigger via `public.set_updated_at()`.

### 8.3 Security — RLS / policies / canonical authz
- ✅ RLS enabled on `regions` + `user_region_preferences` (`relrowsecurity = true`).
- ✅ Policies verified: `regions select public` (true) · `regions admin write`
  (USING+WITH CHECK `public.is_admin()`) · `user_region_preferences owner rw`
  (`auth.uid() = user_id`) · `user_region_preferences admin select`.
- ✅ Canonical **016 `is_admin()`** confirmed live (SECURITY DEFINER, `users.role IN
  ('admin','owner')`); live result `false` for a non-admin `auth.uid()`, `true` for the owner.
- ✅ **Anon write protection verified** (functional): anon INSERT → 42501; anon UPDATE/DELETE →
  RLS no-op (rows verified intact); anon preference INSERT → `permission denied`.
- ✅ **User preference isolation verified**: owner CAN write own preference; writing another
  user's preference → 42501.
- ✅ **Owner/admin behavior verified**: owner CAN INSERT into `regions` (admin write path) and
  manage own preference; non-admin authenticated INSERT into `regions` → 42501.

### 8.4 ⚠️ SECURITY HARDENING FINDING (discovered + resolved during the live gate)

Supabase's platform `ALTER DEFAULT PRIVILEGES` auto-grants **ALL** privileges (including
`TRUNCATE`/`TRIGGER`/`REFERENCES`) on every newly created table to `anon`, `authenticated`, and
`service_role`. Migration 030's explicit `GRANT`s were purely **additive**, so on the first live
apply `anon` held full DML + `TRUNCATE` on both new tables — exceeding the approved grant model
(`regions`: anon SELECT-only; `user_region_preferences`: no anon access).

**Fix (in migration 030, revoke-before-grant):**
```sql
REVOKE ALL ON public.regions FROM anon, authenticated;
REVOKE ALL ON public.user_region_preferences FROM anon, authenticated;
GRANT SELECT ON public.regions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.regions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_region_preferences TO authenticated;
```
Re-applied live (HTTP 201) — the REVOKE/GRANT statements are idempotent.

### 8.5 Final ACL state (verified live after fix)
| Table | Role | Privileges |
|-------|------|-----------|
| `regions` | `anon` | **SELECT only** — no INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER/REFERENCES |
| `regions` | `authenticated` | SELECT/INSERT/UPDATE/DELETE (admin writes further gated by `is_admin()` RLS) — no TRUNCATE/TRIGGER/REFERENCES |
| `user_region_preferences` | `anon` | **no access** |
| `user_region_preferences` | `authenticated` | SELECT/INSERT/UPDATE/DELETE (owner-only writes via `auth.uid() = user_id` RLS) |

RLS remains authoritative; the revoked grant surface removes even the DB-level (non-RLS) write
paths such as `TRUNCATE`, which RLS does not cover.

### 8.6 Flutter↔Supabase compatibility (static, re-verified)
- ✅ Data-source queries use the live snake_case columns (`type`, `is_active`,
  `parent_region_id`, `id`, `code`, `name_ar`, `name_en`; `user_id`, `region_id`);
  `_fromRow` maps to camelCase Freezed entities.
- ✅ `RegionType` / `RegionPreferenceSource` enums match the DB `type` / `source` CHECK values;
  `upsert(..., onConflict: 'user_id')` matches the `user_id` PK.

### 8.7 Gate (final)
| Check | Result |
|-------|--------|
| `flutter analyze` | ✅ 0 errors · 24 warnings + 519 info (pre-existing baseline; 0 issues in region files) |
| `flutter test --no-pub --concurrency=2` | ✅ **663/663** (60 new region tests) |

**Phase 2.1 final verdict: 🟢 READY TO COMMIT** — code-complete, gate green, migration 030
applied + verified live (incl. security hardening). Not committed/pushed.

---

## Files
- `supabase/migrations/030_regional_system.sql` (new)
- `lib/features/regions/**` (new module: entity, repository, resolver/policy, data source, repo impl, providers, page, module)
- `lib/module_registry.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (edited)
- `test/features/regions/**` (new tests)
- `docs/DECISION_LOG.md` — ADR-049…052 (design session)
- `docs/HANDOFF/25_SPRINT_76_PHASE2_ARCHITECTURE_AUDIT.md`, `docs/HANDOFF/26_SPRINT_76_PHASE2_DESIGN_DECISIONS.md` (basis)
- `docs/HANDOFF/27_SPRINT_76_PHASE2_REGIONS.md` (this report) · `SESSION_STATUS.md`
