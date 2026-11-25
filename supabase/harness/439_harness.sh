#!/usr/bin/env bash
# 439 harness: executes the EXACT migration file
# supabase/migrations/439_username_login_identifier.sql against freshly
# created THROWAWAY databases with legacy fixtures seeded BEFORE apply,
# proving: (1) clean apply keeps existing valid usernames and builds the
# case-insensitive index, (2) an existing format-invalid name aborts
# with diagnostics, (3) a case-fold collision aborts, (4) an all-digit
# phone-shaped name aborts, and every abort leaves the original index
# definition intact (full rollback). Nothing is re-typed: the real file
# is applied with psql -f under ON_ERROR_STOP.
#
# SAFETY: endpoint host must be exactly localhost/127.0.0.1/[::1]; the
# prod and staging project refs are refused anywhere in the URL;
# requires HARNESS_CONFIRM_DISPOSABLE=yes; databases are CREATE-first
# (name collision retries with a new random name); only databases this
# run created are dropped; PG* redirect variables are unset.
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./439_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 all pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/439_username_login_identifier.sql"
SUITE="$HERE/../tests/439_username_login_identifier_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 439_harness.sh <admin-db-url>}"

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

PSQL="psql $ADMIN_URL -v ON_ERROR_STOP=1 -X -q -At"
CREATED=()
cleanup() { for db in "${CREATED[@]:-}"; do [ -n "$db" ] && psql "$ADMIN_URL" -X -q -c "DROP DATABASE IF EXISTS \"$db\"" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT

newdb() {
  # Sets NEWDB in the PARENT shell (never call in a subshell: CREATED
  # and the result must survive). Retries on a name collision.
  local db i
  for i in 1 2 3; do
    db="h439_$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    if psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$db\" TEMPLATE $TEMPLATE" >/dev/null 2>&1; then
      CREATED+=("$db")
      NEWDB="$db"
      return 0
    fi
  done
  return 1
}


BASE_URL="$(printf '%s' "$ADMIN_URL" | sed -E 's#/[^/]*$##')"

psql_db() { local db="$1"; shift; psql "$BASE_URL/$db" -X -q -At -v ON_ERROR_STOP=1 "$@"; }

OLD_IDX='CREATE UNIQUE INDEX users_username_unique_idx ON public.users USING btree (username) WHERE (username IS NOT NULL)'
NEW_IDX='CREATE UNIQUE INDEX users_username_unique_idx ON public.users USING btree (lower(username)) WHERE (username IS NOT NULL)'

seed_user() { # db email username_sql account_status
  psql_db "$1" -c "insert into auth.users(id,email) values (gen_random_uuid(), '$2')" >/dev/null \
    && psql_db "$1" -c "update public.users set email='$2', username=$3, account_status='${4:-active}' where email='$2'" >/dev/null \
    || fail_case "fixture insert failed ($2)"
}

# Cleanup proof mode: create one clone, then fail. The EXIT trap must
# drop it; verified externally by counting h439_* databases afterwards.
if [ "${H439_FORCE_FAIL_AFTER_CREATE:-}" = "yes" ]; then
  newdb || fail_case "could not create database"
  echo "forced failure with clone $NEWDB still open"
  fail_case "forced failure for cleanup proof"
fi

echo "== case 1: clean apply keeps valid names, builds lower() index"
newdb || fail_case "could not create case-1 database"
DB1="$NEWDB"
seed_user "$DB1" 'legacy.one@example.invalid' "'LegacyUser'"
seed_user "$DB1" 'phone_201000000099@delwaqty.app' "NULL"
seed_user "$DB1" 'deleted-00000000-0000-4000-8000-000000000439@anonymized.invalid' "NULL"
psql_db "$DB1" -f "$MIG" >/dev/null || fail_case "clean apply failed"
IDX="$(psql_db "$DB1" -c "SELECT indexdef FROM pg_indexes WHERE indexname='users_username_unique_idx'")"
[ "$IDX" = "$NEW_IDX" ] || fail_case "index not rebuilt: $IDX"
[ "$(psql_db "$DB1" -c "SELECT username FROM public.users WHERE email='legacy.one@example.invalid'")" = "LegacyUser" ] \
  || fail_case "existing valid username not preserved"
psql_db "$DB1" -f "$SUITE" >/dev/null || fail_case "post-apply suite failed"
echo "case 1 OK"

echo "== case 2: invalid legacy name aborts with diagnostics"
newdb || fail_case "could not create case-2 database"
DB2="$NEWDB"
seed_user "$DB2" 'john.doe@example.invalid' "'john.doe'"
OUT="$(psql_db "$DB2" -f "$MIG" 2>&1)" && fail_case "apply must abort on invalid legacy name"
printf '%s' "$OUT" | grep -q "439 preflight failed: existing usernames violate the new rules: john.doe" \
  || fail_case "missing diagnostics: $OUT"
IDX="$(psql_db "$DB2" -c "SELECT indexdef FROM pg_indexes WHERE indexname='users_username_unique_idx'")"
[ "$IDX" = "$OLD_IDX" ] || fail_case "abort did not roll back: $IDX"
echo "case 2 OK"

echo "== case 3: case-fold collision aborts"
newdb || fail_case "could not create case-3 database"
DB3="$NEWDB"
seed_user "$DB3" 'ahmed.one@example.invalid' "'Ahmed'"
seed_user "$DB3" 'ahmed.two@example.invalid' "'ahmed'"
OUT="$(psql_db "$DB3" -f "$MIG" 2>&1)" && fail_case "apply must abort on case-fold collision"
printf '%s' "$OUT" | grep -q "439 preflight failed: case-insensitive username collisions" \
  || fail_case "missing diagnostics: $OUT"
IDX="$(psql_db "$DB3" -c "SELECT indexdef FROM pg_indexes WHERE indexname='users_username_unique_idx'")"
[ "$IDX" = "$OLD_IDX" ] || fail_case "abort did not roll back: $IDX"
echo "case 3 OK"

echo "== case 4: all-digit phone-shaped legacy name aborts"
newdb || fail_case "could not create case-4 database"
DB4="$NEWDB"
seed_user "$DB4" 'digits@example.invalid' "'012345678'"
OUT="$(psql_db "$DB4" -f "$MIG" 2>&1)" && fail_case "apply must abort on phone-shaped name"
printf '%s' "$OUT" | grep -q "439 preflight failed: existing usernames violate the new rules: 012345678" \
  || fail_case "missing diagnostics: $OUT"
IDX="$(psql_db "$DB4" -c "SELECT indexdef FROM pg_indexes WHERE indexname='users_username_unique_idx'")"
[ "$IDX" = "$OLD_IDX" ] || fail_case "abort did not roll back: $IDX"
echo "case 4 OK"

echo "ALL 439 HARNESS CASES PASS"
