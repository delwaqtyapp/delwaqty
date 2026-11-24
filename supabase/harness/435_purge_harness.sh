#!/usr/bin/env bash
# 435 purge harness (code review #165/#176): executes the EXACT
# migration files 431 + 435 against freshly created THROWAWAY databases.
# Nothing is re-typed: the real files are applied with psql -f under
# ON_ERROR_STOP, and every assertion is enforced with an exit code.
#
# SAFETY (hard gate, code review #176e):
#   - Only localhost / 127.0.0.1 / ::1 hosts are accepted.
#   - The PROD project ref bttnlkmwhorjamzemwda is refused outright
#     (any host string containing it aborts).
#   - Staging (adcgqoccrgauqdoplsgg) is NOT disposable and is refused too.
#     Run this locally (supabase start); mirror the run on staging only
#     through the builder's own staging-only copy procedure.
#   - Requires HARNESS_CONFIRM_DISPOSABLE=yes in the environment.
#   - Never mutates a pre-existing database: each case runs in a NEW
#     database with a random name, cloned from the prepared template
#     database h435_template (migrations 000..430 applied, 431 NOT
#     applied), and dropped afterwards.
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./435_purge_harness.sh \
#       "postgres://postgres:postgres@localhost:54322/postgres" [--selfcheck]
#
# Exit codes: 0 all pass; 1 safety refusal; 2 a case failed;
# 3 output drifted from expected.txt (with --selfcheck).

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
EXPECTED="$HERE/435_purge_harness.expected.txt"

ADMIN_URL="${1:?usage: 435_purge_harness.sh <admin-db-url> [--selfcheck]}"
SELFCHECK="${2:-}"

fail_safety() { echo "SAFETY REFUSAL: $1" >&2; exit 1; }

[ "${HARNESS_CONFIRM_DISPOSABLE:-}" = "yes" ] \
  || fail_safety "set HARNESS_CONFIRM_DISPOSABLE=yes to confirm you understand this script creates and drops databases"

case "$ADMIN_URL" in
  *bttnlkmwhorjamzemwda*) fail_safety "PROD project ref detected in target URL";;
  *adcgqoccrgauqdoplsgg*) fail_safety "staging project ref detected; staging is not disposable";;
esac

# libpq URI query parameters (host=/hostaddr=/service= etc.) can
# silently override the endpoint in the authority part, and every
# PG* environment variable below can redirect or re-target the whole
# connection. Reject ALL of them: the URI below is the single,
# validated endpoint of this run.
case "$ADMIN_URL" in
  *\?*|*'&'*) fail_safety "URI query parameters are not allowed (host/hostaddr/service overrides)";;
esac
for V in PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE PGPASSFILE PGOPTIONS PGCONNECT_TIMEOUT PGSSLMODE PGTARGETSESSIONATTRS; do
  if [ -n "${!V:-}" ]; then
    fail_safety "environment variable $V is set; unset every PG* variable before running the harness (the URI is the only endpoint)"
  fi
done
case "$ADMIN_URL" in
  postgres://*|postgresql://*) ;;
  *) fail_safety "URL must be a postgres:// connection URI";;
esac
# Host extraction: strip scheme and userinfo; a bracketed IPv6 literal
# keeps its brackets up to ']'; anything else ends at the first : or /.
HPART="$(printf '%s' "$ADMIN_URL" | sed -E 's#^[a-z]+://([^@]*@)?##')"
case "$HPART" in
  \[*) HOST="$(printf '%s' "$HPART" | sed -E 's#^(\[[^]]*\]).*#\1#')";;
  *)    HOST="$(printf '%s' "$HPART" | sed -E 's#[:/].*$##')";;
esac
case "$HOST" in
  localhost|127.0.0.1|'[::1]') ;;
  *) fail_safety "host '$HOST' is not localhost/127.0.0.1/[::1]";;
esac

# bash array for psql args (code review #176e): no string-splitting.
PSQL_BASE=(psql "$ADMIN_URL" -v ON_ERROR_STOP=1 -X -q -A -t)

rand_db() { printf 'h435_%s' "$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"; }

run_psql() { # run_psql <db> <args...>
  local db="$1"; shift
  psql "${ADMIN_URL%/*}/$db" -v ON_ERROR_STOP=1 -X -q -A -t "$@"
}

CREATED_DBS=()
CLEANUP_FAILED=0
cleanup() { # drop every DB we created, even on failure/interrupt
  local d rc=0
  for d in ${CREATED_DBS[@]+"${CREATED_DBS[@]}"}; do
    if ! psql "$ADMIN_URL" -X -q -c "DROP DATABASE IF EXISTS $d;" >/dev/null 2>&1; then
      echo "CLEANUP FAILURE: DROP DATABASE $d failed - remove it manually" >&2
      rc=2
    fi
  done
  [ $rc -ne 0 ] && exit $rc || true
}
trap cleanup EXIT INT TERM

die() { echo "HARNESS SETUP FAILURE: $1" >&2; exit 2; }

new_db()  { # create enforced; failure aborts the whole harness
  "${PSQL_BASE[@]}" -c "CREATE DATABASE $1 TEMPLATE h435_template;" >/dev/null \
    || die "CREATE DATABASE $1 failed"
  CREATED_DBS+=("$1")
}
drop_db() { # a failed drop fails the run (no swallowed errors)
  "${PSQL_BASE[@]}" -c "DROP DATABASE IF EXISTS $1;" >/dev/null \
    || die "DROP DATABASE $1 failed"
  # untrack so the cleanup trap does not re-drop
  local kept=() d
  for d in ${CREATED_DBS[@]+"${CREATED_DBS[@]}"}; do [ "$d" = "$1" ] || kept+=("$d"); done
  CREATED_DBS=(${kept[@]+"${kept[@]}"})
}

apply_sql() { # apply_sql <db> <file>: enforced - any error aborts
  local db="$1" f="$2"
  run_psql "$db" -f "$f" >/dev/null || die "applying $f to $db failed"
}

"${PSQL_BASE[@]}" -c "SELECT 1 FROM pg_database WHERE datname='h435_template';" | grep -q 1 \
  || fail_safety "template database 'h435_template' missing: create it once with migrations 000..430 applied (431 NOT applied)"

RESULTS=()
note() { RESULTS+=("$1"); echo "$1"; }

expect_fail_with() { # expect_fail_with <db> <file> <message-fragment> <tag>
  local db="$1" file="$2" frag="$3" tag="$4" out rc
  out="$(run_psql "$db" -f "$file" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then
    note "$tag: FAIL (migration applied where refusal was expected)"; return 1
  fi
  if ! printf '%s' "$out" | grep -qF "$frag"; then
    note "$tag: FAIL (refused, but not by the expected guard)"
    return 1
  fi
  note "$tag: OK (refused by expected guard)"
  return 0
}

FAILED=0

echo "== case 1: clean apply 431 + 435 =="
DB1="$(rand_db)"; new_db "$DB1"
if run_psql "$DB1" -f "$HERE/435_purge_harness_fixtures.sql" >/dev/null \
   && run_psql "$DB1" -f "$MIG/431_pharmacy_retirement.sql" >/dev/null \
   && run_psql "$DB1" -f "$MIG/435_pharmacy_purge.sql" >/dev/null; then
  CHK="$(run_psql "$DB1" -c "SELECT
      NOT EXISTS(SELECT 1 FROM public.merchants WHERE type='pharmacy')
      AND to_regclass('public.pharmacy_links') IS NULL
      AND to_regclass('public.pharmacy_transfer_requests') IS NULL
      AND NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                      WHERE n.nspname='public' AND p.proname LIKE 'pharmacy\_%' ESCAPE '\')
      AND NOT EXISTS(SELECT 1 FROM public.commission_rules WHERE entity_key IN ('pharmacy','pharmacy_delivery'));")"
  if [ "$CHK" = "t" ]; then note "case1-clean-apply: OK"; else note "case1-clean-apply: FAIL (residue remains)"; FAILED=1; fi
else
  note "case1-clean-apply: FAIL (migration errored)"; FAILED=1
fi

echo "== case 2: second run of both files =="
if run_psql "$DB1" -f "$MIG/431_pharmacy_retirement.sql" >/dev/null 2>&1 \
   && run_psql "$DB1" -f "$MIG/435_pharmacy_purge.sql" >/dev/null 2>&1; then
  note "case2-second-run: OK"
else
  note "case2-second-run: FAIL (re-run errored)"; FAILED=1
fi
drop_db "$DB1"

echo "== case 3: drifted constraint -> Guard 0, zero mutation =="
DB3="$(rand_db)"; new_db "$DB3"
apply_sql "$DB3" "$HERE/435_purge_harness_fixtures.sql"
apply_sql "$DB3" "$MIG/431_pharmacy_retirement.sql"
# Gate A now passes (431 applied, constraints still pre-state); the
# drift below must be caught by Guard 0, not Gate A.
run_psql "$DB3" -c "ALTER TABLE public.merchants DROP CONSTRAINT merchants_type_check;
                    ALTER TABLE public.merchants ADD CONSTRAINT merchants_type_check CHECK (type IN ('food','other','pharmacy'));" >/dev/null
expect_fail_with "$DB3" "$MIG/435_pharmacy_purge.sql" "constraint state drift or mixed pre/post" "case3-drift-guard0" || FAILED=1
SURVIVED="$(run_psql "$DB3" -c "SELECT count(*) FROM public.merchants WHERE type='pharmacy';")"
if [ "$SURVIVED" = "1" ]; then note "case3-fixture-survived: OK (1)"; else note "case3-fixture-survived: FAIL (count=$SURVIVED)"; FAILED=1; fi
drop_db "$DB3"

echo "== case 4a: single blocker = paid ride + driver_earnings =="
DB4="$(rand_db)"; new_db "$DB4"
apply_sql "$DB4" "$HERE/435_purge_harness_fixtures.sql"
apply_sql "$DB4" "$MIG/431_pharmacy_retirement.sql"
apply_sql "$DB4" "$HERE/435_purge_harness_blocked_paid.sql"
expect_fail_with "$DB4" "$MIG/435_pharmacy_purge.sql" "pharmacy_delivery rides with financial/operational dependents or paid/completed state" "case4a-paid-ride-guard" || FAILED=1
C="$(run_psql "$DB4" -c "SELECT count(*) FROM public.rides WHERE service_type='pharmacy_delivery';")"
if [ "$C" = "1" ]; then note "case4a-rides-unchanged: OK (1)"; else note "case4a-rides-unchanged: FAIL (count=$C)"; FAILED=1; fi
drop_db "$DB4"

echo "== case 4b: single blocker = in-trip ride =="
DB5="$(rand_db)"; new_db "$DB5"
apply_sql "$DB5" "$HERE/435_purge_harness_fixtures.sql"
apply_sql "$DB5" "$MIG/431_pharmacy_retirement.sql"
apply_sql "$DB5" "$HERE/435_purge_harness_blocked_intrip.sql"
expect_fail_with "$DB5" "$MIG/435_pharmacy_purge.sql" "pharmacy_delivery rides with financial/operational dependents or paid/completed state" "case4b-intrip-guard" || FAILED=1
C="$(run_psql "$DB5" -c "SELECT count(*) FROM public.rides WHERE service_type='pharmacy_delivery';")" || die "case4b state check failed"
if [ "$C" = "1" ]; then note "case4b-rides-unchanged: OK (1)"; else note "case4b-rides-unchanged: FAIL (count=$C)"; FAILED=1; fi
drop_db "$DB5"

echo "== case 4c: single blocker = non-empty network table =="
DB6="$(rand_db)"; new_db "$DB6"
apply_sql "$DB6" "$HERE/435_purge_harness_fixtures.sql"
apply_sql "$DB6" "$MIG/431_pharmacy_retirement.sql"
apply_sql "$DB6" "$HERE/435_purge_harness_blocked_network.sql"
expect_fail_with "$DB6" "$MIG/435_pharmacy_purge.sql" "non-empty pharmacy network tables" "case4c-network-guard" || FAILED=1
C="$(run_psql "$DB6" -c "SELECT count(*) FROM public.pharmacy_links;")" || die "case4c state check failed"
if [ "$C" = "1" ]; then note "case4c-network-unchanged: OK (1)"; else note "case4c-network-unchanged: FAIL (count=$C)"; FAILED=1; fi
C="$(run_psql "$DB6" -c "SELECT count(*) FROM public.merchants WHERE type='pharmacy';")" || die "case4c merchant check failed"
if [ "$C" = "2" ]; then note "case4c-merchants-unchanged: OK (2)"; else note "case4c-merchants-unchanged: FAIL (count=$C)"; FAILED=1; fi
drop_db "$DB6"

echo "== case 5: Gate A fires when 431 was never applied =="
DB7="$(rand_db)"; new_db "$DB7"
apply_sql "$DB7" "$HERE/435_purge_harness_fixtures.sql"
expect_fail_with "$DB7" "$MIG/435_pharmacy_purge.sql" "Gate A" "case5-gateA-without-431" || FAILED=1
drop_db "$DB7"

if [ $FAILED -ne 0 ]; then
  echo "HARNESS: FAIL"
  exit 2
fi
echo "HARNESS: all cases OK"

if [ "$SELFCHECK" = "--selfcheck" ]; then
  OUT="$HERE/.last_run.txt"
  printf '%s\n' "${RESULTS[@]}" > "$OUT"
  if diff -u "$EXPECTED" "$OUT"; then
    echo "SELFCHECK: output matches expected.txt"
  else
    echo "SELFCHECK: output drifted from expected.txt" >&2
    exit 3
  fi
fi
exit 0
