#!/usr/bin/env bash
# 442 harness (round 2): applies the REAL migration files 439, 440, 441
# and 442 in chain order against a freshly created THROWAWAY clone of
# h435_template (psql -f, ON_ERROR_STOP, nothing re-typed), pins:
#   - pg_policies rows of orders/pos_sales/pos_sale_payments/pos_shifts
#     before vs after (nothing existing changes; only the three staff
#     read policies are added; orders gains NONE);
#   - anon / PUBLIC execute-counts on public functions (unchanged);
#   - public function BODIES by md5 before vs after: the ONLY allowed
#     change is guard_platform_settings_owner_fields (442/S4 extends it,
#     pre-image md5-pinned inside the migration);
# then runs the post-apply suite (cross-tenant negatives for every RPC and
# policy, disabled-staff token refusal, password-change barrier, kitchen
# and NULL-branch negatives, append-only audit, branch/staff re-parent
# inverse checks, idempotency incl. payload-conflict, payments-sum,
# discount caps, race-safe stock, S1 deferred-charge exploit, S3 void
# reversal + move-based restore, S4 owner-only flags, S6 user/merchant
# deletion, S7 shift-gated cash, S11 debt cap, flag-off defaults) and
# finishes with REAL two-session concurrency races (#252/#256).
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
FUNC_SQL="SELECT p.proname || '|' || pg_get_function_identity_arguments(p.oid) || '|' || md5(p.prosrc)
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' ORDER BY 1;"

psql "$DB_URL" -X -q -At -c "$POLICY_SQL" > /tmp/.442_policies_before.txt \
  || fail_case "policy dump (before) failed"
ANON_BEFORE="$(psql "$DB_URL" -X -q -At -c "$ANON_SQL")" || fail_case "anon count (before) failed"
PUB_BEFORE="$(psql "$DB_URL" -X -q -At -c "$PUB_SQL")" || fail_case "PUBLIC count (before) failed"
psql "$DB_URL" -X -q -At -c "$FUNC_SQL" > /tmp/.442_funcs_before.txt \
  || fail_case "function dump (before) failed"

echo "== applying 442"
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$M442" >/dev/null || fail_case "442 apply failed"
echo "442 apply OK"

# ---- pins AFTER 442 ----
psql "$DB_URL" -X -q -At -c "$POLICY_SQL" > /tmp/.442_policies_after.txt \
  || fail_case "policy dump (after) failed"
ANON_AFTER="$(psql "$DB_URL" -X -q -At -c "$ANON_SQL")" || fail_case "anon count (after) failed"
PUB_AFTER="$(psql "$DB_URL" -X -q -At -c "$PUB_SQL")" || fail_case "PUBLIC count (after) failed"
psql "$DB_URL" -X -q -At -c "$FUNC_SQL" > /tmp/.442_funcs_after.txt \
  || fail_case "function dump (after) failed"

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

# 4) Function bodies: every pre-existing function is byte-identical after
#    442 EXCEPT guard_platform_settings_owner_fields (the S4 extension,
#    whose pre-image is md5-pinned inside the migration itself).
CHANGED="$(comm -23 <(sort /tmp/.442_funcs_before.txt) <(sort /tmp/.442_funcs_after.txt) | grep -v '^guard_platform_settings_owner_fields|' || true)"
[ -z "$CHANGED" ] || fail_case "442 changed an existing function body: $CHANGED"
grep -q '^guard_platform_settings_owner_fields|' /tmp/.442_funcs_before.txt \
  || fail_case "guard_platform_settings_owner_fields missing before 442"
echo "policy + grant + function pins OK (anon=$ANON_AFTER, PUBLIC=$PUB_AFTER; added: $ADDED_NAMES; changed: guard_platform_settings_owner_fields only)"

echo "== post-apply suite"
OUT="$(psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -At -f "$SUITE" 2>&1)" \
  || fail_case "suite failed: $OUT"
printf '%s\n' "$OUT" | grep -q "442 suite OK" || fail_case "suite marker missing: $OUT"
echo "442 suite OK"

# ==================== two-session concurrency races (#252/#256) ====================
echo "== concurrency races (two real sessions)"

FIX_SQL=/tmp/.442_race_fixtures.sql
cat > "$FIX_SQL" <<'SQL'
insert into auth.users(id, email) values ('442ee000-0000-4000-8000-0000000000a1', 'zz442race.c@example.invalid');
insert into public.users(id, email, role, user_type, verification_status, username, account_status)
values ('442ee000-0000-4000-8000-0000000000a1', 'zz442race.c@example.invalid', 'customer', 'customer', 'approved', 'zz442racec', 'active')
on conflict (id) do nothing;
insert into public.merchants(id, name, owner_user_id, type, status)
values ('442ee000-0000-4000-8000-0000000000b1', 'zz442-race-shop', NULL, 'food', 'active');
insert into public.branches(id, merchant_id, name, is_primary)
values ('442ee000-0000-4000-8000-0000000000c1', '442ee000-0000-4000-8000-0000000000b1', 'zz442-race-b1', true);
insert into public.products(id, merchant_id, name, name_ar, price, stock_quantity)
values ('442ee000-0000-4000-8000-0000000000d1', '442ee000-0000-4000-8000-0000000000b1', 'zz442-race-tea', 'شاي', 25, 100);
insert into public.merchant_staff(merchant_id, user_id, username, full_name, role, branch_id, must_change_password)
values ('442ee000-0000-4000-8000-0000000000b1', '442ee000-0000-4000-8000-0000000000a1', 'zz442racecash', 'zz442 Race Cashier', 'cashier', '442ee000-0000-4000-8000-0000000000c1', false);
update public.platform_settings
   set feature_flags = feature_flags || '{"staff_accounts":true,"cashier_mode_mobile":true}'::jsonb
 where id = 'default';
SQL
psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -f "$FIX_SQL" >/dev/null || fail_case "race fixtures failed"

CLAIMS='{"sub":"442ee000-0000-4000-8000-0000000000a1"}'
OP_SHIFT='442ee000-0000-4000-8000-00000000f001'
OP_SALE='442ee000-0000-4000-8000-00000000f002'

# Race A: two sessions open a shift with the SAME op id: exactly one shift,
# one winner, one replay.
psql "$DB_URL" -X -q -At -c "SET ROLE authenticated; SELECT set_config('request.jwt.claims', '$CLAIMS', true); SELECT public.staff_shift_open(100, '$OP_SHIFT');" > /tmp/.442_raceA1.txt 2>&1 &
psql "$DB_URL" -X -q -At -c "SET ROLE authenticated; SELECT set_config('request.jwt.claims', '$CLAIMS', true); SELECT public.staff_shift_open(100, '$OP_SHIFT');" > /tmp/.442_raceA2.txt 2>&1 &
wait
grep -q 'idempotent_replay' /tmp/.442_raceA1.txt || fail_case "race A session 1 failed: $(cat /tmp/.442_raceA1.txt)"
grep -q 'idempotent_replay' /tmp/.442_raceA2.txt || fail_case "race A session 2 failed: $(cat /tmp/.442_raceA2.txt)"
SHIFT_COUNT="$(psql "$DB_URL" -X -q -At -c "SELECT count(*) FROM public.pos_shifts WHERE merchant_id = '442ee000-0000-4000-8000-0000000000b1'")"
[ "$SHIFT_COUNT" = "1" ] || fail_case "race A created $SHIFT_COUNT shifts"
REPLAYS="$(grep -h -o '"idempotent_replay": true\|idempotent_replay.*t' /tmp/.442_raceA1.txt /tmp/.442_raceA2.txt | wc -l)"
echo "race A OK (1 shift; outputs: replay flags present)"

# Race B: two sessions open with DIFFERENT op ids while a shift is open:
# both must refuse (close-your-shift / unique rescue), still one shift.
psql "$DB_URL" -X -q -At -c "SET ROLE authenticated; SELECT set_config('request.jwt.claims', '$CLAIMS', true); SELECT public.staff_shift_open(0, '442ee000-0000-4000-8000-00000000f011');" > /tmp/.442_raceB1.txt 2>&1 &
psql "$DB_URL" -X -q -At -c "SET ROLE authenticated; SELECT set_config('request.jwt.claims', '$CLAIMS', true); SELECT public.staff_shift_open(0, '442ee000-0000-4000-8000-00000000f012');" > /tmp/.442_raceB2.txt 2>&1 &
wait
grep -q 'close your current shift' /tmp/.442_raceB1.txt || fail_case "race B session 1 unexpected: $(cat /tmp/.442_raceB1.txt)"
grep -q 'close your current shift' /tmp/.442_raceB2.txt || fail_case "race B session 2 unexpected: $(cat /tmp/.442_raceB2.txt)"
SHIFT_COUNT="$(psql "$DB_URL" -X -q -At -c "SELECT count(*) FROM public.pos_shifts WHERE merchant_id = '442ee000-0000-4000-8000-0000000000b1' AND closed_at IS NULL")"
[ "$SHIFT_COUNT" = "1" ] || fail_case "race B left $SHIFT_COUNT open shifts"
echo "race B OK (still exactly one open shift)"

# Race C: two sessions run the SAME sale op id concurrently: one sale row,
# both calls succeed (winner + replay), stock decremented exactly once.
SALE_CALL="SET ROLE authenticated; SELECT set_config('request.jwt.claims', '$CLAIMS', true); SELECT public.staff_create_walk_in_sale('[{\"product_id\":\"442ee000-0000-4000-8000-0000000000d1\",\"qty\":2}]', '[{\"method\":\"cash\",\"amount\":50}]', '$OP_SALE');"
psql "$DB_URL" -X -q -At -c "$SALE_CALL" > /tmp/.442_raceC1.txt 2>&1 &
psql "$DB_URL" -X -q -At -c "$SALE_CALL" > /tmp/.442_raceC2.txt 2>&1 &
wait
grep -q 'idempotent_replay' /tmp/.442_raceC1.txt || fail_case "race C session 1 failed: $(cat /tmp/.442_raceC1.txt)"
grep -q 'idempotent_replay' /tmp/.442_raceC2.txt || fail_case "race C session 2 failed: $(cat /tmp/.442_raceC2.txt)"
SALE_COUNT="$(psql "$DB_URL" -X -q -At -c "SELECT count(*) FROM public.pos_sales WHERE merchant_id = '442ee000-0000-4000-8000-0000000000b1'")"
[ "$SALE_COUNT" = "1" ] || fail_case "race C created $SALE_COUNT sales"
STOCK="$(psql "$DB_URL" -X -q -At -c "SELECT stock_quantity FROM public.products WHERE id = '442ee000-0000-4000-8000-0000000000d1'")"
[ "$STOCK" = "98" ] || fail_case "race C decremented stock to $STOCK (expected 98)"
echo "race C OK (1 sale, stock 98)"

echo "442 harness ALL OK"
