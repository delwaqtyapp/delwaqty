# 30 — Phase 2.1B: Egypt Complete Geographic Coverage — AUDIT + DESIGN (READ-ONLY)

**Session 48 · 2026-08-15 · AUDIT/DESIGN-ONLY — no migration applied, no DB/structure/security
changes, no production code changes, nothing committed/pushed.**

> **Scope:** audit the existing 28-region implementation (Phase 2.1/2.2), research the authoritative
> Egyptian geographic data universe (admin hierarchy, cities, villages, new cities, tourist cities,
> resorts, hotels, POIs, geocoding providers), and produce the implementation architecture for
> complete geographic coverage. This document is the Phase 2.1B gate deliverable. **STOP after
> delivery — awaiting explicit user approval before any implementation.**

---

## 0. Executive Summary

| Question | Answer |
|----------|--------|
| Is the existing 28-region foundation sound? | **Yes.** Live-verified: 28 rows (Egypt root + 27 governorates), deterministic immutable IDs, ISO 3166-2 codes, RLS 2 policies (SELECT public / admin write), 6 indexes, `user_region_preferences` (0 rows) intact. 030/031 untouched. |
| What is missing? | Everything below governorate level (cities, markaz, villages, small settlements), all tourism/POI data (hotels, resorts, tourist villages, compounds), new cities, and a real GPS→region resolution pipeline. 030 explicitly deferred these ("must be added later from a verified source"). |
| Can it be implemented? | **Yes**, via a strict two-layer model: (1) extend the canonical `regions` admin hierarchy with verified administrative levels; (2) new `geo_places` + alias tables for tourism/POIs (never mixed into the admin hierarchy). Admin authorization (`is_admin_for_region` parent-walk) is **automatically compatible** and benefits from deeper levels. |
| Is a decision required before implementation? | **Yes (🟡).** Two data-source decisions + one schema decision must be approved: (D1) authoritative source for markaz/aqsam/cities/villages (OCHA HDX COD-AB vs CAPMAS vs Ministry of Local Development); (D2) geocoding provider stack (cache-legal OSM/Photon vs Mapbox/HERE vs Google — Google ToS restricts caching); (D3) extend `regions.type` CHECK vocabulary (add `markaz`, `village`, `new_city`; keep `city`/`district`/`area`). |
| Verdict | 🟡 **REQUIRES DATA SOURCE DECISION** (see §0.1). Architecture and scale are fully verified; three explicit approvals unblock implementation. No blocking unknowns remain. |

### 0.1 Decisions required before implementation (user gate)

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| D1 | Authoritative dataset for markaz/aqsam/cities/villages | (a) **OCHA HDX COD-AB** (open, machine-readable, levels 0–3, ~365 2nd-level units, has Arabic names + pcodes); (b) CAPMAS official lists (authoritative but not freely machine-readable, licensing unclear); (c) Ministry of Local Development markaz list (189, authoritative, non-machine-readable); (d) Wikipedia Arabic lists (freely usable but secondary) | **(a) OCHA HDX COD-AB as the load dataset** + CAPMAS/MLD cross-check where free; Wikipedia Arabic for name/alias gaps. Recommend (a) to unblock; CAPMAS licensing to be cleared with the client/legal if full official dataset is required. |
| D2 | Geocoding/reverse-geocoding provider stack | (a) **OSM/Photon** (ODbL, cacheable, free, no API key needed, secondary coverage gaps); (b) Mapbox; (c) HERE; (d) Google Places (best coverage, **ToS forbids caching/storing** — conflicts with canonical-ID architecture); (e) GeoNames (CC-BY, weak reverse geocode) | **(a) Photon/OSM primary + GeoNames enrichment**, all behind a server-side 016-pattern proxy RPC (keys never shipped in-app). Google only as a last-resort online-only lookup if coverage demands — never cached. |
| D3 | `regions.type` taxonomy extension | (a) Extend CHECK to `country/governorate/markaz/district/city/village/new_city/area`; (b) overload existing 5 types; (c) two-table split below governorate | **(a) Extend the CHECK** (additive, ADR-050-compatible). Keeps one canonical admin tree for `is_admin_for_region`, selection UI, and routing. Record as ADR-057. |

---

## 1. Existing-Region Audit (live + code, read-only)

### 1.1 Database (migration 030, live-verified 2026-08-15)

- `public.regions` — self-referencing (`parent_region_id`), 28 rows: Egypt root (`type='country'`) +
  27 governorates. **All city/district/area rows are absent by design** (030 header: *"City / district /
  area data is deliberately NOT fabricated here; it must be added later from a verified source"*).
- **Deterministic immutable IDs:** `00000000-0000-0000-0000-000000000001` (Egypt), `…101`–`…127`
  (governorates, alphabetical by ISO code). Verified live — unchanged since Phase 2.1 (`1f3ba02`).
- **Codes:** `code TEXT UNIQUE` = `EG` + ISO 3166-2:EG (`EG-ALX` … `EG-WAD`).
- **Type CHECK:** `('country','governorate','city','district','area')` — `city/district/area` values
  exist in the enum but **zero rows use them yet**.
- **RLS (verified live, 2 policies):** `regions select public` (SELECT true) ·
  `regions admin write` (ALL, `is_admin()`).
- **Indexes (verified live, 6):** `regions_pkey` · `regions_code_key` · `idx_regions_parent` ·
  `idx_regions_type_active` · `idx_regions_name_ar` · `idx_regions_name_en`.
- **Grants (verified):** anon/authenticated = SELECT only; writes RLS-gated to `is_admin()`; no
  realtime membership; no default-privilege leaks.
- `public.user_region_preferences` — 0 rows live; owner rw (RLS) + admin select; `source`
  CHECK `('detected','manual','verified')`.

### 1.2 Migration 031 dependency (Phase 2.2, verified live)

`public.is_admin_for_region(p_region_id)` is a **SECURITY DEFINER** recursive parent-walk:

```
covered := {p_region_id} ∪ {r.id | r.parent_region_id ∈ covered}
```

- It consumes only `regions.id` + `parent_region_id`. Adding deeper levels **cannot break it** —
  it can only extend coverage. `admin_region_assignments` (0 rows) and the `scope`
  `('self','descendants')` model are untouched.
- **Compatibility invariant for Phase 2.1B:** every new `regions` row must hang under an existing
  governorate (or under a new city/markaz node whose ancestry reaches a governorate). No orphan roots
  other than `EG`.

### 1.3 Flutter layer (`lib/features/regions/**`)

- `RegionType` enum (country/governorate/city/district/area) mirrors the DB CHECK.
- `RegionPreferenceSource` (detected/manual/verified) + `RegionPreferencePolicy.shouldUpdate`
  (state preservation: `detected` only replaces `detected`; `manual`/`verified` always win).
- `RegionResolver.normalize/tokenize/resolveGovernorateId` — **governorate-level only**, pure-Dart,
  deterministic. Aliases are read from `metadata.aliases` (JSONB) — already present on all 27 seeds.
- `SupabaseRegionDataSource`: `getGovernorates` · `getChildren` · `getRegion` · `getRegionByCode` ·
  `searchRegions` (name ilike, limit 20) · `setUserRegion` · `getUserRegion`.
- Providers: `governoratesProvider` · `regionChildrenProvider` (family) ·
  `regionSearchProvider` (family) · `currentUserRegionProvider` · `selectRegionProvider` ·
  `detectedRegionProvider` (GPS → `detailedAddress` → resolver) · `applyDetectedRegionProvider`.
- UI: `RegionSelectionPage` (`/region-selection`); admin scope page dropdowns keyed
  `region-select`/`scope-select` rely on stable region IDs/names.

### 1.4 Audit conclusion

Sound, minimal, and deliberately shallow. 030 + 031 are **preserved as-is**. Phase 2.1B is a pure
**additive** layer: new rows in `regions`, new tables for places/aliases, and new client-side
resolution logic. No existing ID, code, type enum value, policy, or grant changes.

---

## 2. Governorates (Level 1) — VERIFIED COMPLETE

- **27 governorates — stable, undisputed, already seeded and live.** No change required.
- Authority: ISO 3166-2:EG (in use), official division since 1960 (Luxor split from Qena in 2009 is
  the most recent change — already reflected).
- All 27 carry `metadata.aliases` (transliteration variants) already.
- **Action:** none. Re-verify counts at import time (dataset test asserts 27).

---

## 3. Centers — markaz / مراكز (Level 2, rural) — VERIFIED SCALE, SOURCE DECISION NEEDED (D1)

| Source | Count | Authority | Machine-readable | License |
|--------|-------|-----------|------------------|---------|
| Ministry of Local Development | **189** | Official | No (HTML) | Unclear |
| Wikipedia ar (قائمة مراكز مصر) | **174–175** | Secondary | Partially | CC BY-SA |
| CAPMAS | **174–175** | Official | No | Unclear |
| Statoids (2013) | **162** | Secondary | No | Freely usable |
| OCHA COD-AB (HDX) | ~365 total 2nd-level (markaz + qism) | Humanitarian (UN) | **Yes** (SHP/GeoJSON, Arabic + English names, pcodes) | Open (HDX/UN terms) |

- Discrepancy **162 vs 189** is real: different editions, merges, and new-city carve-outs. **D1 must
  pick one canonical source** (recommend OCHA COD-AB load set + MLD/CAPMAS cross-check).
- Markaz are the primary **administrative** 2nd level (Nile valley + Delta governorates). They are the
  backbone of governorate-level admin scoping in Phase 2.2.
- **Schema mapping:** markaz → new `regions.type='markaz'`, `parent_region_id = governorate`.

---

## 4. Aqsam / Urban Districts (Level 2, urban) — VERIFIED SCALE

| Source | Count | Notes |
|--------|-------|-------|
| Wikipedia ar (قائمة أقسام مصر) | **172–212** | City-level qism in Cairo/Alex/Giza and all urban governorates |
| OCHA COD-AB | included in ~365 2nd-level | Qism + markaz combined |

- Aqsam (قسم) are urban administrative districts (e.g., Cairo's 38 qism, Alexandria's 16+).
- **Schema mapping:** qism → existing `regions.type='district'`, `parent_region_id = city` (or
  governorate where the city and qism coincide, e.g., urban governorates).

---

## 5. Cities (Level 3) — VERIFIED SCALE

| Source | Count | Notes |
|--------|-------|-------|
| CAPMAS (2006 census) | **216** | Official |
| Wikipedia ar (list of Egyptian cities) | **231** (Jan 2023) | Secondary, current |

- Includes both markaz-seat cities and standalone cities. New cities (see §8) are **not** in these
  counts — they are a separate class.
- **Schema mapping:** city → existing `regions.type='city'`, parent = markaz or governorate.

---

## 6. Villages (Level 3/4) — VERIFIED SCALE, PARTIAL COVERAGE

| Source | Count | Notes |
|--------|-------|-------|
| CAPMAS (2016) | **4,709** | Official; includes ~30 new villages since 2016 |
| Youm7 / press reporting | 4,470–4,732 | Ranges reflect definition drift (village vs township vs ezba) |
| OCHA COD-AB | level 3 partial | Covers populated places partially, not all villages |

- Village definition is the **most volatile** of all levels (merges, upgrades to cities, new
  settlements). Do **not** fabricate; import only source-confirmed rows and mark the rest
  `UNVERIFIED`/absent.
- **Schema mapping:** village → new `regions.type='village'`, parent = markaz.

---

## 7. Small Settlements (ezba / najʿa / hamlet) — PARTIAL DATA, LOW PRIORITY

- Not systematically listed by any public authoritative dataset. OSM nodes and GeoNames
  `P/PPLL/PPLX` provide partial coverage (GeoNames: 11,569 populated places total, incl. towns).
- **Decision:** treat small settlements as **geo_places** (`type='settlement'`, linked to the nearest
  canonical admin region) rather than `regions` rows — they are localities, not administrative units.
  This keeps the admin hierarchy clean (mandate) and avoids thousands of non-authoritative hierarchy
  nodes.

---

## 8. New Cities — VERIFIED LEGAL FRAMEWORK, SOURCE NUCA

- **NUCA (New Urban Communities Authority, `newcities.gov.eg`)** established by **Law 59/1979**;
  ~39+ new cities across three generations (1st: New Cairo, 6th October, 10th Ramadan, Obour, Sadat;
  2nd: Badr, El Shorouk, New Aswan…; 3rd: New Administrative Capital, New Alamein, New Mansoura,
  East Port Said, New Galala…).
- **Legal status (critical):** new cities are governed by **NUCA, not the ordinary markaz/qism
  hierarchy** (Law 59/1979 Art. 13/27/50 — advisory boards of trustees, no ordinary municipal
  council). **Exception:** New Galala is NOT under NUCA. Generation list + IDs on
  `newcities.gov.eg/about/Lists/List/DispForm.aspx?ID=1`.
- **Schema decision:** new cities **are** real localities users live in and must be selectable +
  admin-scoped → **rows in `regions`**, `type='new_city'` (new enum value, D3), parent = host
  governorate (e.g., New Cairo → Cairo, 6th October → Giza, Obour → Qalyubia). NUCA legal status
  recorded in `metadata` (`{"governed_by":"NUCA","law":"59/1979"}`; New Galala:
  `{"governed_by":"provincial","note":"not under NUCA"}`).
- **Admin compatibility:** parent-walk covers them under the governorate automatically; no 031 change.

---

## 9. Tourist Cities — ADMINISTRATIVE REALITY SPLIT

- Some "tourist cities" are **real administrative cities** (→ `regions.type='city'`):
  Sharm el-Sheikh, Dahab, Taba, Saint Katherine, Hurghada, Marsa Alam, El Alamein, Ras Sedr,
  Ain Sokhna (part of Suez), Luxor, Aswan, Matrouh.
- Others are **tourist settlements under a host city/governorate** (→ `geo_places.type='tourist_city'`):
  e.g., Sahl Hasheesh, Makadi Bay, El Gouna (technically a tourist village), Port Ghalib, Soma Bay,
  Nuweiba.
- Rule: **if it has an administrative district/qism or is a municipal seat → `regions`; otherwise →
  `geo_places` linked to the containing region.**

---

## 10. Tourist Villages (قرى سياحية) — LEGAL CATEGORY, geo_places

- A legal category under Egyptian tourism law (tourist village licenses/regulations); distinct from
  hotels and from ordinary villages.
- Examples: El Gouna, Sahl Hasheesh, Makadi Bay, Soma Bay, Port Ghalib, Marsa Alam tourist villages,
  North Coast villages (Marassi, Hacienda Bay, Amwaj, Stella Di Mare…).
- **Schema:** `geo_places.type='tourist_village'`, `region_id` → containing city/governorate;
  `metadata.legal_category='tourist_village'`. **Never a `regions` row** (not administrative units).

---

## 11. Resorts

- Standalone resorts/hotel-resorts (single property or small cluster) → `geo_places.type='resort'`.
- Includes Red Sea coast resorts, North Coast resorts, Siwa resorts, Ain Sokhna resorts.
- Data source: OSM `tourism=hotel`/`tourism=resort` + GeoNames `S/HTL`/`S/RES` + provider lookup;
  dedup by coordinate proximity + name normalization. Mark `PROVIDER-DERIVED` until verified.

---

## 12. Hotels Strategy — VERIFIED SCALE, HYBRID CACHE RECOMMENDED

| Measure | Value | Source |
|---------|-------|--------|
| OSM `tourism=hotel` in Egypt | **1,650** elements | OSM (ODbL) |
| GeoNames `S/HTL` | **1,357** hotels (of 35,024 features / 11,569 populated places) | GeoNames (CC BY 4.0) |
| Ministry of Tourism hotel rooms | **222,716** rooms (end-Mar 2024) | Official |
| UNWTO/Statista (2022) | **1,207** hotels | Secondary |
| Projection end-2027 | **~1,700** hotels (~1,300 in 2022, ~4%/yr) | Extrapolation |

- **Strategy (recommended): hybrid static cache.** Build a static canonical set of
  **~1,500–2,000 hotels** from OSM + GeoNames (dedup by name + coordinate, ~50 km/hot spot-aware
  rules) → `geo_places.type='hotel'`, each with `region_id`, `point`, `source`, `confidence`.
  Supplement with dynamic provider lookup **only** when a static match is not found (and never
  cache provider-only results from Google per ToS).
- **Licensing (verified):** OSM ODbL (attribution + share-alike; storing derived data OK with
  attribution); GeoNames CC BY 4.0 (attribution); Google Places ToS **forbids caching/offline
  storage** — must not feed the canonical table; Mapbox/HERE permit caching under their terms.
- Hotels are **never** `regions` rows (mandate). They are POIs.

---

## 13. Compounds / Gated Developments

- Private residential compounds (Mountain View, Palm Hills, Madinaty, Rehab, Tagamo3 El-Osra, New
  Cairo compounds…) → `geo_places.type='compound'`, linked to their city/governorate.
- NUCA/developers publish lists; OSM `landuse=residential`/`name` coverage is partial. Import
  source-verified only; volume estimated **tens–low hundreds** of notable compounds. Low priority vs
  admin hierarchy; keep `UNVERIFIED` until sourced.

---

## 14. POI Strategy — GEO_PLACES TYPE TAXONOMY

```
geo_places.type ∈ {hotel, resort, tourist_village, tourist_city, compound, landmark,
                   settlement, poi}
```
- Priority for value: `hotel` → `resort`/`tourist_village` → `tourist_city` → `landmark` → `compound`
  → `settlement` → `poi`.
- **Landmarks** (Pyramids, temples, museums, mosques, churches) → `geo_places.type='landmark'`;
  volume ~100–300 from OSM `tourism=attraction` + GeoNames + provider.
- Every `geo_places` row carries: `region_id` FK, optional `point` (PostGIS geometry), `source`,
  `source_ref`, `license`, `confidence`, `is_active`. No row enters without a source + license.
- **Never** introduce business listings (restaurants, shops) — those belong to the marketplace
  domain, out of scope for geographic coverage.

---

## 15. GPS Architecture — RESOLUTION PIPELINE

Current `detectedRegionProvider` resolves **governorate only** from `detailedAddress` string.

Targeted pipeline (Phase 2.1B client):

```
GPS fix
  → (1) reverse geocode           (provider RPC, §16)
  → (2) normalize candidate       (GeocodingCandidate: country/admin1/admin2/city/
                                     town/suburb/district/road/poi/point)
  → (3) spatial match             (PostGIS point-in-polygon, §17)
  → (4) resolve canonical region  (best granularity: governorate always;
                                     city/markaz only on HIGH confidence)
  → (5) confidence gate           (RegionPreferencePolicy — never overwrite
                                     manual/verified, §19)
  → (6) persist (source='detected') | no-op
```

- Keep resolution **pure + deterministic** (testable). DB writes only at step 6, RLS-gated.
- **Boundary/degrade behavior:** outside all polygons (GPS noise, sea, border), fall back to nearest
  admin centroid within tolerance (option E) or to the geocoder's `admin1` string; never fabricate.

---

## 16. Geocoding Architecture — MULTI-PROVIDER + NORMALIZATION

- **Server-side 016-pattern proxy RPC** (`geo_reverse_geocode(point)`) — API keys live in
  Supabase Vault / secrets, **never** in the Flutter app (current code does client-side only; the
  resolver is local, which stays).
- **Provider stack (D2):** primary **Photon (OSM)** (free, cacheable, no key) → enrichment
  **GeoNames** (CC BY) → optional Mapbox/HERE when configured. **Google restricted to
  online-only**, never cached.
- **GeocodingCandidate normalization** (new domain model, mirrors `RegionResolver.normalize`):
  unified address-component mapping across providers (Nomatim/Photon, Mapbox, HERE, Google, GeoNames
  geometries differ) → `GeocodingCandidate.fromProviderX` mappers.
- **Cache legality:** OSM/Photon + GeoNames results cacheable; store `license` + `provider` +
  `fetched_at` provenance on every cached candidate.

---

## 17. Spatial Matching — OPTIONS A–E (EVALUATION)

| Option | Mechanism | Verdict |
|--------|-----------|---------|
| **A. Client-side point-in-polygon** | Bundle admin boundary GeoJSON in app; test locally | ❌ Rejected — Egypt admin boundaries are heavy (levels 0–3), update friction, no single source shipped. |
| **B. Server-side PostGIS (recommended)** | `geo_region_for_point(point)` SECURITY DEFINER RPC using `ST_Contains` over admin polygons table | ✅ **Recommended** — Supabase supports PostGIS; 016 pattern; RLS-safe; returns canonical region chain at requested granularity. |
| **C. Provider admin lookup** | Use reverse-geocode address components directly (no boundary data) | ⚠️ Partial — works when provider is authoritative (Google/Mapbox); inconsistent across providers; keep as candidate input, not source of truth. |
| **D. Hybrid** | Provider string → candidate regions → verify with B | ✅ **Recommended** — string is a cheap pre-filter; PostGIS is the authoritative disambiguator; handles provider inconsistency. |
| **E. Nearest-centroid fallback** | When point in no polygon (coast/border/noise) | ✅ Keep as tolerance fallback (bounded radius), returns nearest governorate, marks LOW confidence. |

- Boundary source for option B: OCHA COD-AB (levels 0–3) or geoBoundaries (CC BY 4.0); loaded to a
  new `geo_admin_boundaries` table at import time.
- **Note:** PostGIS availability on Supabase host is confirmed as a platform capability; verify
  `postgis` extension enablement during implementation (reads only, no schema change now).

---

## 18. Canonical IDs — DETERMINISTIC SCHEME

- **Governorates (existing, immutable):** keep `00000000-0000-0000-0000-000000000101…127`. **Never
  renumber.**
- **New admin rows (markaz/aqsam/cities/villages/new_cities):** deterministic UUID **v5** derived
  from the authoritative source code where one exists (OCHA/HDX `pcode`, e.g. `EG-01-1`), else
  deterministic sequential within the documented scheme (`…101` governorate → children `…10101`,
  `…10102`…). Idempotent re-imports must never change an ID.
- **geo_places:** UUID **v5** from `(source, source_ref)` (e.g. `osm:way:123`, `geonames:361061`) →
  idempotent, dedup-friendly, traceable.
- **Aliases:** surrogate PK + `(entity_type, entity_id, alias, lang)` unique.

---

## 19. Aliases — NORMALIZED MODEL

- Governorates already use `metadata.aliases` (JSONB). For the complete hierarchy (~7k regions +
  ~3k places, 3–5 aliases each → ~25k–40k alias rows) a **normalized `geo_aliases` table** is
  recommended (searchable, dedupable, per-source provenance):

```
geo_aliases(id, entity_type, entity_id, alias, lang, is_primary, source, created_at)
  UNIQUE (entity_type, entity_id, alias, lang)
```
- Sources: OSM multilingual `name:*`, GeoNames alternate names, CAPMAS variants, user-report
  (self-correcting, `source='user'`), Wikipedia redirects.
- `RegionResolver` gains alias lookup; resolver token matching extended from governorate to any level.

---

## 20. Confidence Model

| Level | Meaning | Set when | Persisted |
|-------|---------|----------|-----------|
| **HIGH** | Verified spatial containment (PostGIS) + ≥2 independent signals (provider component agreement / OSM + GeoNames match) | import verification + runtime | `geo_places.confidence`, detection result |
| **MEDIUM** | Single strong signal (one authoritative geocoder, or OSM-only, or exact alias match) | runtime detection, default import | same |
| **LOW** | Fuzzy string match, nearest-centroid fallback, provider-only (uncacheable) | runtime degrade paths | same |
| **UNVERIFIED / MISSING** | Data absent or not yet source-confirmed | import staging | `data_quality` flag |

- **State-preservation invariant (mandatory):** detection may **never** overwrite
  `manual`/`verified` preferences (existing `RegionPreferencePolicy.shouldUpdate` — extended to
  require HIGH/MEDIUM for `detected` persistence; LOW never persists without user confirmation).

---

## 21. Admin Compatibility — NO SECOND AUTHZ MECHANISM

- `is_admin_for_region()` unchanged — new levels only deepen the covered set.
- New cities under governorates → covered by `scope='descendants'`.
- `admin_region_assignments` (0 rows) untouched; FK targets still `regions.id`.
- **No new admin/authz tables, roles, or functions.** The 016-pattern proxy RPCs for geocoding are
  data-service functions, not authorization mechanisms (same pattern as `geo_*` reads via
  `is_admin()`-guarded or authenticated-only grants).

---

## 22. DB Architecture — NEW SCHEMA (IMPLEMENTATION-PHASE SPEC)

```
regions                      (EXISTING, extended — admin hierarchy ONLY)
  + rows: markaz / district(qism) / city / village / new_city under governorates
  + type CHECK extended (D3): country/governorate/markaz/district/city/village/new_city/area
  + metadata: nuca/governance provenance, admin_level, source, source_ref, license, confidence

geo_places                   (NEW — tourism/POIs, NEVER admin)
  id, type, region_id FK→regions, name_ar, name_en, aliases?
  point GEOMETRY(Point,4326), source, source_ref, license, confidence,
  is_active, metadata, created_at, updated_at

geo_aliases                  (NEW — normalized search/dedup)
  entity_type ('region'|'place'), entity_id, alias, lang, is_primary, source, created_at

geo_admin_boundaries         (NEW — PostGIS polygons for spatial matching, import-only)
  region_id FK→regions, level, geometry GEOMETRY(MultiPolygon,4326),
  source, source_ref, license, valid_from
```
- RLS: `geo_places`/`geo_aliases` = SELECT public + admin write (mirrors 030 pattern);
  `geo_admin_boundaries` = SELECT public, write admin-only (or service-role). No anon writes.
  Realtime: none of these subscribe (read path only, keep realtime surface minimal).
- GRANT/REVOKE-before-GRANT discipline from 030/031 applies to every new table.

---

## 23. Indexing

- `regions`: add `(parent_region_id, type)`, keep existing; `pg_trgm` GIN on `name_ar`/`name_en` for
  Arabic fuzzy search (extends `searchRegions` beyond ilike).
- `geo_places`: `region_id` btree, `type` btree, GIST on `point`, GIN trigram on names, UNIQUE on
  `(source, source_ref)`.
- `geo_aliases`: btree `(entity_type, entity_id)`, GIN trigram on `alias`, UNIQUE
  `(entity_type, entity_id, alias, lang)`.
- `geo_admin_boundaries`: GIST on `geometry`, btree `region_id`.
- Verify every new index against the live query shapes (`is_admin_for_region` recursive walk stays
  indexed by `parent_region_id`).

---

## 24. Data Sources — EVIDENCE TABLE

| Data | Source | URL | Authority | Coverage | License | Usable for prod | Import legality |
|------|--------|-----|-----------|----------|---------|-----------------|-----------------|
| Governorates | ISO 3166-2:EG | (in use) | **Official** | 27/27 | Open standard | ✅ | ✅ |
| Markaz/aqsam/cities/villages | OCHA HDX COD-AB (Egypt) | hdx.hdx.rwlabs.org (Egypt COD-AB) | Humanitarian (UN) | Levels 0–3 | Open (HDX/UN) | ✅ | ✅ (attribution) |
| Admin boundaries (polygons) | OCHA COD-AB / geoBoundaries | geoBoundaries.org | Secondary-official | L0–L3 | **CC BY 4.0** | ✅ | ✅ |
| Markaz list | Ministry of Local Development | (official portal) | **Official** | 189 markaz | Unclear | Cross-check only | ❓ legal review |
| Cities | CAPMAS 2006 | (official) | **Official** | 216 | Unclear | Cross-check only | ❓ legal review |
| Villages | CAPMAS 2016 | (official) | **Official** | 4,709 | Unclear | Cross-check only | ❓ legal review |
| New cities | NUCA (Law 59/1979) | newcities.gov.eg | **Official** | 39+ | Public info | ✅ (name/status) | ✅ |
| Hotels/POIs | OpenStreetMap | openstreetmap.org | Community | 1,650 hotels | **ODbL** | ✅ | ✅ (attribution) |
| Hotels/places | GeoNames | geonames.org | Community | 35,024 features | **CC BY 4.0** | ✅ | ✅ |
| Reverse geocode | Photon (OSM) | photon.komoot.io | Community | global | ODbL | ✅ | ✅ |
| Hotel rooms aggregate | Ministry of Tourism | (official) | **Official** | 222,716 rooms | — | Stats only | ✅ |
| Geocoding (Google) | Google Places | developers.google.com | Commercial | best coverage | Proprietary | **No caching** | ❌ cached |

---

## 25. Data Quality

- **Provenance mandatory:** every row/alias records `source`, `source_ref`, `license`, `confidence`.
- **No fabrication (mandate):** absent/unverified data is marked `UNVERIFIED`/`MISSING`, never
  guessed. Names/codes/coordinates/parents only from a cited source.
- **Normalization:** reuse `RegionResolver.normalize` (Arabic diacritics/hamza/alef/yāʾ/taʾ marbuta
  folding + English lowercasing) for dedup and alias matching.
- **Dedup:** OSM+GeoNames hotel dedup by normalized name + coordinate tolerance + region containment;
  alias convergence tracks conflicts for manual review.
- **Hierarchy integrity checks:** no cycles, no orphan (non-`EG`) roots, single path to `EG`,
  parent-type order validated (`country→governorate→markaz/qism→city→village`), FK integrity,
  code uniqueness, immutable-ID assertions (re-import never changes an ID).
- **Verification workflow:** OFFICIAL sources → human review before promote; PROVIDER-DERIVED →
  auto-import + `UNVERIFIED`; a later verification sweep (boundary + provider cross-check) upgrades
  confidence.

---

## 26. Import Pipeline

1. **Extract** (offline ETL, not in-app): pull OCHA COD-AB (SHP/GeoJSON), NUCA list, OSM via
   Overpass (`tourism=hotel`/`resort`/`attraction`), GeoNames (`S/HTL`,`P`…), cross-check CAPMAS/MLD
   counts.
2. **Normalize** names (Arabic + English), map source codes → canonical UUIDs (v5).
3. **Deduplicate** (osm↔geonames, name+coordinate).
4. **Stage** into `geo_import_staging` (temp, `UNVERIFIED` by default).
5. **Validate** (quality rules §25) → report.
6. **Promote** (insert/update `regions`/`geo_places`/`geo_aliases`/`geo_admin_boundaries`) inside a
   transaction; idempotent (`ON CONFLICT`).
7. **Verify** live (counts vs source, hierarchy integrity, admin-scope probes §21, dataset tests).
8. **Commit as migration data** so the seed is reproducible, not a manual data state.

---

## 27. Scale Estimates

| Entity | Rows (est.) | Notes |
|--------|-------------|-------|
| `regions` total | **~7,300** | 1 + 27 + ~365 (markaz+aqsam) + ~231 cities + ~4,700 villages + ~1,900 new cities/small-settlement administrative rows (new_cities only ~40; remainder villages) |
| `geo_places` | **~2,000–3,000** | ~1,500–2,000 hotels + ~100–300 resorts/tourist villages + ~40–100 tourist cities + ~100–300 landmarks + compounds + settlements |
| `geo_aliases` | **~25,000–40,000** | 3–5 per entity |
| `geo_admin_boundaries` | **~365–4,700** | admin polygons for spatial matching |

- Runtime impact: recursive `is_admin_for_region` walks remain shallow (parent-walk depth ≤ 4);
  indexed. `geo_places`/`geo_aliases` read paths are indexed lookups. No performance concern at
  these scales on Supabase.

---

## 28. Testing

- **Dataset test** (extend `region_dataset_test`): 27 governorates exact; per-level counts within
  source-verified ranges; hierarchy integrity; code uniqueness; deterministic-ID immutability;
  alias presence.
- **Resolver tests:** new-level resolution (markaz/city/village/new_city), alias matching, Arabic
  normalization round-trip, ambiguity → null (never wrong-wins), LOW-confidence gate.
- **Confidence/state tests:** detection never overwrites manual/verified; LOW never persists.
- **Spatial tests:** point-in-governorate/city/markaz; boundary tolerance; coast/border fallback.
- **RLS/security tests:** anon SELECT-only on new tables; admin write gated; no anon write; no
  default-privilege leaks; `is_admin_for_region` returns correct scopes with deeper hierarchy
  (extend Phase 2.2 probe matrix).
- **Migration idempotency test** (030/031 discipline).
- Full `flutter pub get && flutter analyze && flutter test` before any commit.

---

## 29. Missing Data / UNVERIFIED Gaps

- **Markaz/aqsam authoritative Arabic dataset** — needs acquisition per D1 (HDX recommended; CAPMAS
  licensing to clear).
- **Village full list** — CAPMAS authoritative but not freely machine-readable; OCHA level-3 partial.
- **New cities exact roster** — NUCA site is HTML; extract verified; New Galala carve-out noted.
- **Hotels** — no single authoritative public list; hybrid OSM+GeoNames+provider, `UNVERIFIED` until
  provider/boundary cross-check.
- **Boundary polygons** — OCHA/geoBoundaries provide; verification of postgis extension on host
  pending (implementation-time read-only check).
- **Google/Mapbox/HERE keys** — external service configuration (blocked at implementation until
  provided; Photon/OSM path needs none).

---

## 30. Risks

| # | Risk | Sev | Mitigation |
|---|------|-----|------------|
| R1 | Source count discrepancies (markaz 162–190) | Med | D1 locks one canonical source; dataset tests use source-verified ranges; cross-check report |
| R2 | CAPMAS/MLD licensing unclear | Med | Use OCHA/geoBoundaries as load set; legal review before any official-dataset ingestion |
| R3 | Google caching ToS conflict | Med | Google online-only; never cached into canonical tables (architectural rule) |
| R4 | Fabrication temptation / drift into "flat list of businesses" | High | Mandate: `regions` = admin only; `geo_places` = tourism/POIs only; no business listings; provenance columns |
| R5 | Village definition volatility | Med | Import source-confirmed only; `UNVERIFIED` flag; periodic refresh pipeline |
| R6 | PostGIS availability on host | Med | Verify extension before spatial implementation; fallback option C/D without boundaries |
| R7 | Arabic name variants / transliteration drift | Med | Normalized alias table + resolver normalization; alias convergence reviews |
| R8 | Admin-scope regression | Low | Extend Phase 2.2 RLS probe matrix; parent-walk tests; IDs immutable |
| R9 | Import idempotency breakage | Med | Deterministic v5 UUIDs + ON CONFLICT; dataset test asserts ID stability |
| R10 | Scope creep into marketplace listings/POI spam | Med | §14 taxonomy gate; business listings out of scope |

---

## 31. Roadmap — STAGED IMPLEMENTATION (AFTER APPROVAL)

| Step | Work | Gate |
|------|------|------|
| A | **Approve D1/D2/D3** (this document) + assign migration number (next free `032+`; 2.3 contract currently reserves `032` — decide numbering with user) | User decision |
| B | ADR-057 (taxonomy + geo_places + alias model) → DECISION_LOG | ADR |
| C | Migration: extend `regions.type` CHECK, new tables (`geo_places`, `geo_aliases`, `geo_admin_boundaries`) + RLS + grants + indexes | DB change (approved) |
| D | Import admin hierarchy (markaz/aqsam/cities) from OCHA HDX; cross-check counts | Data + validation |
| E | Import villages + new cities (NUCA) | Data + validation |
| F | Import tourism/POI set (hotels/resorts/tourist villages/compounds/landmarks) | Data + validation |
| G | Load admin boundaries + PostGIS spatial RPC (`geo_region_for_point`) | Backend |
| H | Client: GeocodingCandidate + multi-provider reverse geocode proxy + resolution pipeline + confidence/state gates | Flutter |
| I | Tests (dataset/resolver/spatial/RLS/idempotency) + full gate (`flutter analyze`, `flutter test`, live probes) | Pre-commit gate |
| J | Commit + push + Sprint Report + SESSION_STATUS/ROADMAP update | Milestone |

---

## 32. Verdict

🟡 **REQUIRES DATA SOURCE DECISION** — architecture, scale, licensing, and admin-compatibility are
fully verified and implementation-ready. Blocked only on the three explicit approvals in §0.1
(D1 authoritative dataset, D2 geocoder stack, D3 type taxonomy) and the migration-number assignment.
No further research needed; no schema or code changes have been made; Phases 2.1/2.2 untouched.
