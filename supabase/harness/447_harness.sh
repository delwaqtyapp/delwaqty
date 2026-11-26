#!/usr/bin/env bash
# 447 harness: applies the REAL migration files 439..447 in chain order
# against a freshly created THROWAWAY clone of h435_template, then pins:
#   - staff_create_walk_in_sale body md5 before 447: exactly the 446
#     pre-image 447's A0 requires;
#   - body md5 after 447: the deterministic post-image;
#   - pg_policies dump before vs after 447: unchanged (447 adds none);
# then runs the 446 suite (regression) and the 447 suite.
#
# SAFETY: identical rules to 446_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random name, only this run's database is dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./447_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
SUITE446="$HERE/../tests/446_product_presets_test.sql"
SUITE447="$HERE/../tests/447_pos_sanity_caps_test.sql"
TEMPLATE="h435_template"
WALKIN_SIG="public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text)"
PRE_MD5="0a9dbbdf895874107de9a754f7d4d3c2"
POST_MD5="10033f4d3c26b3ce646fd3d4ef34347a"

ADMIN_URL="${1:?usage: 447_harness.sh <admin-db-url>}"

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

DB="zz447_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DB")
URL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DB#")"

run() { psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null || fail_case "apply failed: $1"; }

echo "== chain apply 439..446"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -c \
  "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
  || fail_case "could not add local auth.users.encrypted_password stub"
for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased 444_staff_admin_exec 445_cashier_type_gates 446_product_presets; do
  run "$MIG/$m.sql" || exit 2
  echo "$m OK"
done

md5of() { psql "$URL" -X -q -A -t -c "SELECT md5(pg_get_functiondef('$WALKIN_SIG'::regprocedure))"; }

echo "== pre-image pin"
[ "$(md5of)" = "$PRE_MD5" ] || fail_case "walk-in pre-image drifted: $(md5of)"
psql "$URL" -X -q -A -t -c \
  "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies ORDER BY 1,2,3" > /tmp/zz447_policies_before.txt
echo "pre-image pin OK"

echo "== apply 447"
run "$MIG/447_pos_sanity_caps.sql" || exit 2
echo "447 OK"

echo "== post-image pin"
[ "$(md5of)" = "$POST_MD5" ] || fail_case "walk-in post-image wrong: $(md5of)"
psql "$URL" -X -q -A -t -c \
  "SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check FROM pg_policies ORDER BY 1,2,3" > /tmp/zz447_policies_after.txt
diff /tmp/zz447_policies_before.txt /tmp/zz447_policies_after.txt >/dev/null \
  || fail_case "447 changed pg_policies"
echo "post-image pin OK; policies unchanged"

echo "== 446 suite (regression)"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE446" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "446 regression suite failed"; }
printf '%s\n' "$OUT" | grep -q "446 suite OK" || { printf '%s\n' "$OUT"; fail_case "446 suite marker missing"; }
echo "446 suite OK"

echo "== 447 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE447" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "447 suite failed"; }
printf '%s\n' "$OUT" | grep -q "447 suite OK" || { printf '%s\n' "$OUT"; fail_case "447 suite marker missing"; }
echo "447 suite OK"

echo "ALL OK"
