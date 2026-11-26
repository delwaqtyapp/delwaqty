#!/usr/bin/env bash
# 450 harness: applies the REAL migration files in chain order against
# freshly created THROWAWAY clones of h435_template and pins:
#
#   equal behavior: the 450 battery (449's battery re-expressed over the
#   post-450 surfaces, plus the write paths) prints IDENTICAL output on
#   the pre DB (439..451) and the post DB (439..451+450).
#
#   450 suite: tests/450_public_table_select_revokes_test.sql (keep-list
#   positives; negative anon/authenticated coverage of every revoked
#   table and column class; owner/admin write paths; deliveries labels).
#
#   negative apply: a seeded PUBLIC SELECT and an inherited-role SELECT
#   must each abort the apply untouched. Rollback atomicity: a missing
#   snapshot and an unrestorable snapshot row must each abort the
#   rollback WITHOUT any mutation.
#
#   451 suite (regression) runs on the post-450 DB; it was made
#   posture-independent (superuser-captured ids) for exactly this.
#   The 449 suite is NOT run post-450: its section 8 asserts the
#   pre-450 contract (anon base-table reads), which 450 intentionally
#   breaks.
#
#   rollback: rollback/450_public_table_select_revokes_rollback.sql
#   applied after 450 restores the exact pre-450 grants (its own strict
#   postconditions), the 451 signatures survive, and the 450 battery
#   matches the pre-450 output afterwards.
#
# SAFETY: identical rules to 449/451 harnesses (localhost-only URL, prod
# and staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first
# with random names, only this run's databases are dropped, PG* vars
# unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./450_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
TESTS="$HERE/../tests"
RB="$HERE/../rollback"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 450_harness.sh <admin-db-url>}"

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

DBPRE="zz450pre_$(date +%s)_$RANDOM"
DBPOST="zz450post_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPRE\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPRE")
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPOST\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPOST")
URLPRE="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPRE#")"
URLPOST="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPOST#")"

apply_chain_451() {
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
  # 449 runs AFTER the PostGIS posture, exactly as in 449_harness.
  psql "$url" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null \
    || fail_case "apply failed: 449_customer_surface_hardening.sql"
  psql "$url" -X -q -v ON_ERROR_STOP=1 -f "$MIG/451_owner_surface_followups.sql" >/dev/null \
    || fail_case "apply failed: 451_owner_surface_followups.sql"
}

echo "== DB_PRE + DB_POST chain 439..451"
apply_chain_451 "$URLPRE"
apply_chain_451 "$URLPOST"

echo "== apply 450 to DB_POST"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$MIG/450_public_table_select_revokes.sql" >/dev/null \
  || fail_case "apply failed: 450_public_table_select_revokes.sql"
echo "450 OK"

echo "== seed + equal-behavior proof (450 battery identical pre vs post)"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null \
  || fail_case "seed failed on pre DB"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_seed.sql" >/dev/null \
  || fail_case "450 seed failed on pre DB"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null \
  || fail_case "seed failed on post DB"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_seed.sql" >/dev/null \
  || fail_case "450 seed failed on post DB"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_battery.sql" >/tmp/zz450_bat_pre.out 2>/tmp/zz450_bat_pre.err \
  || { cat /tmp/zz450_bat_pre.err;  fail_case "450 battery failed on pre DB"; }
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_battery.sql" >/tmp/zz450_bat_post.out 2>/tmp/zz450_bat_post.err \
  || { cat /tmp/zz450_bat_post.err; fail_case "450 battery failed on post DB"; }
diff /tmp/zz450_bat_pre.out /tmp/zz450_bat_post.out >/dev/null \
  || { diff /tmp/zz450_bat_pre.out /tmp/zz450_bat_post.out | head -30; fail_case "450 battery differs after 450 (not equal behavior)"; }
diff /tmp/zz450_bat_pre.err /tmp/zz450_bat_post.err >/dev/null \
  || { diff /tmp/zz450_bat_pre.err /tmp/zz450_bat_post.err | head -30; fail_case "450 battery stderr differs after 450"; }
echo "equal-behavior proof OK"

echo "== 450 suite (keep-list positives + negatives)"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_public_table_select_revokes_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "450 suite failed"; }
echo "450 suite OK"

echo "== 451 suite (regression) on the post-450 DB"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/451_owner_surface_followups_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "451 suite failed after 450"; }
echo "451 regression OK"

echo "== negative apply: seeded PUBLIC SELECT must abort 450 (A0)"
DBPUB="zz450pub_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPUB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPUB")
URLPUB="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPUB#")"
apply_chain_451 "$URLPUB"
psql "$URLPUB" -X -q -v ON_ERROR_STOP=1 -c "GRANT SELECT ON public.merchants TO PUBLIC" \
  || fail_case "could not seed PUBLIC SELECT"
if psql "$URLPUB" -X -q -v ON_ERROR_STOP=1 -f "$MIG/450_public_table_select_revokes.sql" >/dev/null 2>&1; then
  fail_case "450 applied despite a seeded PUBLIC SELECT"
fi
# the abort must leave the posture untouched (single transaction)
[ "$(psql "$URLPUB" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(c.relacl) x WHERE n.nspname='public' AND c.relname='merchants' AND x.grantee=0 AND x.privilege_type='SELECT'")" = "1" ] \
  || fail_case "PUBLIC-SELECT abort mutated the posture (PUBLIC grant gone)"
[ "$(psql "$URLPUB" -X -q -A -t -c "SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(a.attacl) x WHERE n.nspname='public' AND c.relname IN ('merchants','products') AND x.privilege_type='SELECT'")" = "0" ] \
  || fail_case "PUBLIC-SELECT abort mutated the posture (keep-list leaked)"
[ "$(psql "$URLPUB" -X -q -A -t -c "SELECT md5(pg_get_viewdef('public.deliveries'::regclass))")" = "228af4e1fa465baf165751e3f84fb7a3" ] \
  || fail_case "PUBLIC-SELECT abort mutated the deliveries view"
echo "PUBLIC-SELECT refusal OK"

echo "== negative apply: inherited SELECT via a parent role must abort 450 (A0)"
DBROLE="zz450role_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBROLE\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBROLE")
URLROLE="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBROLE#")"
apply_chain_451 "$URLROLE"
psql "$URLROLE" -X -q -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE zz450_parent NOLOGIN" \
  -c "GRANT zz450_parent TO authenticated" \
  -c "GRANT SELECT ON public.products TO zz450_parent" \
  || fail_case "could not seed inherited SELECT"
if psql "$URLROLE" -X -q -v ON_ERROR_STOP=1 -f "$MIG/450_public_table_select_revokes.sql" >/dev/null 2>&1; then
  fail_case "450 applied despite an inherited SELECT grant"
fi
[ "$(psql "$URLROLE" -X -q -A -t -c "SELECT md5(pg_get_viewdef('public.deliveries'::regclass))")" = "228af4e1fa465baf165751e3f84fb7a3" ] \
  || fail_case "inherited-SELECT abort mutated the deliveries view"
echo "inherited-SELECT refusal OK"

echo "== rollback atomicity: missing snapshot aborts WITHOUT mutating"
DBMISS="zz450miss_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBMISS\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBMISS")
URLMISS="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBMISS#")"
apply_chain_451 "$URLMISS"
psql "$URLMISS" -X -q -v ON_ERROR_STOP=1 -f "$MIG/450_public_table_select_revokes.sql" >/dev/null \
  || fail_case "450 apply failed on the atomicity DB"
psql "$URLMISS" -X -q -v ON_ERROR_STOP=1 -c "DROP TABLE public._450_revoked_grants" \
  || fail_case "could not drop the snapshot for the atomicity case"
if psql "$URLMISS" -X -q -v ON_ERROR_STOP=1 -f "$RB/450_public_table_select_revokes_rollback.sql" >/dev/null 2>&1; then
  fail_case "rollback ran without a snapshot"
fi
# nothing may have mutated: keep-lists still present, no table-level
# SELECT restored, rebuilt deliveries view still in place
[ "$(psql "$URLMISS" -X -q -A -t -c "SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(a.attacl) x WHERE n.nspname='public' AND c.relname IN ('merchants','products') AND a.attname='id' AND x.grantee='authenticated'::regrole AND x.privilege_type='SELECT'")" = "2" ] \
  || fail_case "missing-snapshot rollback mutated the keep-lists"
[ "$(psql "$URLMISS" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(c.relacl) x JOIN pg_roles g ON g.oid=x.grantee WHERE n.nspname='public' AND c.relname IN ('merchants','products','service_providers') AND g.rolname IN ('anon','authenticated') AND x.privilege_type='SELECT'")" = "0" ] \
  || fail_case "missing-snapshot rollback restored table-level SELECT"
[ "$(psql "$URLMISS" -X -q -A -t -c "SELECT count(*) FROM pg_depend d JOIN pg_rewrite rw ON rw.oid=d.objid JOIN pg_class v ON v.oid=rw.ev_class JOIN pg_namespace vn ON vn.oid=v.relnamespace WHERE vn.nspname='public' AND v.relname='deliveries' AND d.refclassid='pg_class'::regclass AND d.refobjid='public.merchants'::regclass")" = "0" ] \
  || fail_case "missing-snapshot rollback touched the deliveries view"
echo "missing-snapshot atomicity OK"

echo "== rollback atomicity: unrestorable snapshot row aborts WITHOUT mutating"
psql "$URLMISS" -X -q -v ON_ERROR_STOP=1 -c \
  "CREATE TABLE public._450_revoked_grants(tbl text NOT NULL, grantee text NOT NULL, privilege text NOT NULL, grantor text NOT NULL, grantable boolean NOT NULL)" \
  -c "INSERT INTO public._450_revoked_grants VALUES ('merchants','anon','SELECT','zz450_no_such_role',false),('merchants','authenticated','SELECT','zz450_no_such_role',false)" \
  || fail_case "could not seed the unrestorable snapshot"
if psql "$URLMISS" -X -q -v ON_ERROR_STOP=1 -f "$RB/450_public_table_select_revokes_rollback.sql" >/dev/null 2>&1; then
  fail_case "rollback ran with an unrestorable snapshot row"
fi
[ "$(psql "$URLMISS" -X -q -A -t -c "SELECT count(*) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(a.attacl) x WHERE n.nspname='public' AND c.relname IN ('merchants','products') AND a.attname='id' AND x.grantee='authenticated'::regrole AND x.privilege_type='SELECT'")" = "2" ] \
  || fail_case "restore-failure rollback mutated the keep-lists"
[ "$(psql "$URLMISS" -X -q -A -t -c "SELECT count(*) FROM public._450_revoked_grants")" = "2" ] \
  || fail_case "restore-failure rollback dropped the snapshot"
echo "restore-failure atomicity OK"

echo "== rollback 450"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$RB/450_public_table_select_revokes_rollback.sql" >/dev/null \
  || fail_case "450 rollback failed"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname IN ('get_my_products_count','get_my_products_by_ids','admin_get_merchants_count') OR (p.proname='get_my_merchant_profile' AND p.pronargs=1))")" = "4" ] \
  || fail_case "rollback dropped a 451 signature"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM public._450_revoked_grants" 2>/dev/null)" = "" ] \
  || fail_case "rollback left the _450_revoked_grants snapshot behind"
echo "rollback pins OK"

echo "== deliveries view restored to the exact pre-image after rollback"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT md5(pg_get_viewdef('public.deliveries'::regclass))")" = "228af4e1fa465baf165751e3f84fb7a3" ] \
  || fail_case "rollback did not restore the deliveries pre-image"

echo "== 450 battery still matches after the rollback"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/450_battery.sql" >/tmp/zz450_bat_rb.out 2>/tmp/zz450_bat_rb.err \
  || { cat /tmp/zz450_bat_rb.err; fail_case "450 battery failed after rollback"; }
diff /tmp/zz450_bat_pre.out /tmp/zz450_bat_rb.out >/dev/null \
  || { diff /tmp/zz450_bat_pre.out /tmp/zz450_bat_rb.out | head -30; fail_case "450 battery differs after rollback"; }
diff /tmp/zz450_bat_pre.err /tmp/zz450_bat_rb.err >/dev/null \
  || { diff /tmp/zz450_bat_pre.err /tmp/zz450_bat_rb.err | head -30; fail_case "450 battery stderr differs after rollback"; }
echo "post-rollback battery OK"

echo "450 HARNESS PASS"
