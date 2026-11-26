# Supabase Advisors after migration batches

Run the Supabase Advisors (security + performance lints) after every
migration batch is applied to production, and attach the result to the
release report for the security reviewer's post-apply sweep.

## How

    GET https://api.supabase.com/v1/projects/{project_ref}/advisors/security
    GET https://api.supabase.com/v1/projects/{project_ref}/advisors/performance

with the Supabase access token (Instinct's vault, or a personal access
token with the project).

## Baseline (known, accepted — do not re-report as new)

- `rls_enabled_no_policy` (INFO) on service-role-only tables
  (auth_login_attempts, staff_provisioning, staff_admin_refusals,
  whatsapp_otp_verifications, wallet/credit ledgers, ...): intentional.
  These tables are written only by SECURITY DEFINER functions and the
  service role; zero policies means zero direct client access.
- `authenticated_security_definer_function_executable` (WARN) on the
  staff/POS RPCs (staff_shift_open, staff_create_walk_in_sale,
  merchant_apply_preset, ...): by design. These are SECURITY DEFINER so
  RLS on underlying tables can stay deny-all; authorization happens
  inside each function (owner or scoped staff checks, feature flags).
- `security_definer_view` (ERROR) on `app_public_config` and
  `merchant_storefront`: pre-existing baseline, intentionally
  anon-readable public surfaces.
- `rls_disabled_in_public` (ERROR) on `spatial_ref_sys`: PostGIS system
  table, not ours.
- `function_search_path_mutable` (WARN) on legacy baseline functions:
  tracked separately; new functions must SET search_path.

## What is reportable

Any finding whose subject is an object created or replaced by the batch
that is NOT in the baseline list above, and any new ERROR regardless of
subject.
