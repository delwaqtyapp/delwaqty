#!/usr/bin/env bash
# 451 harness: applies the REAL migration files in chain order against
# freshly created THROWAWAY clones of h435_template and pins:
#
#   additive proof: the 449 equal-behavior battery prints IDENTICAL output
#   on the pre-451 DB (439..449) and the post-451 DB (439..451).
#
#   451 suite: tests/451_owner_surface_followups_test.sql (positive +
#   negative owner/staff/other-user/anon coverage of every 451 signature).
#
#   rollback: rollback/451_owner_surface_followups_rollback.sql applied
#   after 451 leaves the 449 zero-arg get_my_merchant_profile byte-
#   identical (md5 pin), removes exactly the 451 signatures, and the 449
#   battery still matches the pre-451 output afterwards.
#
#   449 suite (regression) runs on the post-451 DB.
#
# SAFETY: identical rules to 449_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random names, only this run's databases are dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./451_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
TESTS="$HERE/../tests"
RB="$HERE/../rollback"
TEMPLATE="h435_template"
PROFILE449_MD5="93a34d4eba42dddd85c5af26b1c5c8bb"

ADMIN_URL="${1:?usage: 451_harness.sh <admin-db-url>}"

fail_safety() { echo "SAFETY REFUSAL: $1" >&2; exit 1; }
fail_case() { echo "CASE FAILURE: $1" >&2; exit 2; }

[ "${HARNESS_CONFIRM_DISPOSABLE:-}" = "yes" ] \
  || fail_safety "set HARNESS_CONFIRM_DISPOSABLE=yes to confirm disposable databases"

case "$ADMIN_URL" in
  *bttnlkmwhorjamzemwda*) fail_safety "PROD project ref detected in target URL";;
  *adcgqoccrgauqdoplsgg*) fail_safety "staging project ref detected; staging is not disposable";;
esac
case "$ADMIN_URL" in
  *\?*|*'&'*|*'#'*) fail_safety "URI query parameters and fragments are not allowed";;
esac
for V in PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE PGPASSFILE PGOPTIONS PGCONNECT_TIMEOUT PGSSLMODE PGTARGETSESSIONATTRS; do
  unset "$V" || true
done

HOSTPORT="$(printf '%s' "$ADMIN_URL" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/@]*@)?([^/]*)/.*$#\2#')"
HOST="$(printf '%s' "$HOSTPORT" | sed -E 's/^(\[[0-9a-fA-F:]+\]|[^:]+)(:[0-9]+)?$/\1/')"
case "$HOST" in
  localhost|127.0.0.1|"[::1]") ;;
  *) fail_safety "host must be exactly localhost, 127.0.0.1 or [::1], got: $HOST";;
esac

CREATED=()
cleanup() { for db in "${CREATED[@]:-}"; do [ -n "$db" ] && psql "$ADMIN_URL" -X -q -c "DROP DATABASE IF EXISTS \"$db\"" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT

DBPRE="zz451pre_$(date +%s)_$RANDOM"
DBPOST="zz451post_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPRE\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPRE")
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPOST\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPOST")
URLPRE="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPRE#")"
URLPOST="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPOST#")"

apply_chain_449() {
  local url="$1"
  psql "$url" -X -q -v ON_ERROR_STOP=1 -c \
    "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
    || fail_case "could not add local auth.users.encrypted_password stub"
  local m
  for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased 444_staff_admin_exec 445_cashier_type_gates 446_product_presets 447_pos_sanity_caps 448_db_hardening_anon_surface; do
    psql "$url" -X -q -v ON_ERROR_STOP=1 -f "$MIG/$m.sql" >/dev/null \
      || fail_case "apply failed: $m.sql"
  done
  # Reproduce PROD's PostGIS posture (security review requirement), same
  # as 449_harness: supabase_admin-granted ALL for anon+authenticated.
  psql "$url" -X -q -v ON_ERROR_STOP=1 -c "
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns TO supabase_admin WITH GRANT OPTION;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns TO supabase_admin WITH GRANT OPTION;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys TO supabase_admin WITH GRANT OPTION;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns FROM anon, authenticated;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns FROM anon, authenticated;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys FROM anon, authenticated;
    SET ROLE supabase_admin;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns TO anon, authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns TO anon, authenticated;
    SET ROLE supabase_admin;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys TO anon, authenticated;
    RESET ROLE;" || fail_case "could not simulate prod PostGIS posture"
  # 449 runs AFTER the PostGIS posture, exactly as in 449_harness.sh: its
  # guarded per-catalog revoke attempts must see the prod-like grants.
  psql "$url" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null     || fail_case "apply failed: 449_customer_surface_hardening.sql"
}

echo "== DB_PRE + DB_POST chain 439..449"
apply_chain_449 "$URLPRE"
apply_chain_449 "$URLPOST"

echo "== apply 451 to DB_POST"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$MIG/451_owner_surface_followups.sql" >/dev/null \
  || fail_case "apply failed: 451_owner_surface_followups.sql"
echo "451 OK"

echo "== seed + additive proof (449 battery identical pre vs post 451)"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null   || fail_case "seed failed on pre DB"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null   || fail_case "seed failed on post DB"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_battery.sql" >/tmp/zz451_bat_pre.out 2>/tmp/zz451_bat_pre.err \
  || { cat /tmp/zz451_bat_pre.err;  fail_case "449 battery failed on pre DB"; }
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_battery.sql" >/tmp/zz451_bat_post.out 2>/tmp/zz451_bat_post.err \
  || { cat /tmp/zz451_bat_post.err; fail_case "449 battery failed on post DB"; }
diff /tmp/zz451_bat_pre.out /tmp/zz451_bat_post.out >/dev/null \
  || { diff /tmp/zz451_bat_pre.out /tmp/zz451_bat_post.out | head -30; fail_case "449 battery differs after 451 (not additive)"; }
diff /tmp/zz451_bat_pre.err /tmp/zz451_bat_post.err >/dev/null \
  || { diff /tmp/zz451_bat_pre.err /tmp/zz451_bat_post.err | head -30; fail_case "449 battery stderr differs after 451"; }
echo "additive proof OK"

echo "== 451 suite (positive + negative owner/staff/other-user/anon)"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/451_owner_surface_followups_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "451 suite failed"; }
echo "451 suite OK"

echo "== 449 suite (regression) on the post-451 DB"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_customer_surface_hardening_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "449 suite failed after 451"; }
echo "449 regression OK"

echo "== rollback 451"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$RB/451_owner_surface_followups_rollback.sql" >/dev/null \
  || fail_case "451 rollback failed"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT md5(pg_get_functiondef('public.get_my_merchant_profile()'::regprocedure))")" = "$PROFILE449_MD5" ] \
  || fail_case "rollback did not preserve the 449 zero-arg profile"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname IN ('get_my_products_count','get_my_products_by_ids','admin_get_merchants_count') OR (p.proname='get_my_merchant_profile' AND p.pronargs=1))")" = "0" ] \
  || fail_case "rollback left 451 signatures behind"
echo "rollback pins OK"

echo "== 449 battery still matches after the rollback"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_battery.sql" >/tmp/zz451_bat_rb.out 2>/tmp/zz451_bat_rb.err \
  || { cat /tmp/zz451_bat_rb.err; fail_case "449 battery failed after rollback"; }
diff /tmp/zz451_bat_pre.out /tmp/zz451_bat_rb.out >/dev/null \
  || { diff /tmp/zz451_bat_pre.out /tmp/zz451_bat_rb.out | head -30; fail_case "449 battery differs after rollback"; }
diff /tmp/zz451_bat_pre.err /tmp/zz451_bat_rb.err >/dev/null \
  || { diff /tmp/zz451_bat_pre.err /tmp/zz451_bat_rb.err | head -30; fail_case "449 battery stderr differs after rollback"; }
echo "post-rollback battery OK"

echo "451 HARNESS PASS"
