#!/usr/bin/env bash
# 446 harness: applies the REAL migration files 439..446 in chain order
# against a freshly created THROWAWAY clone of h435_template, then pins:
#   - merchants_type_check: 435's 43-value definition -> 445's 44-value
#     definition (explicit old/new strings, condition 5);
#   - the type partition: every merchants_type_check value is in EXACTLY
#     ONE of is_cashier_type / is_simple_service_type (condition 2);
#   - function bodies before vs after 445: ONLY staff_shift_open,
#     staff_create_walk_in_sale, staff_shift_close and is_cashier_type may
#     change; ONLY is_simple_service_type and _assert_staff_settings_shape
#     may be added; nothing may disappear;
#   - pg_policies dump before vs after 445: unchanged (445 adds none);
# then runs the 442 + 444 suites (regression) and the 445 suite.
#
# SAFETY: identical rules to 444_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random name, only this run's database is dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./446_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
SUITE442="$HERE/../tests/442_shop_staff_core_test.sql"
SUITE444="$HERE/../tests/444_staff_admin_exec_test.sql"
SUITE445="$HERE/../tests/445_cashier_type_gates_test.sql"
SUITE446="$HERE/../tests/446_product_presets_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 446_harness.sh <admin-db-url>}"

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

DB="zz446_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DB")
URL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DB#")"

run() { psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null || fail_case "apply failed: $1"; }

echo "== chain apply 439..445"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -c \
  "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
  || fail_case "could not add local auth.users.encrypted_password stub"
for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased 444_staff_admin_exec 445_cashier_type_gates; do
  run "$MIG/$m.sql" || exit 2
  echo "$m OK"
done

snap() {  # $1 = label
  psql "$URL" -X -q -A -t -c "
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
           md5(pg_get_functiondef(p.oid))
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       JOIN pg_language l ON l.oid=p.prolang
     WHERE n.nspname='public' AND p.prokind='f' AND l.lanname IN ('sql','plpgsql')
     ORDER BY 1,2,3" > "/tmp/zz446_funcs_$1.txt"
  psql "$URL" -X -q -A -t -c "
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies ORDER BY 1,2,3" > "/tmp/zz446_policies_$1.txt"
}

echo "== pins before 446"
snap before

CHK445="CHECK ((type = ANY (ARRAY['food'::text, 'restaurant'::text, 'grocery'::text, 'supermarket'::text, 'electronics'::text, 'fashion'::text, 'flowers'::text, 'bakery'::text, 'general'::text, 'fruits'::text, 'meat'::text, 'seafood'::text, 'sweets'::text, 'clothing'::text, 'shoes'::text, 'mobile'::text, 'furniture'::text, 'home'::text, 'cafe'::text, 'petShop'::text, 'fitness'::text, 'gas'::text, 'carwash'::text, 'perfumes'::text, 'spices'::text, 'dairy'::text, 'accessories'::text, 'butcher'::text, 'vegetables'::text, 'service'::text, 'home_services'::text, 'plumbing'::text, 'electrical'::text, 'cleaning'::text, 'handyman'::text, 'carpentry'::text, 'ac_maintenance'::text, 'painting'::text, 'pest_control'::text, 'appliance_repair'::text, 'doctor'::text, 'clinic'::text, 'other'::text, 'juice_shop'::text])))"
OLD_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='merchants_type_check' AND conrelid='public.merchants'::regclass")"
[ "$OLD_CHK" = "$CHK445" ] || fail_case "merchants_type_check pre-image drifted: $OLD_CHK"
OLD_KIND="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='merchant_staff_events_kind_check' AND conrelid='public.merchant_staff_events'::regclass")"
[ "$OLD_KIND" = "CHECK ((kind = ANY (ARRAY['created'::text, 'role_changed'::text, 'branch_changed'::text, 'disabled'::text, 'enabled'::text, 'password_reset'::text, 'walk_in_sale'::text, 'void_sale'::text, 'debt_payment'::text, 'shift_opened'::text, 'shift_closed'::text, 'order_status'::text, 'refused'::text, 'password_changed'::text])))" ] \
  || fail_case "merchant_staff_events_kind_check pre-image drifted: $OLD_KIND"

echo "== apply 446"
run "$MIG/446_product_presets.sql" || exit 2
echo "446 OK"

NEW_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='merchants_type_check' AND conrelid='public.merchants'::regclass")"
[ "$NEW_CHK" = "$CHK445" ] || fail_case "446 changed merchants_type_check"
NEW_KIND="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='merchant_staff_events_kind_check' AND conrelid='public.merchant_staff_events'::regclass")"
[ "$NEW_KIND" = "CHECK ((kind = ANY (ARRAY['created'::text, 'role_changed'::text, 'branch_changed'::text, 'disabled'::text, 'enabled'::text, 'password_reset'::text, 'walk_in_sale'::text, 'void_sale'::text, 'debt_payment'::text, 'shift_opened'::text, 'shift_closed'::text, 'order_status'::text, 'refused'::text, 'password_changed'::text, 'preset_applied'::text, 'preset_removed'::text])))" ] \
  || fail_case "merchant_staff_events_kind_check post-image wrong: $NEW_KIND"
echo "CHECK pins OK (type unchanged; kind +preset kinds)"

echo "== partition pin (regression)"
PART="$(psql "$URL" -X -q -A -t <<'SQL'
WITH vals AS (
  SELECT (regexp_matches(
    (SELECT pg_get_constraintdef(oid) FROM pg_constraint
      WHERE conname='merchants_type_check' AND conrelid='public.merchants'::regclass),
    '''([A-Za-z_]+)''::text', 'g'))[1] AS t
)
SELECT string_agg(t, ',' ORDER BY t) FROM vals
 WHERE (public.is_cashier_type(t))::int + (public.is_simple_service_type(t))::int <> 1;
SQL
)"
[ -z "$PART" ] || fail_case "partition not exhaustive/disjoint for: $PART"
NVALS="$(psql "$URL" -X -q -A -t -c "
SELECT count(*) FROM (SELECT (regexp_matches(
  (SELECT pg_get_constraintdef(oid) FROM pg_constraint
    WHERE conname='merchants_type_check' AND conrelid='public.merchants'::regclass),
  '''([A-Za-z_]+)''::text', 'g'))[1] AS t) x")"
[ "$NVALS" = "44" ] || fail_case "expected 44 CHECK values, got $NVALS"
echo "partition pin OK (44 values, exactly one list each)"

echo "== pins after 446"
snap after

diff <(sort /tmp/zz446_policies_before.txt) <(sort /tmp/zz446_policies_after.txt) >/dev/null \
  || fail_case "pg_policies changed under 445"
echo "policies pin OK"

python3 - /tmp/zz446_funcs_before.txt /tmp/zz446_funcs_after.txt <<'PY' || fail_case "unexpected function-body change under 446"
import sys
def load(p):
    d = {}
    for line in open(p):
        parts = line.rstrip("\n").split("|")
        if len(parts) == 4:
            d[(parts[0], parts[1], parts[2])] = parts[3]
    return d
before, after = load(sys.argv[1]), load(sys.argv[2])
changed = sorted(k for k in before if k in after and before[k] != after[k])
gone = [k for k in before if k not in after]
added = sorted(set(after) - set(before))
expected_changed = sorted([
    ("public", "staff_create_walk_in_sale", "p_items jsonb, p_payments jsonb, p_client_op_id uuid, p_discount numeric, p_pos_customer_id uuid, p_branch_id uuid, p_notes text"),
])
expected_added = sorted([
    ("public", "_resolve_owned_merchant", "p_merchant_id uuid"),
    ("public", "merchant_apply_preset", "p_preset text, p_merchant_id uuid"),
    ("public", "merchant_remove_preset", "p_preset text, p_merchant_id uuid"),
])
if changed != expected_changed or gone or added != expected_added:
    print("CHANGED:", changed, "GONE:", gone, "ADDED:", added)
    sys.exit(1)
print("function-body pin OK (1 replaced pinned, 3 added)")
PY

echo "== 442 suite (regression)"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE442" | grep -q '442 suite OK' \
  || fail_case "442 suite failed under the 445 chain"
echo "442 suite OK"

echo "== 444 suite (regression)"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE444" 2>&1)" || { printf '%s\n' "$OUT" | tail -20; fail_case "444 suite failed under the 445 chain"; }
echo "444 suite OK"

echo "== 445 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE445" 2>&1)" || { printf '%s\n' "$OUT" | tail -25; fail_case "445 suite failed"; }
printf '%s\n' "$OUT" | grep -q '445 suite OK' || fail_case "445 suite marker missing"
echo "445 suite OK"

echo "== 446 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE446" 2>&1)" || { printf '%s\n' "$OUT" | tail -25; fail_case "446 suite failed"; }
printf '%s\n' "$OUT" | grep -q '446 suite OK' || fail_case "446 suite marker missing"
echo "446 suite OK"

echo "446 harness ALL OK"
