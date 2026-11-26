# Supabase Advisors after migration batches

Run the Supabase Advisors (security + performance lints) after every
migration batch is applied to production, and attach the full JSON to
the release report for the security reviewer's post-apply sweep.

## How

    GET https://api.supabase.com/v1/projects/{project_ref}/advisors/security
    GET https://api.supabase.com/v1/projects/{project_ref}/advisors/performance

authenticated with a Supabase access token for the project.

## Policy

Nothing gains blanket approval from this document. The dated snapshot in
`docs/security/advisors-2026-11-26-security.json` (and
`-performance.json`) is a record of what the advisors reported on
2026-11-26, not an acceptance of it.

On every batch, compare the fresh run against the latest dated snapshot
and report to the security reviewer:

- every NEW finding (object + finding + severity not in the snapshot),
- every CHANGED finding on an object the batch created or replaced
  (grants, definition, exposed columns, severity),
- every finding whose severity increased.

Unchanged findings may be summarized as "unchanged vs the
YYYY-MM-DD snapshot" with a count, not suppressed.

## Dated baseline observed 2026-11-26 (post 438-446 batch)

Machine-readable: `docs/security/advisors-2026-11-26-security.json`,
`docs/security/advisors-2026-11-26-performance.json`.

Security run totals: 3 ERROR, 447 WARN, 25 INFO. Notes on specific
objects, with their status as of 2026-11-26:

- `public.app_public_config` and `public.merchant_storefront`
  (ERROR, `security_definer_view`): PRE-EXISTING, UNREVIEWED. Both come
  from `supabase/migrations/000_baseline.sql`; no grounded acceptance
  (memory, decision file or repo doc) was found as of 2026-11-26.
  Exposed columns checked live on 2026-11-26 against the baseline:
  `app_public_config` exposes id, app_name, support_email,
  support_phone, maintenance_mode, min_app_version_android,
  min_app_version_ios, require_provider_documents. `merchant_storefront`
  exposes id, name, type, status, description, logo_url, cover_url,
  address, latitude, longitude, rating, total_reviews, delivery_fee,
  min_order, delivery_time_min, is_featured, is_open for active
  merchants only. Neither exposes whatsapp_otp_number, feature_flags or
  staff_settings. These selections look intentional for public surfaces,
  but that is an observation, not an approval: the views stay on the
  report list until the security reviewer accepts or fixes them.
- `public.spatial_ref_sys` (ERROR, `rls_disabled_in_public`): PostGIS
  system table, not platform-owned; still reported.
- 447 WARN are dominated by `function_search_path_mutable` on legacy
  baseline functions and `authenticated_security_definer_function_executable`
  on RPCs. The staff/POS RPCs from 438-446 are SECURITY DEFINER with
  in-function authorization by design and appear in this WARN list; the
  design intent is recorded in the migrations and PR bodies, and the
  WARNs are still listed in the snapshot and diffed every batch.
- 25 INFO `rls_enabled_no_policy` cover service-role-only tables
  (auth_login_attempts, staff_provisioning, staff_admin_refusals,
  whatsapp_otp_verifications, wallet/credit ledgers, ...). Zero policies
  means zero direct client access there; still listed and diffed.
