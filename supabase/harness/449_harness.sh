#!/usr/bin/env bash
# 449 harness: applies the REAL migration files in chain order against
# freshly created THROWAWAY clones of h435_template and pins:
#
#   twin-DB equal behavior (the 22 re-pointed policies + campaigns
#   trigger must behave IDENTICALLY before and after 449):
#     DB_PRE  = 439..448 + 449_seed + 449_battery
#     DB_POST = 439..449 + 449_seed + 449_battery
#     battery stdout AND stderr must diff empty.
#
#   pre-image pins (both DBs, verified equal): campaigns trigger body md5
#   ffa5f17cde22ef4767785429d1db4d90, merchants_guard_sensitive_fields
#   body md5 7107c3cb04bf85de221ca347479d6ca2.
#
#   post-image pins (DB_POST): campaigns body e8b5b249f50311c28eea712a7de69714,
#   guard body 3556653a225599e861e35d3577a79a9c; policy-name set unchanged,
#   exactly the 22 expected policies changed expression; sweep counts
#   (anon REFERENCES/TRIGGER = 0, authenticated TRUNCATE = 0); view owner
#   postgres + security_barrier + SELECT-only for anon/authenticated.
#
#   NON-BREAKING proof: anon wildcard reads of merchants/products STILL
#   WORK after 449 (the base-table SELECT revokes are 450, not 449).
#
#   Then: 447 + 448 suites (regression) and the 449 suite (new surface).
#
# SAFETY: identical rules to 448_harness.sh (localhost-only URL, prod and
# staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes, CREATE-first with
# random names, only this run's databases are dropped, PG* vars unset).
#
# Usage:
#   HARNESS_CONFIRM_DISPOSABLE=yes ./449_harness.sh \
#       "postgres://postgres@localhost:54322/postgres"
#
# Exit codes: 0 pass; 1 safety refusal; 2 a case failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations"
TESTS="$HERE/../tests"
TEMPLATE="h435_template"
CAMP_SIG="public.campaigns_guard_status_change()"
CAMP_PRE_MD5="ffa5f17cde22ef4767785429d1db4d90"
CAMP_POST_MD5="e8b5b249f50311c28eea712a7de69714"
GUARD_SIG="public.merchants_guard_sensitive_fields()"
GUARD_PRE_MD5="7107c3cb04bf85de221ca347479d6ca2"
GUARD_POST_MD5="3556653a225599e861e35d3577a79a9c"

ADMIN_URL="${1:?usage: 449_harness.sh <admin-db-url>}"

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

DBPRE="zz449pre_$(date +%s)_$RANDOM"
DBPOST="zz449post_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPRE\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPRE")
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBPOST\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE"
CREATED+=("$DBPOST")
URLPRE="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPRE#")"
URLPOST="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBPOST#")"

apply_chain_448() {
  local url="$1"
  psql "$url" -X -q -v ON_ERROR_STOP=1 -c \
    "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS encrypted_password text NOT NULL DEFAULT 'zz-local-stub'" \
    || fail_case "could not add local auth.users.encrypted_password stub"
  local m
  for m in 439_username_login_identifier 440_auth_login_identifier 441_login_identifier_no_email 442_shop_staff_core 443_whatsapp_otp_number_rebased 444_staff_admin_exec 445_cashier_type_gates 446_product_presets 447_pos_sanity_caps 448_db_hardening_anon_surface; do
    psql "$url" -X -q -v ON_ERROR_STOP=1 -f "$MIG/$m.sql" >/dev/null \
      || fail_case "apply failed: $m.sql"
  done
  # Reproduce PROD's PostGIS posture (security review requirement): on prod
  # the 3 catalogs carry supabase_admin-granted ALL for anon+authenticated,
  # which the migration role cannot revoke. Without this simulation the
  # twin DBs hide that hazard.
  # Reproduce PROD's PostGIS posture (security review requirement): on prod
  # the 3 catalogs carry supabase_admin-granted ALL for anon+authenticated.
  # A plain GRANT as supabase_admin is a no-op while postgres-granted rows
  # exist, so first strip the local postgres-granted rows, then re-grant as
  # supabase_admin. Without this the twin DBs hide the unrevocable-grantor
  # hazard.
  psql "$url" -X -q -v ON_ERROR_STOP=1 -c "
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns TO supabase_admin WITH GRANT OPTION;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns TO supabase_admin WITH GRANT OPTION;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys TO supabase_admin WITH GRANT OPTION;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns FROM anon, authenticated;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns FROM anon, authenticated;
    REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys FROM anon, authenticated;
    SET ROLE supabase_admin;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geography_columns TO anon, authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.geometry_columns TO anon, authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.spatial_ref_sys TO anon, authenticated;
    RESET ROLE;" || fail_case "could not simulate prod PostGIS posture"
}

md5sig() { psql "$2" -X -q -A -t -c "SELECT md5(pg_get_functiondef('$1'::regprocedure))"; }

echo "== DB_PRE chain 439..448"
apply_chain_448 "$URLPRE"
echo "== DB_POST chain 439..448"
apply_chain_448 "$URLPOST"

echo "== pre-image pins (both DBs)"
[ "$(md5sig "$CAMP_SIG" "$URLPRE")" = "$CAMP_PRE_MD5" ] || fail_case "campaigns pre-image drifted (pre DB)"
[ "$(md5sig "$CAMP_SIG" "$URLPOST")" = "$CAMP_PRE_MD5" ] || fail_case "campaigns pre-image drifted (post DB)"
[ "$(md5sig "$GUARD_SIG" "$URLPRE")" = "$GUARD_PRE_MD5" ] || fail_case "guard pre-image drifted (pre DB)"
[ "$(md5sig "$GUARD_SIG" "$URLPOST")" = "$GUARD_PRE_MD5" ] || fail_case "guard pre-image drifted (post DB)"
echo "pre-image pins OK"

POLSQL="SELECT schemaname, tablename, policyname, permissive, roles, cmd, replace(qual::text, chr(10), ' '), replace(with_check::text, chr(10), ' ') FROM pg_policies ORDER BY 1,2,3"
ACLSQL="SELECT table_name || '|' || grantee || '|' || privilege_type || '|' || grantor || '|' || is_grantable FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee IN ('anon','authenticated') ORDER BY 1"
FUNSQL="SELECT p.proname || '|' || coalesce(p.proacl::text,'NULL') FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('campaigns_guard_status_change','merchants_guard_sensitive_fields','_is_merchant_owner_only') ORDER BY 1"
psql "$URLPRE"  -X -q -A -t -c "$POLSQL" > /tmp/zz449_policies_pre_448.txt
psql "$URLPOST" -X -q -A -t -c "$POLSQL" > /tmp/zz449_policies_post_448.txt
psql "$URLPOST" -X -q -A -t -c "$ACLSQL" > /tmp/zz449_acls_before.txt
psql "$URLPOST" -X -q -A -t -c "$FUNSQL" > /tmp/zz449_funs_before.txt
diff /tmp/zz449_policies_pre_448.txt /tmp/zz449_policies_post_448.txt >/dev/null \
  || fail_case "the two 448-built DBs already differ in policies"
echo "twin 448 builds identical"

echo "== apply 449 to DB_POST"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null 2>&1 \
  || fail_case "apply failed: 449_customer_surface_hardening.sql"
echo "449 OK"

echo "== post-image pins"
[ "$(md5sig "$CAMP_SIG" "$URLPOST")" = "$CAMP_POST_MD5" ] || fail_case "campaigns post-image wrong: $(md5sig "$CAMP_SIG" "$URLPOST")"
[ "$(md5sig "$GUARD_SIG" "$URLPOST")" = "$GUARD_POST_MD5" ] || fail_case "guard post-image wrong: $(md5sig "$GUARD_SIG" "$URLPOST")"
[ "$(md5sig "$CAMP_SIG" "$URLPRE")" = "$CAMP_PRE_MD5" ] || fail_case "pre DB campaigns body changed?!"
echo "post-image pins OK"

echo "== policies: name set unchanged, exactly the 22 expected changed"
psql "$URLPOST" -X -q -A -t -c "$POLSQL" > /tmp/zz449_policies_post_449.txt
cut -d'|' -f1-6 /tmp/zz449_policies_post_448.txt | sort > /tmp/zz449_names_before.txt
cut -d'|' -f1-6 /tmp/zz449_policies_post_449.txt | sort > /tmp/zz449_names_after.txt
diff /tmp/zz449_names_before.txt /tmp/zz449_names_after.txt >/dev/null \
  || fail_case "449 added or removed a policy: $(diff /tmp/zz449_names_before.txt /tmp/zz449_names_after.txt)"
diff /tmp/zz449_policies_post_448.txt /tmp/zz449_policies_post_449.txt > /tmp/zz449_policies.diff || true
CHANGED="$(grep '^>' /tmp/zz449_policies.diff | cut -d'|' -f2,3 | sort)"
EXPECTED="$(printf '%s\n' \
  'branches|branches merchant manage' \
  'branches|branches_view' \
  'driver_locations|driver_locations_select' \
  'driver_obligations|driver_obligations_read_own' \
  'merchant_ledger|merchant_ledger_read_own' \
  'merchant_payout_requests|merchant_payout_requests_read_own' \
  'merchant_staff_settings|merchant_staff_settings_owner' \
  'offers|offers_view' \
  'order_tracking|ot_insert_participants' \
  'order_tracking|ot_view_participants' \
  'orders|Merchants can view orders for their merchant' \
  'pos_sales|pos_sales_select_merchant' \
  'product_modifier_groups|product_modifier_groups_write' \
  'product_modifier_options|product_modifier_options_write' \
  'products|Merchant owners can manage products' \
  'products|Products are viewable by everyone' \
  'provider_documents|provider docs owner rw' \
  'reviews|Merchants can view reviews for their merchant' \
  'reviews|Reviews are viewable by everyone' \
  'service_bookings|Admins can manage bookings' \
  'service_bookings|service_bookings_select_provider' \
  'service_bookings|service_bookings_update_provider' | sort)"
[ "$CHANGED" = "$EXPECTED" ] || fail_case "changed policy set wrong: $(diff <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$CHANGED"))"
echo "policies OK (exactly the 22 expected re-points)"

echo "== sweep counts"
LEFT1="$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee='anon' AND privilege_type IN ('REFERENCES','TRIGGER')")"
[ "$LEFT1" = "0" ] || fail_case "anon still holds $LEFT1 REFERENCES/TRIGGER grants"
LEFT2="$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND grantee='authenticated' AND privilege_type='TRUNCATE'")"
[ "$LEFT2" = "0" ] || fail_case "authenticated still holds $LEFT2 TRUNCATE grants"
LEFT3="$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name='merchant_profiles' AND grantee='anon'")"
[ "$LEFT3" = "0" ] || fail_case "merchant_profiles still has $LEFT3 anon grants"
LEFT4="$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name='merchants' AND grantee='authenticated' AND privilege_type IN ('INSERT','DELETE','TRUNCATE')")"
[ "$LEFT4" = "0" ] || fail_case "merchants still has $LEFT4 authenticated DML grants"
echo "sweeps OK"

echo "== views: owner, barrier, SELECT-only"
for V in merchants_public products_public; do
  OWN="$(psql "$URLPOST" -X -q -A -t -c "SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner WHERE c.oid='public.$V'::regclass")"
  [ "$OWN" = "postgres" ] || fail_case "$V owner is $OWN"
  BAR="$(psql "$URLPOST" -X -q -A -t -c "SELECT c.reloptions::text FROM pg_class c WHERE c.oid='public.$V'::regclass")"
  case "$BAR" in *security_barrier=true*) ;; *) fail_case "$V missing security_barrier";; esac
  BAD="$(psql "$URLPOST" -X -q -A -t -c "SELECT grantee || ':' || privilege_type FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name='$V' AND grantee IN ('anon','authenticated') AND privilege_type <> 'SELECT'")"
  [ -z "$BAD" ] || fail_case "$V grants beyond SELECT: $BAD"
  N="$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name='$V' AND grantee IN ('anon','authenticated') AND privilege_type='SELECT'")"
  [ "$N" = "2" ] || fail_case "$V missing anon/authenticated SELECT"
done
echo "views OK"

echo "== NON-BREAKING: anon wildcard base-table reads still work after 449"
psql "$URLPOST" -X -q -A -t -c "SET ROLE anon; SET LOCAL request.jwt.claims='{}'; SELECT m.* FROM public.merchants m LIMIT 1" >/dev/null \
  || fail_case "anon wildcard SELECT m.* on merchants broke in 449 (that revoke is 450's job)"
psql "$URLPOST" -X -q -A -t -c "SET ROLE anon; SET LOCAL request.jwt.claims='{}'; SELECT p.* FROM public.products p LIMIT 1" >/dev/null \
  || fail_case "anon wildcard SELECT on products broke in 449 (that revoke is 450's job)"
echo "non-breaking OK"

echo "== twin seed + battery"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null   || fail_case "seed failed on pre DB"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_seed.sql" >/dev/null   || fail_case "seed failed on post DB"
psql "$URLPRE"  -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_battery.sql" >/tmp/zz449_bat_pre.out 2>/tmp/zz449_bat_pre.err \
  || { tail -20 /tmp/zz449_bat_pre.err; fail_case "battery failed on pre DB"; }
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_battery.sql" >/tmp/zz449_bat_post.out 2>/tmp/zz449_bat_post.err \
  || { tail -20 /tmp/zz449_bat_post.err; fail_case "battery failed on post DB"; }
diff /tmp/zz449_bat_pre.out /tmp/zz449_bat_post.out >/dev/null \
  || fail_case "battery stdout differs pre vs post: $(diff /tmp/zz449_bat_pre.out /tmp/zz449_bat_post.out | head -20)"
diff /tmp/zz449_bat_pre.err /tmp/zz449_bat_post.err >/dev/null \
  || fail_case "battery stderr differs pre vs post: $(diff /tmp/zz449_bat_pre.err /tmp/zz449_bat_post.err | head -20)"
echo "battery identical on both builds"

echo "== 447 suite (regression)"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/447_pos_sanity_caps_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "447 regression suite failed"; }
printf '%s\n' "$OUT" | grep -q "447 suite OK" || { printf '%s\n' "$OUT"; fail_case "447 suite marker missing"; }
echo "447 suite OK"

echo "== 448 suite (regression)"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/448_db_hardening_anon_surface_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "448 regression suite failed"; }
printf '%s\n' "$OUT" | grep -q "448 suite OK" || { printf '%s\n' "$OUT"; fail_case "448 suite marker missing"; }
echo "448 suite OK"

echo "== 449 suite"
OUT="$(psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$TESTS/449_customer_surface_hardening_test.sql" 2>&1)" \
  || { printf '%s\n' "$OUT"; fail_case "449 suite failed"; }
printf '%s\n' "$OUT" | grep -q "449 suite OK" || { printf '%s\n' "$OUT"; fail_case "449 suite marker missing"; }
echo "449 suite OK"

echo "== A0 negative drift test (tampered policy must abort 449)"
DBDRIFT="zz449drift_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBDRIFT\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE for drift test"
CREATED+=("$DBDRIFT")
URLDRIFT="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBDRIFT#")"
apply_chain_448 "$URLDRIFT"
psql "$URLDRIFT" -X -q -v ON_ERROR_STOP=1 -c "ALTER POLICY branches_view ON public.branches USING (true)" \
  || fail_case "drift setup failed"
if psql "$URLDRIFT" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null 2>/tmp/zz449_drift.err; then
  fail_case "449 applied despite a drifted policy (A0 pins not enforcing)"
fi
grep -q "A0: one or more re-point target policies drifted" /tmp/zz449_drift.err \
  || { cat /tmp/zz449_drift.err; fail_case "449 failed on drift but with the wrong error"; }
echo "drift test OK (A0 aborts on tampered policy)"

echo "== A0 column-ACL guard (seeded column grant must abort before any mutation)"
DBCOL="zz449col_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBCOL\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE for column-ACL test"
CREATED+=("$DBCOL")
URLCOL="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBCOL#")"
apply_chain_448 "$URLCOL"
# a privilege class 449 revokes at table level (the anon REFERENCES sweep):
# an explicit column grant here would be stripped silently without the guard
psql "$URLCOL" -X -q -v ON_ERROR_STOP=1 -c "GRANT REFERENCES (status) ON public.merchants TO anon" \
  || fail_case "column-ACL seed failed"
if psql "$URLCOL" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null 2>/tmp/zz449_col.err; then
  fail_case "449 applied despite a seeded explicit column grant in a revoked class"
fi
grep -q "A0: explicit column-level grants exist" /tmp/zz449_col.err \
  || { tail -5 /tmp/zz449_col.err; fail_case "449 aborted with the wrong error"; }
[ "$(psql "$URLCOL" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('_449_revoked_grants','merchants_public','products_public')")" = "0" ] \
  || fail_case "A0 column-ACL abort happened after mutations"
echo "A0 column-ACL guard OK (seeded column grant aborts 449 before any mutation)"

echo "== A0 column-ACL guard on the PostGIS catalogs (section 7 strips column ACLs too)"
DBCOL2="zz449col2_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBCOL2\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE for catalog column-ACL test"
CREATED+=("$DBCOL2")
URLCOL2="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBCOL2#")"
apply_chain_448 "$URLCOL2"
psql "$URLCOL2" -X -q -v ON_ERROR_STOP=1 -c "GRANT SELECT (srid) ON public.spatial_ref_sys TO anon" \
  || fail_case "catalog column-ACL seed failed"
if psql "$URLCOL2" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null 2>/tmp/zz449_col2.err; then
  fail_case "449 applied despite a seeded catalog column grant"
fi
grep -q "A0: explicit column-level grants exist" /tmp/zz449_col2.err \
  || { tail -5 /tmp/zz449_col2.err; fail_case "449 aborted with the wrong error (catalog seed)"; }
[ "$(psql "$URLCOL2" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('_449_revoked_grants','merchants_public','products_public')")" = "0" ] \
  || fail_case "A0 catalog column-ACL abort happened after mutations"
echo "A0 catalog column-ACL guard OK (seeded catalog column grant aborts 449 before any mutation)"

echo "== rollback strict-failure path (unrestorable row must abort + keep snapshot)"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -c "ALTER TABLE public.merchant_profiles RENAME TO zz449_moved" \
  || fail_case "strict-failure setup failed"
if psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$HERE/../rollback/449_customer_surface_hardening_rollback.sql" >/dev/null 2>/tmp/zz449_rb_fail.err; then
  fail_case "rollback succeeded despite an unrestorable table"
fi
grep -q "449 rollback:" /tmp/zz449_rb_fail.err \
  || { tail -5 /tmp/zz449_rb_fail.err; fail_case "rollback aborted with the wrong error"; }
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='_449_revoked_grants'")" = "1" ] \
  || fail_case "snapshot table lost after aborted rollback"
[ "$(psql "$URLPOST" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='merchants_public'")" = "1" ] \
  || fail_case "aborted rollback was not all-or-nothing (merchants_public gone)"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -c "ALTER TABLE public.zz449_moved RENAME TO merchant_profiles" \
  || fail_case "strict-failure restore failed"
echo "strict-failure path OK (aborted, snapshot kept, all-or-nothing)"

echo "== rollback exercise: run the rollback file, diff against pre-449"
psql "$URLPOST" -X -q -v ON_ERROR_STOP=1 -f "$HERE/../rollback/449_customer_surface_hardening_rollback.sql" >/dev/null \
  || fail_case "rollback file failed to apply"
psql "$URLPOST" -X -q -A -t -c "$POLSQL" > /tmp/zz449_policies_rolledback.txt
diff /tmp/zz449_policies_post_448.txt /tmp/zz449_policies_rolledback.txt >/dev/null \
  || fail_case "policies after rollback differ from pre-449: $(diff /tmp/zz449_policies_post_448.txt /tmp/zz449_policies_rolledback.txt | head -10)"
[ "$(md5sig "$CAMP_SIG" "$URLPOST")" = "$CAMP_PRE_MD5" ] || fail_case "campaigns body not restored"
[ "$(md5sig "$GUARD_SIG" "$URLPOST")" = "$GUARD_PRE_MD5" ] || fail_case "guard body not restored"
psql "$URLPOST" -X -q -A -t -c "$FUNSQL" > /tmp/zz449_funs_after.txt
diff /tmp/zz449_funs_before.txt /tmp/zz449_funs_after.txt >/dev/null \
  || fail_case "function ACLs changed: $(diff /tmp/zz449_funs_before.txt /tmp/zz449_funs_after.txt)"
for OBJ in merchants_public products_public get_my_merchant_profile get_my_products admin_get_merchant_contacts admin_get_merchant_products _merchant_is_active _product_merchant_id _provider_is_owner _provider_region_id _actor_is_seller _owns_merchant_row; do
  FOUND="$(psql "$URLPOST" -X -q -A -t -c "SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='$OBJ') + (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='$OBJ')")"
  [ "$FOUND" = "0" ] || fail_case "449 object $OBJ survived the rollback"
done
psql "$URLPOST" -X -q -A -t -c "$ACLSQL" > /tmp/zz449_acls_after.txt
diff /tmp/zz449_acls_before.txt /tmp/zz449_acls_after.txt > /tmp/zz449_acls.diff || true
# The ONLY permitted delta: the rollback's PostGIS re-grants add rows the
# local template never had (local lacks the supabase_admin-granted ALL on
# the 3 catalogs; prod has them - the rollback restores the prod pre-image).
# diff '>' lines are "table|grantee|privilege|grantor|grantable"; the only
# permitted delta is the zz449 fixture table (created by the seed AFTER the
# pre-449 snapshot; not real schema). PostGIS rows must restore exactly,
# including the supabase_admin grantor.
UNEXPECTED="$(grep '^>' /tmp/zz449_acls.diff | grep -vE '^> zz449\|' || true)"
[ -z "$UNEXPECTED" ] || fail_case "rollback ACL restore inexact: $UNEXPECTED"
[ -z "$(grep '^<' /tmp/zz449_acls.diff || true)" ] || fail_case "rollback lost pre-449 grants: $(grep '^<' /tmp/zz449_acls.diff | head)"
echo "rollback OK (policies + bodies + table/function ACLs exact incl. grantor/grantable)"

echo "== degraded PostGIS path (prod posture: unrevocable grants + missing catalog)"
# Reproduce PROD exactly: the migration role cannot revoke the
# supabase_admin-granted PostGIS rows (local postgres is superuser, so flip
# it to NOSUPERUSER for this test only), cannot SET ROLE supabase_admin,
# and one catalog is missing. 449 must still apply: warn, keep the residual
# OPEN, and reconcile the snapshot to only actually-removed rows.
DBDEG="zz449deg_$(date +%s)_$RANDOM"
psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$DBDEG\" TEMPLATE \"$TEMPLATE\"" \
  || fail_case "could not clone $TEMPLATE for degraded test"
CREATED+=("$DBDEG")
URLDEG="$(printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$DBDEG#")"
apply_chain_448 "$URLDEG"
# a genuinely missing catalog (extension membership dropped first)
psql "$URLDEG" -X -q -v ON_ERROR_STOP=1 -c "ALTER EXTENSION postgis DROP TABLE public.spatial_ref_sys; DROP TABLE public.spatial_ref_sys" \
  || fail_case "degraded setup (drop catalog) failed"
# Applier with prod-like powers: a NON-superuser owner of the schema (like
# prod's postgres role) that is NOT a member of supabase_admin, so it cannot
# revoke supabase_admin-granted rows and cannot SET ROLE - exactly why the
# prod residual stays open. The 3 PostGIS catalogs are owned by
# supabase_admin, mirroring prod ownership.
psql "$ADMIN_URL" -X -q -v ON_ERROR_STOP=1 -c "DROP ROLE IF EXISTS zz449_migrator; CREATE ROLE zz449_migrator LOGIN NOSUPERUSER" \
  || fail_case "degraded setup (migrator role) failed"
psql "$URLDEG" -X -q -v ON_ERROR_STOP=1 -c "ALTER DATABASE \"$DBDEG\" OWNER TO zz449_migrator" \
  || fail_case "degraded setup (db owner) failed"
psql "$URLDEG" -X -q -v ON_ERROR_STOP=1 -c "
  ALTER SCHEMA public OWNER TO zz449_migrator;
  GRANT USAGE ON SCHEMA auth TO zz449_migrator;" \
  || fail_case "degraded setup (schema rights) failed"
psql "$URLDEG" -X -q -v ON_ERROR_STOP=1 <<'XFER' || fail_case "degraded setup (ownership transfer) failed"
DO $xfer$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, c.relname AS name, c.relkind AS kind
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relowner = 'postgres'::regrole
       AND n.nspname NOT LIKE 'pg\_%' ESCAPE '\' AND n.nspname <> 'information_schema'
       AND c.relkind IN ('r','p','v','m')
       AND NOT EXISTS (SELECT 1 FROM pg_depend d
                        WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e')
  LOOP
    -- indexes and linked sequences follow their table automatically
    EXECUTE CASE r.kind
      WHEN 'v' THEN format('ALTER VIEW %I.%I OWNER TO zz449_migrator', r.sch, r.name)
      WHEN 'm' THEN format('ALTER MATERIALIZED VIEW %I.%I OWNER TO zz449_migrator', r.sch, r.name)
      ELSE format('ALTER TABLE %I.%I OWNER TO zz449_migrator', r.sch, r.name) END;
  END LOOP;
  FOR r IN
    SELECT n.nspname AS sch, p.proname AS name,
           pg_get_function_identity_arguments(p.oid) AS args, p.prokind AS kind
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE p.proowner = 'postgres'::regrole
       AND n.nspname NOT LIKE 'pg\_%' ESCAPE '\' AND n.nspname <> 'information_schema'
       AND NOT EXISTS (SELECT 1 FROM pg_depend d
                        WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
  LOOP
    EXECUTE format('ALTER %s %I.%I(%s) OWNER TO zz449_migrator',
      CASE r.kind WHEN 'a' THEN 'AGGREGATE' WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
      r.sch, r.name, r.args);
  END LOOP;
END $xfer$;
XFER
# the 3 PostGIS catalogs are owned by supabase_admin, mirroring prod
psql "$URLDEG" -X -q -v ON_ERROR_STOP=1 -c "
  ALTER VIEW public.geography_columns OWNER TO supabase_admin;
  ALTER VIEW public.geometry_columns OWNER TO supabase_admin;" \
  || fail_case "degraded setup (catalog owners) failed"
URLDEG_MIG="$(printf '%s' "$URLDEG" | sed -E 's#(postgres://)[^:@/]+@#\1zz449_migrator@#')"
psql "$URLDEG_MIG" -X -q -v ON_ERROR_STOP=1 -f "$MIG/449_customer_surface_hardening.sql" >/dev/null 2>/tmp/zz449_deg.err \
  || { tail -5 /tmp/zz449_deg.err; fail_case "449 must NOT fail on the prod PostGIS posture"; }
grep -q "PostGIS residual revoke incomplete on geography_columns" /tmp/zz449_deg.err \
  || fail_case "degraded path did not warn for geography_columns: $(grep -i warning /tmp/zz449_deg.err | head -3)"
grep -q "PostGIS residual revoke incomplete on geometry_columns" /tmp/zz449_deg.err \
  || fail_case "degraded path did not warn for geometry_columns: $(grep -i warning /tmp/zz449_deg.err | head -3)"
RESIDUAL="$(psql "$URLDEG" -X -q -A -t -c "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='public' AND table_name IN ('geography_columns','geometry_columns') AND grantee IN ('anon','authenticated')")"
[ "$RESIDUAL" -gt 0 ] || fail_case "degraded residual vanished (should stay open)"
# the global sweeps must EXCLUDE the catalogs: their sweep-class rows
# (anon REFERENCES/TRIGGER, authenticated TRUNCATE) survive the apply
[ "$(psql "$URLDEG" -X -q -A -t -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(c.relacl) x JOIN pg_roles g ON g.oid=x.grantee WHERE n.nspname='public' AND c.relname IN ('geography_columns','geometry_columns') AND ((g.rolname='anon' AND x.privilege_type IN ('REFERENCES','TRIGGER')) OR (g.rolname='authenticated' AND x.privilege_type='TRUNCATE'))")" = "6" ] \
  || fail_case "sweeps touched the PostGIS catalogs (must be excluded, section 7 owns them)"
[ "$(psql "$URLDEG" -X -q -A -t -c "SELECT count(*) FROM public._449_revoked_grants WHERE tbl IN ('geography_columns','geometry_columns','spatial_ref_sys')")" = "0" ] \
  || fail_case "snapshot holds rows for unrevoked PostGIS grants"
psql "$URLDEG" -X -q -A -t -c "SELECT 1 FROM public.merchants_public LIMIT 1" >/dev/null \
  || fail_case "degraded apply incomplete"
echo "degraded PostGIS path OK (2 catalogs residual-open + warned, 1 missing skipped, snapshot reconciled, apply completed)"

echo "ALL OK"
