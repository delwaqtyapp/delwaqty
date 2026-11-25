# Migration deployment procedure

How migrations reach an environment, and how to keep the history honest.
All state claims below were verified read-only against the live
management API on 2026-11-25.

## Before applying anything: identify the environment

Run read-only:

    SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;

and classify:

- **No `434` row** (prod: `bttnlkmwhorjamzemwda`): the standard pending
  chain below applies.
- **Has a `434` row** (staging: `adcgqoccrgauqdoplsgg`): 442 and 443
  both abort there by design (442 pins the 393-era guard body, which
  434 already replaced; 443 aborts on the existing
  `whatsapp_otp_number` column). Do NOT force. The supported repair is
  a rebuild from `000_baseline.sql` + the full chain (excluding
  SUPERSEDED versions), since a 434-applied environment has diverged
  from the canonical history anyway. See "Staging" below.

## Applying

1. Apply pending files from `supabase/migrations/` in version order,
   one at a time. `supabase/migrations/` never contains a superseded
   version; archived superseded files live in `supabase/superseded/`
   (see `SUPERSEDED.txt`).
2. Every migration is self-guarding: preconditions (pinned md5s of the
   live functions it replaces, column-absence checks) abort BEFORE any
   mutation when the live state drifted. An abort means stop and
   reconcile, never force.
3. After each apply, record the version in `schema_migrations` (the
   apply tool does this) and run that migration's harness locally
   against a fresh clone when one exists.

## Verified unapplied set on prod (2026-11-25)

Reconciled version-by-version against `schema_migrations` (338 applied
versions), not by maximum, because history has skipped migrations
before (434 itself was skipped by prod).

Pending release chain, in dependency order:

    438 → 439 → 440 → 441 → 442 → 443

- 438 (`service_category_alias_canonicalization`): independent.
- 439 (`username_login_identifier`): case-insensitive username login.
- 440 (`auth_login_identifier`): depends on 439 — its server-side
  resolution replaces the client-side lookup flow 439 introduced.
- 441 (`login_identifier_no_email`): depends on 440 — it changes
  `auth_login_resolve_email`, which 440 creates.
- 442 (`shop_staff_core`): after 441 (numeric chain order; no shared
  objects). DARK, flag-gated; apply only on an explicit owner order.
- 443 (`whatsapp_otp_number_rebased`): strictly after 442 — it pins
  the 442 guard body and replaces it with one covering both
  `feature_flags` and `whatsapp_otp_number`.

Not in the chain:

- `000_baseline.sql`: fresh-environment bootstrap only; never applied
  to prod (prod's history starts at `001_initial_schema`).
- `301_geo_seed_01` … `326_geo_seed_26`: idempotent (`ON CONFLICT DO
  NOTHING`) region seeds generated FROM live prod (2026-11-21). Prod
  never recorded them in `schema_migrations` but already carries the
  data (`regions` = 6157 rows, verified 2026-11-25). Applying them is
  a safe no-op; skipping them changes nothing. Excluded from the
  release chain either way.
- `434_whatsapp_otp_number.sql`: SUPERSEDED, archived at
  `supabase/superseded/`. Never apply; apply 443 instead.

## Staging

Staging (`adcgqoccrgauqdoplsgg`) has 434 applied (verified 2026-11-25;
its applied history is short and divergent — 22 versions). It is not a
mirror of prod. Until it is rebuilt from `000_baseline.sql` + the full
chain, it cannot take 442 or 443, and results from it do not represent
the prod apply path. Rebuild when a faithful staging mirror is needed;
there is no supported incremental repair for a 434-applied
environment.
