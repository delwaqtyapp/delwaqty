#!/usr/bin/env bash
# 454 harness: on a THROWAWAY clone of h435_template (which holds 340..382),
#  1. seeds a pre-454 legacy license (long DLWQ1 key, no short_code column),
#  2. applies the REAL 454 migration,
#  3. asserts the backfill (legacy key unchanged, short code added, unique),
#  4. runs the 454 suite and the 419 + 420 cashier suites (regression),
#  5. RED RUN: applies a deliberately broken copy of 454 (throttle check
#     removed) to a second clone and requires the 454 suite to FAIL.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes,
# random DB names, only this run's databases are dropped.
# Usage: HARNESS_CONFIRM_DISPOSABLE=yes ./454_harness.sh "postgres://postgres@localhost:54322/postgres"
# Exit: 0 pass; 1 safety refusal; 2 case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/454_cashier_short_license_keys.sql"
T="$HERE/../tests"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 454_harness.sh <admin-db-url>}"
fail_safety() { echo "SAFETY REFUSAL: $1" >&2; exit 1; }
fail_case() { echo "CASE FAILURE: $1" >&2; exit 2; }
[ "${HARNESS_CONFIRM_DISPOSABLE:-}" = "yes" ] || fail_safety "set HARNESS_CONFIRM_DISPOSABLE=yes"
case "$ADMIN_URL" in
  *bttnlkmwhorjamzemwda*) fail_safety "PROD project ref detected";;
  *adcgqoccrgauqdoplsgg*) fail_safety "staging project ref detected";;
  *\?*|*'&'*|*'#'*) fail_safety "URI query parameters and fragments are not allowed";;
esac
for V in PGHOST PGHOSTADDR PGPORT PGUSER PGDATABASE PGSERVICE PGSERVICEFILE PGPASSFILE PGOPTIONS PGCONNECT_TIMEOUT PGSSLMODE PGTARGETSESSIONATTRS; do unset "$V" || true; done
HOSTPORT="$(printf '%s' "$ADMIN_URL" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/@]*@)?([^/]*)/.*$#\2#')"
HOST="$(printf '%s' "$HOSTPORT" | sed -E 's/^(\[[0-9a-fA-F:]+\]|[^:]+)(:[0-9]+)?$/\1/')"
case "$HOST" in localhost|127.0.0.1|"[::1]") ;; *) fail_safety "host must be localhost, got: $HOST";; esac
CREATED=()
cleanup() { for db in "${CREATED[@]:-}"; do [ -n "$db" ] && psql "$ADMIN_URL" -X -q -c "DROP DATABASE IF EXISTS \"$db\"" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT
mk() { local n="zz454${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
# Local stub only: make auth.uid() read both claim styles, as real Supabase does,
# so the 419/420 suites (request.jwt.claim.sub) and 454 (request.jwt.claims) both run.
stub_uid() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$f\$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''))::uuid \$f\$" || fail_case "uid stub failed"; }
seed_legacy() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "
  INSERT INTO auth.users(id,email) VALUES ('00000000-0000-0000-0000-0000000454a1','l454@x.i');
  INSERT INTO public.users(id,email,role) VALUES ('00000000-0000-0000-0000-0000000454a1','l454@x.i','merchant') ON CONFLICT(id) DO UPDATE SET role='merchant';
  INSERT INTO public.merchants(id,owner_user_id,name,type) VALUES ('00000000-0000-0000-0000-0000000454b1','00000000-0000-0000-0000-0000000454a1','legacy shop','grocery');
  INSERT INTO public.cashier_licenses(merchant_id,license_key,plan,status) VALUES ('00000000-0000-0000-0000-0000000454b1','DLWQ1.legacyseed.0000','trial','active');" \
  || fail_case "legacy seed failed"; }

echo "== GREEN: seed legacy row, apply 454, check backfill"
URL="$(mk g)"; stub_uid "$URL"; seed_legacy "$URL"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null || fail_case "454 apply failed"
R="$(psql "$URL" -X -Atc "select license_key, short_code ~ '^[0-9]{12}\$' from public.cashier_licenses")"
[ "$R" = "DLWQ1.legacyseed.0000|t" ] || fail_case "backfill wrong: $R"
echo "backfill OK (legacy key unchanged, short code added)"
for S in 454_cashier_short_license_keys_test 419_cashier_license_gate_test 420_cashier_offline_customer_resolution_test; do
  OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$T/$S.sql" 2>&1)" || { printf '%s\n' "$OUT" | tail -5; fail_case "$S failed"; }
  echo "$S OK"
done
echo "== RED: broken 454 (throttle disabled) must make the suite fail"
RURL="$(mk r)"; stub_uid "$RURL"; seed_legacy "$RURL"
sed 's/IF public._cashier_key_throttled(v_uid) THEN/IF false THEN/g' "$MIG" > /tmp/zz454_broken.sql
cmp -s "$MIG" /tmp/zz454_broken.sql && fail_case "red edit did not change the migration"
psql "$RURL" -X -q -v ON_ERROR_STOP=1 -f /tmp/zz454_broken.sql >/dev/null || fail_case "broken 454 apply failed"
if psql "$RURL" -X -q -v ON_ERROR_STOP=1 -f "$T/454_cashier_short_license_keys_test.sql" >/tmp/zz454_red.out 2>&1; then
  fail_case "suite passed against the broken migration"
fi
grep -q "454 F2" /tmp/zz454_red.out || fail_case "red run failed for the wrong reason"
rm -f /tmp/zz454_broken.sql /tmp/zz454_red.out
echo "red run failed as required (454 F2)"
echo "== RED 2 (#297): throttle-first regression must fail the throttled-owner case"
R2="$(mk q)"; stub_uid "$R2"; seed_legacy "$R2"
python3 - "$MIG" > /tmp/zz454_broken2.sql <<'PY'
import sys
s=open(sys.argv[1]).read()
k="  v_norm := public._cashier_normalize_key(p_license_key);\n  SELECT * INTO v_l"
assert k in s
s=s.replace(k,"  IF public._cashier_key_throttled(v_uid) THEN RETURN jsonb_build_object('ok', false, 'reason', 'TOO_MANY_ATTEMPTS'); END IF;\n"+k,1)
sys.stdout.write(s)
PY
psql "$R2" -X -q -v ON_ERROR_STOP=1 -f /tmp/zz454_broken2.sql >/dev/null 2>&1 || fail_case "broken2 apply failed"
if psql "$R2" -X -q -v ON_ERROR_STOP=1 -f "$T/454_cashier_short_license_keys_test.sql" >/tmp/zz454_red2.out 2>&1; then fail_case "suite passed against throttle-first"; fi
grep -q "454 F4" /tmp/zz454_red2.out || fail_case "red2 failed for the wrong reason"
rm -f /tmp/zz454_broken2.sql /tmp/zz454_red2.out
echo "red run 2 failed as required (454 F4)"
echo "== IDEMPOTENT: apply 454 a second time to the green DB"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null || fail_case "454 is not re-runnable"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$T/454_cashier_short_license_keys_test.sql" 2>&1)" || { printf '%s\n' "$OUT" | tail -5; fail_case "454 suite failed after re-apply"; }
echo "re-apply OK, suite OK"
echo "454 HARNESS PASS"
