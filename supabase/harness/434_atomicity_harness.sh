#!/usr/bin/env bash
# 434 atomicity harness (code review #192): executes the EXACT migration
# file supabase/migrations/434_whatsapp_otp_number.sql against freshly
# created THROWAWAY databases - a correct pre-image and deliberately
# drifted pre-images - and proves that (a) the real file succeeds on the
# real pre-image and (b) every induced A0 failure aborts with the exact
# expected reason and leaves column/function/guard/ACL state UNCHANGED.
# Nothing is re-typed: the real file is applied with psql -f under
# ON_ERROR_STOP, and every assertion is enforced with an exit code.
#
# SAFETY (hard gate, same pattern as 435_purge_harness.sh):
#   - Only localhost / 127.0.0.1 / ::1 hosts are accepted.
#   - The PROD project ref bttnlkmwhorjamzemwda is refused outright.
#   - Staging (adcgqoccrgauqdoplsgg) is NOT disposable and is refused too.
#   - Requires HARNESS_CONFIRM_DISPOSABLE=yes in the environment.
#   - Never mutates a pre-existing database: each case runs in a NEW
#     database with a random name, cloned from the prepared template
#     database h435_template, and dropped afterwards.
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./434_atomicity_harness.sh \
#       "postgres://postgres@localhost:54322/postgres" [--selfcheck]
#
# Exit codes: 0 all pass; 1 safety refusal; 2 a case failed;
# 3 output drifted from expected.txt (with --selfcheck).

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/434_whatsapp_otp_number.sql"
SUITE="$HERE/../tests/434_whatsapp_otp_number_test.sql"
EXPECTED="$HERE/434_atomicity_harness.expected.txt"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 434_atomicity_harness.sh <admin-db-url> [--selfcheck]}"
SELFCHECK="${2:-}"

fail_safety() { echo "SAFETY REFUSAL: $1" >&2; exit 1; }

[ "${HARNESS_CONFIRM_DISPOSABLE:-}" = "yes" ] \
  || fail_safety "set HARNESS_CONFIRM_DISPOSABLE=yes to confirm you understand this script creates and drops databases"

case "$ADMIN_URL" in
  *bttnlkmwhorjamzemwda*) fail_safety "PROD project ref detected in target URL";;
  *adcgqoccrgauqdoplsgg*) fail_safety "staging project ref detected; staging is not disposable";;
esac
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
  *) fail_safety "ADMIN_URL must be a postgres:// URI";;
esac
HOSTPORT="$(printf '%s' "$ADMIN_URL" | sed -E 's#^postgres(ql)?://([^@]*@)?([^/]*)/.*#\3#')"
case "$HOSTPORT" in
  localhost*|127.0.0.1*|::1*|"[::1]"*) ;;
  *) fail_safety "only localhost targets are allowed, got host: $HOSTPORT";;
esac

[ -f "$MIG" ] || fail_safety "migration file not found: $MIG"
[ -f "$SUITE" ] || fail_safety "suite file not found: $SUITE"

ADMIN_DB="${ADMIN_URL%/postgres}/postgres"

say() { printf '%s\n' "$1"; }
OUT=()
record() { OUT+=("$1"); say "$1"; }
fail_case() { record "$1: FAIL ($2)"; }

db_url() { printf '%s/%s' "${ADMIN_URL%/postgres}" "$1"; }

q() { # q <db> <sql> -> stdout (tA)
  psql "$(db_url "$1")" -X -q -tA -v ON_ERROR_STOP=1 -c "$2"
}
admin_q() { psql "$ADMIN_DB" -X -q -tA -v ON_ERROR_STOP=1 -c "$1"; }

mk_db() { # mk_db <name>
  admin_q "CREATE DATABASE $1 TEMPLATE $TEMPLATE" >/dev/null || return 1
}
drop_db() { admin_q "DROP DATABASE IF EXISTS $1" >/dev/null 2>&1 || true; }

FN_OID="public.request_whatsapp_otp(text,text)"
GUARD_OID="public.guard_platform_settings_owner_fields()"

# state <db> -> "col_exists|body_md5|body_has_rateguard|body_has_override|
#                guard_md5|guard_covers|acl_set"
state() {
  q "$1" "SELECT (SELECT count(*) FROM information_schema.columns
                    WHERE table_schema='public' AND table_name='platform_settings'
                      AND column_name='whatsapp_otp_number')
          || '|' || md5(pg_get_functiondef('$FN_OID'::regprocedure))
          || '|' || (pg_get_functiondef('$FN_OID'::regprocedure) LIKE '%_lookup_rate_allow%')
          || '|' || (pg_get_functiondef('$FN_OID'::regprocedure) LIKE '%whatsapp_otp_number%')
          || '|' || md5(pg_get_functiondef('$GUARD_OID'::regprocedure))
          || '|' || (pg_get_functiondef('$GUARD_OID'::regprocedure) LIKE '%whatsapp_otp_number%')
          || '|' || coalesce((SELECT string_agg(g, ',' ORDER BY g) FROM (
                        SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                                    ELSE a.grantee::regrole::text END AS g
                          FROM aclexplode(p.proacl) a
                         WHERE a.privilege_type = 'EXECUTE') z), '')
           FROM pg_proc p WHERE p.oid = '$FN_OID'::regprocedure"
}

apply_migration() { # apply_migration <db> -> captures stderr in APPLY_ERR, returns psql code
  APPLY_ERR="$(psql "$(db_url "$1")" -X -q -v ON_ERROR_STOP=1 -f "$MIG" 2>&1 >/dev/null)"
}

# ---------- case 1: clean apply on the correct pre-image + real suite ----------
DB1="t434h_c1_$RANDOM$RANDOM"
drop_db "$DB1"
mk_db "$DB1" || { record "case1-clean-apply: FAIL (create db)"; exit 2; }
apply_migration "$DB1"
if [ $? -eq 0 ]; then
  record "case1-clean-apply: OK"
  S="$(state "$DB1")"
  if [ "$(printf '%s' "$S" | cut -d'|' -f1)" = "1" ] \
     && [ "$(printf '%s' "$S" | cut -d'|' -f3)" = "true" ] \
     && [ "$(printf '%s' "$S" | cut -d'|' -f4)" = "true" ] \
     && [ "$(printf '%s' "$S" | cut -d'|' -f6)" = "true" ] \
     && [ "$(printf '%s' "$S" | cut -d'|' -f7)" = "anon,authenticated,postgres,service_role" ]; then
    record "case1-post-state: OK"
  else
    fail_case "case1-post-state" "unexpected state $S"
  fi
  if psql "$(db_url "$DB1")" -X -q -v ON_ERROR_STOP=1 -f "$SUITE" >/dev/null 2>&1; then
    record "case1-suite: OK"
  else
    fail_case "case1-suite" "rollback suite non-zero on applied DB"
  fi
else
  fail_case "case1-clean-apply" "exit=$? err=$APPLY_ERR"
fi
drop_db "$DB1"

# ---------- case 2: drifted function body -> exact abort, state unchanged ----------
DB2="t434h_c2_$RANDOM$RANDOM"
drop_db "$DB2"
mk_db "$DB2" || { record "case2-drift-refused: FAIL (create db)"; exit 2; }
q "$DB2" "CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
           RETURNS jsonb LANGUAGE plpgsql AS \$f\$ BEGIN RETURN '{}'::jsonb; END; \$f\$;" >/dev/null
BEFORE2="$(state "$DB2")"
apply_migration "$DB2"
RC=$?
if [ $RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: request_whatsapp_otp drifted from the pinned 414 pre-image"; then
  record "case2-drift-refused: OK (refused by expected guard)"
else
  fail_case "case2-drift-refused" "exit=$RC err=$APPLY_ERR"
fi
AFTER2="$(state "$DB2")"
# body md5 must equal the drifted stub, column absent, guard untouched
if [ "$AFTER2" = "$BEFORE2" ] \
   && [ "$(printf '%s' "$AFTER2" | cut -d'|' -f1)" = "0" ] \
   && [ "$(printf '%s' "$AFTER2" | cut -d'|' -f5)" = "797da2f7a1fb8c6eaf14b33121345bb8" ]; then
  record "case2-state-unchanged: OK"
else
  fail_case "case2-state-unchanged" "before=$BEFORE2 after=$AFTER2"
fi
drop_db "$DB2"

# ---------- case 3: drifted owner-guard -> exact abort, state unchanged ----------
DB3="t434h_c3_$RANDOM$RANDOM"
drop_db "$DB3"
mk_db "$DB3" || { record "case3-guard-refused: FAIL (create db)"; exit 2; }
q "$DB3" "CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
           RETURNS trigger LANGUAGE plpgsql AS \$f\$ BEGIN RETURN NEW; END; \$f\$;" >/dev/null
apply_migration "$DB3"
RC=$?
if [ $RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: guard_platform_settings_owner_fields drifted from its pinned pre-image"; then
  record "case3-guard-refused: OK (refused by expected guard)"
else
  fail_case "case3-guard-refused" "exit=$RC err=$APPLY_ERR"
fi
AFTER3="$(state "$DB3")"
if [ "$(printf '%s' "$AFTER3" | cut -d'|' -f1)" = "0" ] \
   && [ "$(printf '%s' "$AFTER3" | cut -d'|' -f2)" = "2e2f0086c65bac716c937af718debf86" ] \
   && [ "$(printf '%s' "$AFTER3" | cut -d'|' -f6)" = "false" ]; then
  record "case3-state-unchanged: OK"
else
  fail_case "case3-state-unchanged" "after=$AFTER3"
fi
drop_db "$DB3"

# ---------- case 4: column already present -> exact abort, function unchanged ----------
DB4="t434h_c4_$RANDOM$RANDOM"
drop_db "$DB4"
mk_db "$DB4" || { record "case4-column-refused: FAIL (create db)"; exit 2; }
q "$DB4" "ALTER TABLE public.platform_settings ADD COLUMN whatsapp_otp_number text" >/dev/null
apply_migration "$DB4"
RC=$?
if [ $RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "whatsapp_otp_number already exists; aborting"; then
  record "case4-column-refused: OK (refused by expected guard)"
else
  fail_case "case4-column-refused" "exit=$RC err=$APPLY_ERR"
fi
AFTER4="$(state "$DB4")"
if [ "$(printf '%s' "$AFTER4" | cut -d'|' -f2)" = "2e2f0086c65bac716c937af718debf86" ] \
   && [ "$(printf '%s' "$AFTER4" | cut -d'|' -f4)" = "false" ] \
   && [ "$(printf '%s' "$AFTER4" | cut -d'|' -f6)" = "false" ]; then
  record "case4-state-unchanged: OK"
else
  fail_case "case4-state-unchanged" "after=$AFTER4"
fi
drop_db "$DB4"

# ---------- case 5: ACL drift -> exact abort, state unchanged ----------
DB5="t434h_c5_$RANDOM$RANDOM"
drop_db "$DB5"
mk_db "$DB5" || { record "case5-acl-refused: FAIL (create db)"; exit 2; }
q "$DB5" "REVOKE EXECUTE ON FUNCTION public.request_whatsapp_otp(text,text) FROM anon" >/dev/null
BEFORE5="$(state "$DB5")"
apply_migration "$DB5"
RC=$?
if [ $RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: request_whatsapp_otp EXECUTE ACL drifted"; then
  record "case5-acl-refused: OK (refused by expected guard)"
else
  fail_case "case5-acl-refused" "exit=$RC err=$APPLY_ERR"
fi
AFTER5="$(state "$DB5")"
if [ "$AFTER5" = "$BEFORE5" ] && [ "$(printf '%s' "$AFTER5" | cut -d'|' -f1)" = "0" ]; then
  record "case5-state-unchanged: OK"
else
  fail_case "case5-state-unchanged" "before=$BEFORE5 after=$AFTER5"
fi
drop_db "$DB5"

# ---------- verdict ----------
FAILED=0
for L in "${OUT[@]}"; do
  case "$L" in *FAIL*) FAILED=1;; esac
done

if [ "$SELFCHECK" = "--selfcheck" ]; then
  if [ ! -f "$EXPECTED" ]; then
    say "selfcheck: expected file missing: $EXPECTED"
    exit 3
  fi
  TMP="$(mktemp)"
  printf '%s\n' "${OUT[@]}" > "$TMP"
  if ! diff -u "$EXPECTED" "$TMP"; then
    rm -f "$TMP"
    say "selfcheck: output drifted from $(basename "$EXPECTED")"
    exit 3
  fi
  rm -f "$TMP"
fi

[ "$FAILED" -eq 0 ] && exit 0 || exit 2
