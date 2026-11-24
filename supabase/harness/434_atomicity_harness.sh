#!/usr/bin/env bash
# 434 atomicity harness (code review #192/#194): executes the EXACT
# migration file supabase/migrations/434_whatsapp_otp_number.sql against
# freshly created THROWAWAY databases - a correct pre-image and
# deliberately broken pre-images - and proves that (a) the real file
# succeeds on the real pre-image and (b) every induced failure aborts
# with the exact expected reason and leaves FULL state (whole function
# bodies, both ACL sets, the owner guard, the platform_settings column
# set) byte-identical to before. One case fails AFTER the DDL (a
# postcheck failure), proving the BEGIN/COMMIT wrapper rolls the DDL
# back. Nothing is re-typed: the real file is applied with psql -f under
# ON_ERROR_STOP, and every assertion is enforced with an exit code.
#
# SAFETY (hard gate, code review #194):
#   - The endpoint host must parse as EXACTLY localhost, 127.0.0.1, or
#     ::1 (bracketed [::1] when a port is given), with an optional
#     numeric port and nothing else. Supplied host text is never trusted
#     beyond that parse: no prefix matching, no suffixes, no query
#     string, no fragments, no non-default path segments.
#   - The PROD project ref bttnlkmwhorjamzemwda and the staging ref
#     adcgqoccrgauqdoplsgg are refused outright anywhere in the URL.
#   - Requires HARNESS_CONFIRM_DISPOSABLE=yes in the environment.
#   - Never touches a pre-existing database: databases are CREATE-first
#     (no DROP IF EXISTS before create; a name collision retries with a
#     new random name), and only databases THIS run created successfully
#     are dropped afterwards.
#   - Every PG* environment variable that could redirect the connection
#     must be unset.
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
  *\?*|*'&'*|*'#'*) fail_safety "URI query parameters and fragments are not allowed (host/hostaddr/service overrides)";;
esac
for V in PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE PGPASSFILE PGOPTIONS PGCONNECT_TIMEOUT PGSSLMODE PGTARGETSESSIONATTRS; do
  if [ -n "${!V:-}" ]; then
    fail_safety "environment variable $V is set; unset every PG* variable before running the harness (the URI is the only endpoint)"
  fi
done

# Exact endpoint parse: postgres://[userinfo@]HOST[:PORT]/dbname where
# HOST is exactly a loopback and PORT is digits only. Nothing else.
case "$ADMIN_URL" in
  postgres://*|postgresql://*) ;;
  *) fail_safety "ADMIN_URL must be a postgres:// URI";;
esac
NOPROTO="${ADMIN_URL#postgres://}"; NOPROTO="${NOPROTO#postgresql://}"
NOUSER="${NOPROTO##*@}"            # userinfo, if any, ends at the LAST @
HOSTPORT="${NOUSER%%/*}"           # authority ends at the first /
DBPATH="${NOUSER#*/}"
case "$DBPATH" in
  */*|'') fail_safety "database path must be a single non-empty segment";;
esac
[ -n "$HOSTPORT" ] || fail_safety "missing host"
case "$HOSTPORT" in
  localhost|127.0.0.1|::1|\[::1\]) ;;                    # exact host, no port
  localhost:*|127.0.0.1:*|\[::1\]:*)
    H="${HOSTPORT%:*}"; P="${HOSTPORT##*:}"
    case "$H" in localhost|127.0.0.1|\[::1\]) ;; *) fail_safety "host is not an exact loopback: $H";; esac
    case "$P" in ''|*[!0-9]*) fail_safety "port must be numeric, got: $P";; esac
    ;;
  *) fail_safety "host is not an exact loopback (localhost, 127.0.0.1, ::1): $HOSTPORT";;
esac

[ -f "$MIG" ] || fail_safety "migration file not found: $MIG"
[ -f "$SUITE" ] || fail_safety "suite file not found: $SUITE"

ADMIN_DB="${ADMIN_URL%/postgres}/postgres"
FN_OID="public.request_whatsapp_otp(text,text)"
GUARD_OID="public.guard_platform_settings_owner_fields()"

say() { printf '%s\n' "$1"; }
OUT=()
record() { OUT+=("$1"); say "$1"; }
fail_case() { record "$1: FAIL ($2)"; }

q() { # q <db> <sql> -> stdout (tA)
  psql "${ADMIN_URL%/postgres}/$1" -X -q -tA -v ON_ERROR_STOP=1 -c "$2"
}
admin_q() { psql "$ADMIN_DB" -X -q -tA -v ON_ERROR_STOP=1 -c "$1"; }

CREATED=()
mk_db() { # mk_db <name-var> : create-first, retry on name collision only
  local attempt name err
  for attempt in 1 2 3 4 5; do
    name="t434h_${RANDOM}${RANDOM}${RANDOM}"
    err="$(admin_q "CREATE DATABASE $name TEMPLATE $TEMPLATE" 2>&1)"
    if [ $? -eq 0 ]; then
      CREATED+=("$name")
      printf -v "$1" '%s' "$name"
      return 0
    fi
    case "$err" in
      *"already exists"*) continue;;   # collision: new random name, never drop
      *) say "CREATE DATABASE failed: $err" >&2; return 1;;
    esac
  done
  say "CREATE DATABASE: too many name collisions" >&2
  return 1
}
cleanup() {
  local db
  for db in ${CREATED[@]+"${CREATED[@]}"}; do
    admin_q "DROP DATABASE $db" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

# Full state: the WHOLE platform_settings column set, both whole function
# bodies (md5 over the complete pg_get_functiondef text), and both full
# EXECUTE ACL sets. '~' separates fields; ',' separates set members.
state() {
  q "$1" "SELECT (SELECT coalesce(string_agg(column_name||':'||data_type, ',' ORDER BY column_name), '')
                    FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='platform_settings')
          || '~' || md5(pg_get_functiondef('$FN_OID'::regprocedure))
          || '~' || coalesce((SELECT string_agg(g, ',' ORDER BY g) FROM (
                        SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                                    ELSE a.grantee::regrole::text END AS g
                          FROM aclexplode(p.proacl) a
                         WHERE a.privilege_type = 'EXECUTE') z), '')
          || '~' || md5(pg_get_functiondef('$GUARD_OID'::regprocedure))
          || '~' || coalesce((SELECT string_agg(g, ',' ORDER BY g) FROM (
                        SELECT CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                                    ELSE a.grantee::regrole::text END AS g
                          FROM aclexplode(p2.proacl) a
                         WHERE a.privilege_type = 'EXECUTE') z), '')
           FROM pg_proc p, pg_proc p2
          WHERE p.oid = '$FN_OID'::regprocedure AND p2.oid = '$GUARD_OID'::regprocedure"
}

colset_has() { # colset_has <state> <column>
  printf '%s' "$1" | cut -d'~' -f1 | tr ',' '\n' | grep -q "^$2:"
}

APPLY_ERR=""
APPLY_RC=0
apply_migration() { # apply_migration <db>
  APPLY_ERR="$(psql "${ADMIN_URL%/postgres}/$1" -X -q -v ON_ERROR_STOP=1 -f "$MIG" 2>&1 >/dev/null)"
  APPLY_RC=$?
}

# ---------- case 1: clean apply on the correct pre-image + real suite ----------
mk_db DB1 || { record "case1-clean-apply: FAIL (create db)"; exit 2; }
apply_migration "$DB1"
if [ $APPLY_RC -eq 0 ]; then
  record "case1-clean-apply: OK"
  S="$(state "$DB1")"
  if colset_has "$S" "whatsapp_otp_number" \
     && [ "$(printf '%s' "$S" | cut -d'~' -f3)" = "anon,authenticated,postgres,service_role" ] \
     && q "$DB1" "SELECT pg_get_functiondef('$FN_OID'::regprocedure) LIKE '%_lookup_rate_allow%'
                    AND pg_get_functiondef('$FN_OID'::regprocedure) LIKE '%whatsapp_otp_number%'
                    AND pg_get_functiondef('$GUARD_OID'::regprocedure) LIKE '%whatsapp_otp_number%'" | grep -qx "t"; then
    record "case1-post-state: OK"
  else
    fail_case "case1-post-state" "unexpected state $S"
  fi
  if psql "${ADMIN_URL%/postgres}/$DB1" -X -q -v ON_ERROR_STOP=1 -f "$SUITE" >/dev/null 2>&1; then
    record "case1-suite: OK"
  else
    fail_case "case1-suite" "rollback suite non-zero on applied DB"
  fi
else
  fail_case "case1-clean-apply" "exit=$APPLY_RC err=$APPLY_ERR"
fi

# ---------- case 2: drifted function body -> exact abort, FULL state unchanged ----------
mk_db DB2 || { record "case2-drift-refused: FAIL (create db)"; exit 2; }
q "$DB2" "CREATE OR REPLACE FUNCTION public.request_whatsapp_otp(p_phone text, p_purpose text DEFAULT 'register'::text)
           RETURNS jsonb LANGUAGE plpgsql AS \$f\$ BEGIN RETURN '{}'::jsonb; END; \$f\$;" >/dev/null
BEFORE2="$(state "$DB2")"
apply_migration "$DB2"
if [ $APPLY_RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: request_whatsapp_otp drifted from the pinned 414 pre-image"; then
  record "case2-drift-refused: OK (refused by expected guard)"
else
  fail_case "case2-drift-refused" "exit=$APPLY_RC err=$APPLY_ERR"
fi
AFTER2="$(state "$DB2")"
if [ "$AFTER2" = "$BEFORE2" ] && ! colset_has "$AFTER2" "whatsapp_otp_number"; then
  record "case2-state-unchanged: OK"
else
  fail_case "case2-state-unchanged" "state drifted"
fi

# ---------- case 3: drifted owner-guard -> exact abort, FULL state unchanged ----------
mk_db DB3 || { record "case3-guard-refused: FAIL (create db)"; exit 2; }
q "$DB3" "CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
           RETURNS trigger LANGUAGE plpgsql AS \$f\$ BEGIN RETURN NEW; END; \$f\$;" >/dev/null
BEFORE3="$(state "$DB3")"
apply_migration "$DB3"
if [ $APPLY_RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: guard_platform_settings_owner_fields drifted from its pinned pre-image"; then
  record "case3-guard-refused: OK (refused by expected guard)"
else
  fail_case "case3-guard-refused" "exit=$APPLY_RC err=$APPLY_ERR"
fi
AFTER3="$(state "$DB3")"
if [ "$AFTER3" = "$BEFORE3" ] && ! colset_has "$AFTER3" "whatsapp_otp_number"; then
  record "case3-state-unchanged: OK"
else
  fail_case "case3-state-unchanged" "state drifted"
fi

# ---------- case 4: column already present -> exact abort, FULL state unchanged ----------
mk_db DB4 || { record "case4-column-refused: FAIL (create db)"; exit 2; }
q "$DB4" "ALTER TABLE public.platform_settings ADD COLUMN whatsapp_otp_number text" >/dev/null
BEFORE4="$(state "$DB4")"
apply_migration "$DB4"
if [ $APPLY_RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "whatsapp_otp_number already exists; aborting"; then
  record "case4-column-refused: OK (refused by expected guard)"
else
  fail_case "case4-column-refused" "exit=$APPLY_RC err=$APPLY_ERR"
fi
AFTER4="$(state "$DB4")"
if [ "$AFTER4" = "$BEFORE4" ]; then
  record "case4-state-unchanged: OK"
else
  fail_case "case4-state-unchanged" "state drifted"
fi

# ---------- case 5: ACL drift -> exact abort, FULL state unchanged ----------
mk_db DB5 || { record "case5-acl-refused: FAIL (create db)"; exit 2; }
q "$DB5" "REVOKE EXECUTE ON FUNCTION public.request_whatsapp_otp(text,text) FROM anon" >/dev/null
BEFORE5="$(state "$DB5")"
apply_migration "$DB5"
if [ $APPLY_RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 precondition failed: request_whatsapp_otp EXECUTE ACL drifted"; then
  record "case5-acl-refused: OK (refused by expected guard)"
else
  fail_case "case5-acl-refused" "exit=$APPLY_RC err=$APPLY_ERR"
fi
AFTER5="$(state "$DB5")"
if [ "$AFTER5" = "$BEFORE5" ] && ! colset_has "$AFTER5" "whatsapp_otp_number"; then
  record "case5-state-unchanged: OK"
else
  fail_case "case5-state-unchanged" "state drifted"
fi

# ---------- case 6: failure AFTER the DDL (postcheck) -> full rollback ----------
# An event trigger (harness scaffolding, not part of the compared state)
# swaps the guard back to its pre-434 body the moment the migration
# re-creates it, so the migration's OWN postcheck is what fails - after
# ADD COLUMN and both function replacements already ran. The BEGIN/COMMIT
# wrapper must roll ALL of it back.
mk_db DB6 || { record "case6-postcheck-refused: FAIL (create db)"; exit 2; }
q "$DB6" "CREATE OR REPLACE FUNCTION public.zz_434_sabotage_guard() RETURNS event_trigger
           LANGUAGE plpgsql AS \$f\$
           DECLARE obj record;
           BEGIN
             -- one-shot: the sabotage's own CREATE OR REPLACE re-fires this
             -- trigger; the GUC stops the recursion.
             IF current_setting('zz_434.sabotage_done', true) IS NOT NULL THEN
               RETURN;
             END IF;
             FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
               IF obj.object_identity = 'public.guard_platform_settings_owner_fields()' THEN
                 PERFORM set_config('zz_434.sabotage_done', '1', true);
                 EXECUTE 'CREATE OR REPLACE FUNCTION public.guard_platform_settings_owner_fields()
                            RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
                            SET search_path TO ''public'', ''pg_temp''
                            AS \$g\$ BEGIN RETURN NEW; END; \$g\$';
               END IF;
             END LOOP;
           END \$f\$;" >/dev/null \
  && q "$DB6" "CREATE EVENT TRIGGER zz_434_sabotage ON ddl_command_end
                WHEN TAG IN ('CREATE FUNCTION')
                EXECUTE FUNCTION public.zz_434_sabotage_guard()" >/dev/null \
  || { record "case6-postcheck-refused: FAIL (event trigger setup)"; exit 2; }
BEFORE6="$(state "$DB6")"
apply_migration "$DB6"
if [ $APPLY_RC -ne 0 ] && printf '%s' "$APPLY_ERR" | grep -qF "434 post-check failed: owner guard does not cover whatsapp_otp_number"; then
  record "case6-postcheck-refused: OK (refused by expected guard)"
else
  fail_case "case6-postcheck-refused" "exit=$APPLY_RC err=$APPLY_ERR"
fi
AFTER6="$(state "$DB6")"
if [ "$AFTER6" = "$BEFORE6" ] && ! colset_has "$AFTER6" "whatsapp_otp_number"; then
  record "case6-state-unchanged: OK"
else
  fail_case "case6-state-unchanged" "state drifted"
fi

# ---------- verdict ----------
FAILED=0
for L in ${OUT[@]+"${OUT[@]}"}; do
  case "$L" in *FAIL*) FAILED=1;; esac
done

if [ "$SELFCHECK" = "--selfcheck" ]; then
  if [ ! -f "$EXPECTED" ]; then
    say "selfcheck: expected file missing: $EXPECTED"
    exit 3
  fi
  TMP="$(mktemp)"
  printf '%s\n' ${OUT[@]+"${OUT[@]}"} > "$TMP"
  if ! diff -u "$EXPECTED" "$TMP"; then
    rm -f "$TMP"
    say "selfcheck: output drifted from $(basename "$EXPECTED")"
    exit 3
  fi
  rm -f "$TMP"
fi

[ "$FAILED" -eq 0 ] && exit 0 || exit 2
