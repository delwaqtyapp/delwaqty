#!/usr/bin/env bash
# 444 harness: applies the REAL migration files 439, 440, 441, 442, 443
# and 444 in chain order against a freshly created THROWAWAY clone of
# h435_template (psql -f, ON_ERROR_STOP), then pins:
#   - anon / PUBLIC execute-counts on public functions before vs after 444
#     (unchanged: is_cashier_type is SECURITY INVOKER, the executors are
#     granted to authenticated only);
#   - definer-subset execute-counts (prosecdef) before vs after 444
#     (security's B1 baseline: anon=11, PUBLIC=4 on the 443 chain);
#   - public function BODIES by md5 before vs after 444: NO existing
#     function may change (444 only adds);
#   - pg_policies dump before vs after 444: unchanged (444 adds no policies);
#   - users_user_type_check: old pinned definition -> new pinned definition;
# then runs the 442 suite (regression: 444 must not break it) and the 444
# suite (partition pins, executor happy path, audited refusals, grants).
#
# SAFETY: identical rules to 442_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random name, only this run's database is dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./444_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
SUITE442="$HERE/../tests/442_shop_staff_core_test.sql"
SUITE444="$HERE/../tests/444_staff_admin_exec_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 444_harness.sh <admin-db-url>}"

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

DB="zz444_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DB")
URL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DB#")"

run() { psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null || fail_case "apply failed: $1"; }

echo "== chain apply 439..443"
for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased; do
  run "$MIG/$m.sql" || exit 2
  echo "$m OK"
done

snap() {  # $1 = label; prints the three pin streams to /tmp files
  psql "$URL" -X -q -A -t -c "
    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname='public' AND a.privilege_type='EXECUTE'
       AND a.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon');
    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname='public' AND a.privilege_type='EXECUTE' AND a.grantee=0;
    SELECT count(*) FILTER (WHERE a.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon')),
           count(*) FILTER (WHERE a.grantee=0)
       FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
            LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      WHERE n.nspname='public' AND p.prosecdef AND a.privilege_type='EXECUTE';" > "/tmp/zz444_counts_$1.txt"
  psql "$URL" -X -q -A -t -c "
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
           md5(pg_get_functiondef(p.oid))
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       JOIN pg_language l ON l.oid=p.prolang
     WHERE n.nspname='public' AND p.prokind='f' AND l.lanname IN ('sql','plpgsql')
     ORDER BY 1,2,3" > "/tmp/zz444_funcs_$1.txt"
  psql "$URL" -X -q -A -t -c "
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies ORDER BY 1,2,3" > "/tmp/zz444_policies_$1.txt"
}

echo "== pins before 444"
snap before

OLD_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='users_user_type_check' AND conrelid='public.users'::regclass")"
[ "$OLD_CHK" = "CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text, 'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text, 'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text, 'village_admin'::text])))" ] \
  || fail_case "users_user_type_check pre-image drifted: $OLD_CHK"

echo "== apply 444"
run "$MIG/444_staff_admin_exec.sql" || exit 2
echo "444 OK"

NEW_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='users_user_type_check' AND conrelid='public.users'::regclass")"
[ "$NEW_CHK" = "CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text, 'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text, 'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text, 'village_admin'::text, 'merchant_staff'::text])))" ] \
  || fail_case "users_user_type_check post-image wrong: $NEW_CHK"
echo "users_user_type_check old->new pinned OK"

echo "== pins after 444"
snap after

diff <(sort /tmp/zz444_policies_before.txt) <(sort /tmp/zz444_policies_after.txt) >/dev/null \
  || fail_case "pg_policies changed under 444"
echo "policies pin OK"

# anon/PUBLIC flat counts unchanged; definer subset unchanged
diff /tmp/zz444_counts_before.txt /tmp/zz444_counts_after.txt >/dev/null \
  || fail_case "anon/PUBLIC execute counts changed under 444: $(paste -sd' ' /tmp/zz444_counts_before.txt) -> $(paste -sd' ' /tmp/zz444_counts_after.txt)"
echo "anon/PUBLIC counts pin OK ($(paste -sd' ' /tmp/zz444_counts_after.txt))"

# function bodies: 444 may only ADD, never change an existing body
python3 - /tmp/zz444_funcs_before.txt /tmp/zz444_funcs_after.txt <<'PY' || fail_case "an existing function body changed under 444"
import sys
def load(p):
    d = {}
    for line in open(p):
        parts = line.rstrip("\n").split("|")
        if len(parts) == 4:
            d[(parts[0], parts[1], parts[2])] = parts[3]
    return d
before, after = load(sys.argv[1]), load(sys.argv[2])
changed = [k for k in before if k in after and before[k] != after[k]]
gone = [k for k in before if k not in after]
added = sorted(set(after) - set(before))
expected = {("public", "is_cashier_type", "p_type text"),
            ("public", "staff_admin_create_staff", "p_merchant_id uuid, p_auth_user_id uuid, p_username text, p_full_name text, p_role text, p_branch_id uuid, p_phone text, p_login_username text"),
            ("public", "staff_admin_set_active", "p_staff_id uuid, p_active boolean"),
            ("public", "staff_admin_record_password_reset", "p_staff_id uuid"),
            ("public", "staff_admin_audit_refusal", "p_merchant_id uuid, p_reason text")}
if changed or gone or set(added) != expected:
    print("CHANGED:", changed, "GONE:", gone, "ADDED:", added)
    sys.exit(1)
print("function-body pin OK (only the 5 new 444 functions added)")
PY

echo "== 442 suite (regression)"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE442" | grep -q '442 suite OK' \
  || fail_case "442 suite failed under the 444 chain"
echo "442 suite OK"

echo "== 444 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE444" 2>&1)" || { printf '%s\n' "$OUT" | tail -20; fail_case "444 suite failed"; }
echo "444 suite OK"

echo "444 harness ALL OK"
