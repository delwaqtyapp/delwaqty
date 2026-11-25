#!/usr/bin/env bash
# 441 harness: applies the REAL migration files 439, 440 and 441 in
# chain order against a freshly created THROWAWAY clone of h435_template
# (psql -f, ON_ERROR_STOP, nothing re-typed), then runs the post-apply
# suite proving: username and phone resolution still work, and an
# email-shaped identifier NEVER resolves (the removed legacy email
# bridge) - not even for the account whose email it is - while grants
# stay service-role only.
#
# SAFETY: endpoint host must be exactly localhost/127.0.0.1/[::1]; the
# prod and staging project refs are refused anywhere in the URL;
# requires HARNESS_CONFIRM_DISPOSABLE=yes; the database is CREATE-first
# (name collision retries with a new random name); only the database
# this run created is dropped; PG* redirect variables are unset.
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./441_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
M439="$HERE/../migrations/439_username_login_identifier.sql"
M440="$HERE/../migrations/440_auth_login_identifier.sql"
M441="$HERE/../migrations/441_login_identifier_no_email.sql"
SUITE="$HERE/../tests/441_login_identifier_no_email_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 441_harness.sh <admin-db-url>}"

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
  db="h441_$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  if psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$db\" TEMPLATE $TEMPLATE" >/dev/null 2>&1; then
    CREATED+=("$db")
    NEWDB="$db"
    break
  fi
done
[ -n "$NEWDB" ] || fail_case "could not create database"

BASE_URL="$(printf '%s' "$ADMIN_URL" | sed -E 's#/[^/]*$##')"

echo "== applying 439, 440, 441 in chain order on clone $NEWDB"
psql "$BASE_URL/$NEWDB" -v ON_ERROR_STOP=1 -X -q -f "$M439" >/dev/null || fail_case "439 apply failed"
psql "$BASE_URL/$NEWDB" -v ON_ERROR_STOP=1 -X -q -f "$M440" >/dev/null || fail_case "440 apply failed"
psql "$BASE_URL/$NEWDB" -v ON_ERROR_STOP=1 -X -q -f "$M441" >/dev/null || fail_case "441 apply failed"
echo "chain apply OK"

echo "== post-apply suite"
OUT="$(psql "$BASE_URL/$NEWDB" -v ON_ERROR_STOP=1 -X -q -At -f "$SUITE" 2>&1)" \
  || fail_case "suite failed: $OUT"
printf '%s\n' "$OUT" | grep -q "441 suite OK" || fail_case "suite marker missing: $OUT"
echo "441 suite OK"
