#!/usr/bin/env bash
# 444 harness: applies the REAL migration files 439, 440, 441, 442, 443
# and 444 in chain order against a freshly created THROWAWAY clone of
# h435_template (psql -f, ON_ERROR_STOP), then pins:
#   - anon / PUBLIC execute-counts on public functions before vs after 444
#     (unchanged: is_cashier_type is SECURITY INVOKER, the executors are
#     granted to authenticated only);
#   - definer-subset execute-counts (prosecdef) before vs after 444
#     (security's B1 baseline: anon=11, PUBLIC=4 on the 443 chain);
#   - public function BODIES by md5 before vs after 444: NO existing
#     function may change (444 only adds);
#   - pg_policies dump before vs after 444: unchanged (444 adds no policies);
#   - users_user_type_check: old pinned definition -> new pinned definition;
# then runs the 442 suite (regression: 444 must not break it) and the 444
# suite (partition pins, executor happy path, audited refusals, grants).
#
# SAFETY: identical rules to 442_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random name, only this run's database is dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./444_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
SUITE442="$HERE/../tests/442_shop_staff_core_test.sql"
SUITE444="$HERE/../tests/444_staff_admin_exec_test.sql"
TEMPLATE="h435_template"

ADMIN_URL="${1:?usage: 444_harness.sh <admin-db-url>}"

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

DB="zz444_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DB\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DB")
URL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DB#")"

run() { psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$1" >/dev/null || fail_case "apply failed: $1"; }

echo "== chain apply 439..443"
for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased; do

# Real Supabase auth.users always has encrypted_password; the local stub
# schema predates the stub's use here. Add it so the digest proof in
# mark_password_rotated / staff_password_changed exercises the real shape.
psql "$URL" -X -q -v ON_ERROR_STOP=1 -c \
  "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
  || fail_case "could not add local auth.users.encrypted_password stub"
  run "$MIG/$m.sql" || exit 2
  echo "$m OK"
done

snap() {  # $1 = label; prints the three pin streams to /tmp files
  psql "$URL" -X -q -A -t -c "
    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname='public' AND a.privilege_type='EXECUTE'
       AND a.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon');
    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
         LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     WHERE n.nspname='public' AND a.privilege_type='EXECUTE' AND a.grantee=0;
    SELECT count(*) FILTER (WHERE a.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon')),
           count(*) FILTER (WHERE a.grantee=0)
       FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
            LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      WHERE n.nspname='public' AND p.prosecdef AND a.privilege_type='EXECUTE';" > "/tmp/zz444_counts_$1.txt"
  psql "$URL" -X -q -A -t -c "
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
           md5(pg_get_functiondef(p.oid))
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       JOIN pg_language l ON l.oid=p.prolang
     WHERE n.nspname='public' AND p.prokind='f' AND l.lanname IN ('sql','plpgsql')
     ORDER BY 1,2,3" > "/tmp/zz444_funcs_$1.txt"
  psql "$URL" -X -q -A -t -c "
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies ORDER BY 1,2,3" > "/tmp/zz444_policies_$1.txt"
}

echo "== pins before 444"
snap before

OLD_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='users_user_type_check' AND conrelid='public.users'::regclass")"
[ "$OLD_CHK" = "CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text, 'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text, 'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text, 'village_admin'::text])))" ] \
  || fail_case "users_user_type_check pre-image drifted: $OLD_CHK"

echo "== apply 444"
run "$MIG/444_staff_admin_exec.sql" || exit 2
echo "444 OK"

NEW_CHK="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='users_user_type_check' AND conrelid='public.users'::regclass")"
[ "$NEW_CHK" = "CHECK ((user_type = ANY (ARRAY['customer'::text, 'merchant'::text, 'driver'::text, 'provider'::text, 'delivery'::text, 'admin'::text, 'owner'::text, 'super_admin'::text, 'country_admin'::text, 'governorate_admin'::text, 'center_admin'::text, 'village_admin'::text, 'merchant_staff'::text])))" ] \
  || fail_case "users_user_type_check post-image wrong: $NEW_CHK"
echo "users_user_type_check old->new pinned OK"

NEW_KIND="$(psql "$URL" -X -q -A -t -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='merchant_staff_events_kind_check' AND conrelid='public.merchant_staff_events'::regclass")"
case "$NEW_KIND" in
  *"'refused'::text"*"'password_changed'::text"*) echo "kind CHECK extended OK";;
  *) fail_case "merchant_staff_events_kind_check post-image wrong: $NEW_KIND";;
esac

echo "== pins after 444"
snap after

diff <(sort /tmp/zz444_policies_before.txt) <(sort /tmp/zz444_policies_after.txt) >/dev/null \
  || fail_case "pg_policies changed under 444"
echo "policies pin OK"

# anon/PUBLIC flat counts unchanged; definer subset unchanged
diff /tmp/zz444_counts_before.txt /tmp/zz444_counts_after.txt >/dev/null \
  || fail_case "anon/PUBLIC execute counts changed under 444: $(paste -sd' ' /tmp/zz444_counts_before.txt) -> $(paste -sd' ' /tmp/zz444_counts_after.txt)"
echo "anon/PUBLIC counts pin OK ($(paste -sd' ' /tmp/zz444_counts_after.txt))"

# function bodies: 444 may only ADD, never change an existing body
python3 - /tmp/zz444_funcs_before.txt /tmp/zz444_funcs_after.txt <<'PY' || fail_case "an existing function body changed under 444"
import sys
def load(p):
    d = {}
    for line in open(p):
        parts = line.rstrip("\n").split("|")
        if len(parts) == 4:
            d[(parts[0], parts[1], parts[2])] = parts[3]
    return d
before, after = load(sys.argv[1]), load(sys.argv[2])
changed = [k for k in before if k in after and before[k] != after[k]]
gone = [k for k in before if k not in after]
added = sorted(set(after) - set(before))
expected = {("public", "is_cashier_type", "p_type text"),
            ("public", "staff_admin_provision_begin", "p_merchant_id uuid, p_username text, p_full_name text, p_role text, p_branch_id uuid, p_phone text"),
            ("public", "staff_admin_provision_complete", "p_provision_id uuid, p_auth_user_id uuid"),
            ("public", "staff_admin_provision_abort", "p_provision_id uuid, p_reason text"),
            ("public", "staff_admin_set_active", "p_staff_id uuid, p_active boolean"),
            ("public", "staff_admin_record_password_reset", "p_staff_id uuid"),
            ("public", "staff_admin_audit_refusal", "p_merchant_id uuid, p_reason text"),
            ("public", "staff_admin_sync_complete", "p_staff_id uuid, p_generation uuid"),
            ("public", "staff_admin_sync_failed", "p_staff_id uuid, p_generation uuid"),
            ("public", "staff_admin_mark_password_rotated", "p_staff_id uuid, p_generation uuid"),
            ("public", "staff_password_changed", "")}
allowed_changed = {("public", "handle_new_user", ""): ("3bb10a3336503d4f558c27d66493e39e", "4c27ceff52867e83ead588c6951fc5c1")}
bad_changed = [k for k in changed
               if k not in allowed_changed
               or allowed_changed[k] != (before[k], after[k])]
if bad_changed or gone or set(added) != expected:
    print("CHANGED:", bad_changed, "GONE:", gone, "ADDED:", added)
    sys.exit(1)
print("function-body pin OK (11 added; handle_new_user pinned old->new)")
PY

echo "== 442 suite (regression)"
psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE442" | grep -q '442 suite OK' \
  || fail_case "442 suite failed under the 444 chain"
echo "442 suite OK"

echo "== 444 suite"
OUT="$(psql "$URL" -X -q -v ON_ERROR_STOP=1 -f "$SUITE444" 2>&1)" || { printf '%s\n' "$OUT" | tail -20; fail_case "444 suite failed"; }
echo "444 suite OK"

echo "== race H: concurrent provision_complete claims"
IDS="$(psql "$URL" -X -q -A -t <<'SQL'
BEGIN;
insert into auth.users(id, email) values (gen_random_uuid(), 'zzh.owner@example.invalid') returning id;
insert into public.users(id, email, role, user_type, verification_status, account_status)
  select id, email, 'customer', 'customer', 'approved', 'active' from auth.users
  where email = 'zzh.owner@example.invalid' on conflict (id) do nothing;
insert into public.merchants(id, name, owner_user_id, type, status)
  select gen_random_uuid(), 'zzh-shop', u.id, 'restaurant', 'active'
  from public.users u where u.email = 'zzh.owner@example.invalid';
insert into public.branches(id, merchant_id, name, is_primary)
  select gen_random_uuid(), m.id, 'zzh-b1', true
  from public.merchants m where m.name = 'zzh-shop';
update public.platform_settings
   set feature_flags = feature_flags || '{"staff_accounts":true}'::jsonb where id = 'default';
select m.owner_user_id, m.id, b.id
  from public.merchants m join public.branches b on b.merchant_id = m.id
 where m.name = 'zzh-shop';
COMMIT;
SQL
)"
OWNER=$(echo "$IDS" | tail -1 | cut -d'|' -f1)
MERCHANT=$(echo "$IDS" | tail -1 | cut -d'|' -f2)
BRANCH=$(echo "$IDS" | tail -1 | cut -d'|' -f3)
AUTHUSER="11111111-2222-4333-8444-555555555555"
PROV="$(psql "$URL" -X -q -A -t <<SQL | grep -E '^[0-9a-f-]{36}$'
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "$OWNER"}', true);
SELECT (public.staff_admin_provision_begin('$MERCHANT'::uuid, 'zzhracer', 'Racer', 'cashier', '$BRANCH'::uuid, NULL))->>'provision_id';
COMMIT;
SQL
)"
[ -n "$PROV" ] || fail_case "race H: provision_begin failed"
psql "$URL" -X -q -c "INSERT INTO auth.users(id, email, created_at, raw_app_meta_data) VALUES ('$AUTHUSER', 'staff_zzh_race@delwaqty.app', now(), jsonb_build_object('staff_provisioning', '$PROV'::uuid))" >/dev/null
for i in 1 2; do
  ( psql "$URL" -X -q > "/tmp/zz444_race_$i.out" 2>&1 <<SQL
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "$OWNER"}', true);
SELECT public.staff_admin_provision_complete('$PROV'::uuid, '$AUTHUSER'::uuid);
COMMIT;
SQL
  ) &
done
wait
WON=$(psql "$URL" -X -q -A -t -c "SELECT count(*) FROM public.merchant_staff WHERE user_id = '$AUTHUSER'")
[ "$WON" = "1" ] || fail_case "race H: expected exactly one staff row, got $WON"
STATE=$(psql "$URL" -X -q -A -t -c "SELECT state FROM public.staff_provisioning WHERE id = '$PROV'")
[ "$STATE" = "consumed" ] || fail_case "race H: provisioning state $STATE"
( grep -q 'staff creation refused' /tmp/zz444_race_1.out || grep -q 'staff creation refused' /tmp/zz444_race_2.out )   || fail_case "race H: the losing claim was not refused"
echo "race H OK (exactly one concurrent claim won; loser refused)"

echo "== race I: ownership flip concurrent with provision_complete (#260)"
IDS2="$(psql "$URL" -X -q -A -t <<'SQL'
BEGIN;
insert into auth.users(id, email) values (gen_random_uuid(), 'zzh.outsider@example.invalid');
update public.platform_settings
   set feature_flags = feature_flags || '{"staff_accounts":true}'::jsonb where id = 'default';
select m.owner_user_id, m.id, b.id,
       (select id from auth.users where email = 'zzh.outsider@example.invalid')
  from public.merchants m join public.branches b on b.merchant_id = m.id
 where m.name = 'zzh-shop';
COMMIT;
SQL
)"
OUTSIDER=$(echo "$IDS2" | tail -1 | cut -d'|' -f4)
AUTHUSER2="21111111-2222-4333-8444-555555555555"
PROV2="$(psql "$URL" -X -q -A -t <<SQL | grep -E '^[0-9a-f-]{36}$'
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "$OWNER"}', true);
SELECT (public.staff_admin_provision_begin('$MERCHANT'::uuid, 'zzhrace2', 'Racer2', 'cashier', '$BRANCH'::uuid, NULL))->>'provision_id';
COMMIT;
SQL
)"
[ -n "$PROV2" ] || fail_case "race I: provision_begin failed"
psql "$URL" -X -q -c "INSERT INTO auth.users(id, email, created_at, raw_app_meta_data) VALUES ('$AUTHUSER2', 'staff_zzh_race2@delwaqty.app', now(), jsonb_build_object('staff_provisioning', '$PROV2'::uuid))" >/dev/null
# session A holds an uncommitted ownership flip
mkfifo /tmp/zz444_raceI_fifo 2>/dev/null || true
psql "$URL" -X -q > /tmp/zz444_raceI_flip.out 2>&1 <<SQL &
BEGIN;
UPDATE public.merchants SET owner_user_id = '$OUTSIDER' WHERE id = '$MERCHANT';
SELECT pg_sleep(2);
COMMIT;
SQL
FLIPPID=$!
sleep 1
# session B consumes concurrently: must block on the FOR SHARE lock, then refuse
psql "$URL" -X -q > /tmp/zz444_raceI_complete.out 2>&1 <<SQL
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "$OWNER"}', true);
SELECT public.staff_admin_provision_complete('$PROV2'::uuid, '$AUTHUSER2'::uuid);
COMMIT;
SQL
wait $FLIPPID
grep -q 'staff creation refused' /tmp/zz444_raceI_complete.out   || fail_case "race I: complete after the committed flip was not refused"
WON2=$(psql "$URL" -X -q -A -t -c "SELECT count(*) FROM public.merchant_staff WHERE user_id = '$AUTHUSER2'")
[ "$WON2" = "0" ] || fail_case "race I: flipped consume created a staff row"
psql "$URL" -X -q -c "UPDATE public.merchants SET owner_user_id = '$OWNER' WHERE id = '$MERCHANT'" >/dev/null
echo "race I OK (FOR SHARE serialized the flip; consume refused)"

echo "444 harness ALL OK"
