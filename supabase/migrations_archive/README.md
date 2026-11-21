# Archived migrations 001-214

These are the historical migrations that built the current production schema.
They are superseded by `../migrations/000_baseline.sql` — a clean snapshot of
the live prod schema (public schema DDL, RLS, policies, grants, default ACLs,
realtime publication, auth.users trigger, and the load-bearing
`platform_settings` row) generated from live catalogs on 2026-11-21.

Fresh environments apply: 000_baseline -> 215 -> 216 -> 301..327 (geo seed
chunks, split from archived 032_egypt_geographic_seed.sql for runner timeouts).
Kept for history and provenance; do not re-apply.
