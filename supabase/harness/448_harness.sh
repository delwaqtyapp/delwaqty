#!/usr/bin/env bash
# 448 harness: applies the REAL migration files 439..448 in chain order
# against a freshly created THROWAWAY clone of h435_template, then pins:
#   - the 3 re-pointed function bodies before 448: exactly the A0 pins
#     448 requires (post-447 walk-in-sale, 445 shape check, 446 audit);
#   - body md5s after 448: the deterministic post-images;
#   - pg_policies on every table except the new merchant_staff_settings:
#     unchanged; the new table carries exactly its one owner policy;
#   - anon grant sweep: no INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER left;
#   - anon wildcard SELECT on merchants STILL WORKS (guest browse);
# then runs the 447 suite (regression) and the 448 suite.
# NOTE: the 445/446 suites are NOT re-run: their fixtures write the
# merchants.staff_settings column that 448 deliberately drops. The 448
# suite re-tests that surface (shape, audit, custom-line gate) through
# the new table.
#
# SAFETY: identical rules to 446_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random name, only this run's database is dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./448_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
SUITE447="$HERE/../tests/447_pos_sanity_caps_test.sql"
SUITE448="$HERE/../tests/448_db_hardening_anon_surface_test.sql"
TEMPLATE="h435_template"
WALKIN_SIG="public.staff_create_walk_in_sale(jsonb, jsonb, uuid, numeric, uuid, uuid, text)"
PRE_MD5="c081f5c008cc826e5454b54949a10751"
POST_MD5="4fd44b7b9606d831f963ba5c0a9e7310"
SHAPE_SIG="public._assert_staff_settings_shape()"
SHAPE_PRE_MD5="453b7496ce33d38898d9bd6295a82075"
AUDIT_SIG="public._audit_staff_settings_change()"
AUDIT_PRE_MD5="df28bf803c3ac6e47b994929bb6b91fc"

ADMIN_URL="${1:?usage: 448_harness.sh <admin-db-url>}"

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

DB="zz448_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DB")
URL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DB#")"

run() { psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null || fail_case "apply failed: $1"; }

echo "== chain apply 439..447"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -c \
  "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
  || fail_case "could not add local auth.users.encrypted_password stub"
for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased 444_staff_admin_exec 445_cashier_type_gates 446_product_presets 447_pos_sanity_caps; do
  run "$MIG/$m.sql" || exit 2
  echo "$m OK"
done

md5of() { psql "$URL" -X -q -A -t -c "SELECT md5(pg_get_functiondef('$WALKIN_SIG'::regprocedure))"; }

md5sig() { psql "$URL" -X -q -A -t -c "SELECT md5(pg_get_functiondef('$1'::regprocedure))"; }

echo "== pre-image pins"
[ "$(md5of)" = "$PRE_MD5" ] || fail_case "walk-in pre-image drifted: $(md5of)"
[ "$(md5sig "$SHAPE_SIG")" = "$SHAPE_PRE_MD5" ] || fail_case "shape pre-image drifted: $(md5sig "$SHAPE_SIG")"
[ "$(md5sig "$AUDIT_SIG")" = "$AUDIT_PRE_MD5" ] || fail_case "audit pre-image drifted: $(md5sig "$AUDIT_SIG")"
psql "$URL" -X -q -A -t -c \
  "SELECT schemaname, tablename, policyname, permissive, roles, cmd, replace(qual::text, chr(10), ' '), replace(with_check::text, chr(10), ' ') FROM pg_policies ORDER BY 1,2,3" > /tmp/zz448_policies_before.txt
psql "$URL" -X -q -A -t -c \
  "SELECT table_name, grantee, privilege_type FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee IN ('anon','authenticated') ORDER BY 1,2,3" > /tmp/zz448_grants_before.txt
echo "pre-image pins OK"

echo "== apply 448"
run "$MIG/448_db_hardening_anon_surface.sql" || exit 2
echo "448 OK"

echo "== post-image pin"
[ "$(md5of)" = "$POST_MD5" ] || fail_case "walk-in post-image wrong: $(md5of)"
echo "post-image pin OK"

echo "== policies: only merchant_staff_settings added"
psql "$URL" -X -q -A -t -c \
  "SELECT schemaname, tablename, policyname, permissive, roles, cmd, replace(qual::text, chr(10), ' '), replace(with_check::text, chr(10), ' ') FROM pg_policies ORDER BY 1,2,3" > /tmp/zz448_policies_after.txt
diff /tmp/zz448_policies_before.txt /tmp/zz448_policies_after.txt > /tmp/zz448_policies.diff || true
ADDED="$(grep -c '^>' /tmp/zz448_policies.diff || true)"
REMOVED="$(grep -c '^<' /tmp/zz448_policies.diff || true)"
[ "$REMOVED" = "0" ] || fail_case "448 removed policies: $(grep '^<' /tmp/zz448_policies.diff)"
[ "$ADDED" = "1" ] || fail_case "448 added $ADDED policies, expected exactly 1"
grep '^>' /tmp/zz448_policies.diff | grep -q 'merchant_staff_settings' \
  || fail_case "the added policy is not on merchant_staff_settings"
echo "policies OK (+1 owner policy on merchant_staff_settings)"

echo "== anon grant sweep"
psql "$URL" -X -q -A -t -c \
  "SELECT table_name, grantee, privilege_type FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee IN ('anon','authenticated') ORDER BY 1,2,3" > /tmp/zz448_grants_after.txt
LEFT="$(psql "$URL" -X -q -A -t -c \
  "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee='anon' AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE','TRIGGER')")"
[ "$LEFT" = "0" ] || fail_case "anon still holds $LEFT write-class grants"
echo "anon sweep OK (0 write-class grants left; sweeps in /tmp/zz448_grants_{before,after}.txt)"

echo "== anon wildcard merchants read still works (guest browse)"
N="$(psql "$URL" -X -q -A -t -c "SET ROLE anon; SET LOCAL request.jwt.claims='{}'; SELECT count(*) FROM public.merchants")" \
  || fail_case "anon wildcard SELECT on merchants broke in 448"
echo "anon merchants wildcard read OK ($N rows visible through RLS)"

echo "== 447 suite (regression)"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE447" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "447 regression suite failed"; }
printf '%s\n' "$OUT" | grep -q "447 suite OK" || { printf '%s\n' "$OUT"; fail_case "447 suite marker missing"; }
echo "447 suite OK"

echo "== 448 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE448" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "448 suite failed"; }
printf '%s\n' "$OUT" | grep -q "448 suite OK" || { printf '%s\n' "$OUT"; fail_case "448 suite marker missing"; }
echo "448 suite OK"

echo "ALL OK"
