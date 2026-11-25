#!/usr/bin/env bash
# 442 harness: applies the REAL migration files 439, 440, 441 and 442 in
# chain order against a freshly created THROWAWAY clone of h435_template
# (psql -f, ON_ERROR_STOP, nothing re-typed), pins the pg_policies rows of
# the four live tables it touches (orders, pos_sales, pos_sale_payments,
# pos_shifts) before vs after, proves the anon/PUBLIC function-execute
# counts are unchanged, then runs the post-apply suite: cross-tenant
# negatives for every RPC, disabled-staff token refusal, append-only
# audit, branch-match triggers, idempotency, payments-sum, discount caps,
# race-safe stock and flag-off defaults.
#
# SAFETY: endpoint host must be exactly localhost/127.0.0.1/[::1]; the
# prod and staging project refs are refused anywhere in the URL;
# requires HARNESS_CONFIRM_DISPOSABLE=yes; the database is CREATE-first
# (name collision retries with a new random name); only the database
# this run created is dropped; PG* redirect variables are unset.
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./442_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
M439="$HERE/../migrations/439_username_login_identifier.sql"
M440="$HERE/../migrations/440_auth_login_identifier.sql"
M441="$HERE/../migrations/441_login_identifier_no_email.sql"
M442="$HERE/../migrations/442_shop_staff_core.sql"
SUITE="$HERE/../tests/442_shop_staff_core_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 442_harness.sh <admin-db-url>}"

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

NEWDB=""
for i in 1 2 3; do
  db="h442_$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  if psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$db\" TEMPLATE $TEMPLATE" >/dev/null 2>&1; then
    CREATED+=("$db")
    NEWDB="$db"
    break
  fi
done
[ -n "$NEWDB" ] || fail_case "could not create database"

BASE_URL="$(printf '%s' "$ADMIN_URL" | sed -E 's#/[^/]*$##')"
DB_URL="$BASE_URL/$NEWDB"

echo "== applying 439, 440, 441 on clone $NEWDB"
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$M439" >/dev/null || fail_case "439 apply failed"
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$M440" >/dev/null || fail_case "440 apply failed"
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$M441" >/dev/null || fail_case "441 apply failed"
echo "pre-chain apply OK"

# ---- pins BEFORE 442 ----
POLICY_SQL="SELECT tablename, policyname, permissive, roles::text, cmd, replace(coalesce(qual,''), E'\\n', ' '), replace(coalesce(with_check,''), E'\\n', ' ')
  FROM pg_policies
 WHERE schemaname='public'
   AND tablename IN ('orders','pos_sales','pos_sale_payments','pos_shifts')
 ORDER BY 1, 2;"
ANON_SQL="SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND has_function_privilege('anon', p.oid, 'EXECUTE');"
PUB_SQL="SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace,
       aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
 WHERE n.nspname = 'public' AND a.grantee = 0 AND a.privilege_type = 'EXECUTE';"

psql "$DB_URL" -X -q -At -c "$POLICY_SQL" > /tmp/.442_policies_before.txt \
  || fail_case "policy dump (before) failed"
ANON_BEFORE="$(psql "$DB_URL" -X -q -At -c "$ANON_SQL")" || fail_case "anon count (before) failed"
PUB_BEFORE="$(psql "$DB_URL" -X -q -At -c "$PUB_SQL")" || fail_case "PUBLIC count (before) failed"

echo "== applying 442"
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$M442" >/dev/null || fail_case "442 apply failed"
echo "442 apply OK"

# ---- pins AFTER 442 ----
psql "$DB_URL" -X -q -At -c "$POLICY_SQL" > /tmp/.442_policies_after.txt \
  || fail_case "policy dump (after) failed"
ANON_AFTER="$(psql "$DB_URL" -X -q -At -c "$ANON_SQL")" || fail_case "anon count (after) failed"
PUB_AFTER="$(psql "$DB_URL" -X -q -At -c "$PUB_SQL")" || fail_case "PUBLIC count (after) failed"

# 1) No pre-existing policy on the four live tables changed or vanished.
REMOVED="$(comm -23 <(sort /tmp/.442_policies_before.txt) <(sort /tmp/.442_policies_after.txt))"
[ -z "$REMOVED" ] || fail_case "442 changed/removed an existing policy: $REMOVED"

# 2) The only new policies are the three staff read policies, and orders
#    gained NONE (staff reach orders through RPCs only).
ADDED="$(comm -13 <(sort /tmp/.442_policies_before.txt) <(sort /tmp/.442_policies_after.txt))"
ADDED_NAMES="$(printf '%s\n' "$ADDED" | awk -F'|' '{print $1 "/" $2}' | sort | tr '\n' ' ')"
[ "$ADDED_NAMES" = "pos_sale_payments/pos_sale_payments_staff_read pos_sales/pos_sales_staff_read pos_shifts/pos_shifts_staff_read " ] \
  || fail_case "unexpected new policies: $ADDED_NAMES"

# 3) anon and PUBLIC execute-counts on public functions are unchanged.
[ "$ANON_BEFORE" = "$ANON_AFTER" ] \
  || fail_case "anon execute-count changed: $ANON_BEFORE -> $ANON_AFTER"
[ "$PUB_BEFORE" = "$PUB_AFTER" ] \
  || fail_case "PUBLIC execute-count changed: $PUB_BEFORE -> $PUB_AFTER"
echo "policy + grant pins OK (anon=$ANON_AFTER, PUBLIC=$PUB_AFTER; added: $ADDED_NAMES)"

echo "== post-apply suite"
OUT="$(psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -At -f "$SUITE" 2>&1)" \
  || fail_case "suite failed: $OUT"
printf '%s\n' "$OUT" | grep -q "442 suite OK" || fail_case "suite marker missing: $OUT"
echo "442 suite OK"
