#!/usr/bin/env bash
# 458 harness: admin_list_payout_requests, exercised together with the REAL existing payout RPCs
# (merchant_request_payout, admin_review_payout) on THROWAWAY clones of h435_template.
#  GREEN: apply the REAL 458 (twice); owner lists the queue with merchant name+balance, a merchant owner
#         and anon cannot, invalid status refused, approve via admin_review_payout debits the ledger and the
#         list reflects it.
#  RED:   a broken copy (admin check removed) must FAIL.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes.
# Usage: HARNESS_CONFIRM_DISPOSABLE=yes ./458_harness.sh "postgres://postgres@localhost:54322/postgres"
# Exit: 0 pass; 1 safety refusal; 2 case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/458_admin_list_payout_requests.sql"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 458_harness.sh <admin-db-url>}"
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
mk() { local n="zz458${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
OWN=00000000-0000-0000-0000-000000458a01
MER=00000000-0000-0000-0000-000000458a02
M1=00000000-0000-0000-0000-0000004580a1
prep() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$f\$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''))::uuid \$f\$;
  INSERT INTO auth.users(id,email) VALUES ('$OWN','o458@x.i'),('$MER','m458@x.i');
  INSERT INTO public.users(id,email,role) VALUES ('$OWN','o458@x.i','owner'),('$MER','m458@x.i','merchant') ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.merchants(id,owner_user_id,name) VALUES ('$M1','$MER','Harness Kitchen');
  INSERT INTO public.merchant_ledger(merchant_id,entry_type,amount,description) VALUES ('$M1','credit',500,'seed');" || fail_case "prep failed"; }
as() { local out; out=$(psql "$1" -X -At -v ON_ERROR_STOP=1 -c "select set_config('request.jwt.claims','{\"sub\":\"$2\"}',false)" -c "set role ${4:-authenticated}" -c "$3" 2>/tmp/h458.err) || { echo ERR; return 0; }; printf '%s\n' "$out" | tail -1; }
code() { as "$1" "$2" "select ($3)->>'code'"; }
val() { psql "$1" -X -At -c "$2"; }
check() { local U="$1" bad=0 r n rid
  want() { [ "$2" = "$3" ] || { echo "$1: got '$2' want '$3'"; bad=1; }; }
  r=$(code "$U" $MER "public.merchant_request_payout(200,'$M1')"); [ -z "$r" ] || true
  rid=$(val "$U" "select id from public.merchant_payout_requests where merchant_id='$M1' and status='pending'"); [ -n "$rid" ] || { echo "no pending request created"; bad=1; }
  r=$(code "$U" $OWN "public.admin_list_payout_requests()"); want "owner list" "$r" OK
  n=$(as "$U" $OWN "select (public.admin_list_payout_requests())->'requests'->0->>'merchant_name'"); want "merchant name" "$n" "Harness Kitchen"
  n=$(as "$U" $OWN "select ((public.admin_list_payout_requests())->'requests'->0->>'merchant_balance')::numeric::int"); want "balance" "$n" 500
  r=$(code "$U" $MER "public.admin_list_payout_requests()"); want "merchant owner list" "$r" FORBIDDEN
  r=$(as "$U" "" "select (public.admin_list_payout_requests())->>'code'" anon); [ "$r" = ERR ] || { echo "anon can execute"; bad=1; }
  r=$(code "$U" $OWN "public.admin_list_payout_requests('bogus')"); want "invalid status" "$r" INVALID_STATUS
  r=$(code "$U" $MER "public.admin_review_payout('$rid',true)"); want "merchant cannot review" "$r" FORBIDDEN
  r=$(code "$U" $OWN "public.admin_review_payout('$rid',true)"); [ "$r" = "" ] || true
  n=$(val "$U" "select status from public.merchant_payout_requests where id='$rid'"); want "approved" "$n" approved
  n=$(val "$U" "select coalesce(sum(case when entry_type='credit' then amount else -amount end),0)::int from public.merchant_ledger where merchant_id='$M1'"); want "ledger debited" "$n" 300
  n=$(as "$U" $OWN "select jsonb_array_length((public.admin_list_payout_requests())->'requests')"); want "pending list now empty" "$n" 0
  n=$(as "$U" $OWN "select jsonb_array_length((public.admin_list_payout_requests('all'))->'requests')"); want "all list" "$n" 1
  return $bad; }
echo "== GREEN: real 458"
G="$(mk g)"; prep "$G"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "458 apply failed"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "458 re-apply failed"
check "$G" || fail_case "green assertions failed"
echo "green OK: owner lists with merchant name and balance; merchant owner and anon refused; invalid status refused; real admin_review_payout approves and debits the ledger; list reflects it; re-apply clean"
echo "== RED: broken copy (admin check removed) must fail"
BROKEN=$(mktemp); sed 's/IF auth.uid() IS NULL OR NOT public._is_country_admin_uid(auth.uid()) THEN/IF auth.uid() IS NULL THEN/' "$MIG" > "$BROKEN"
cmp -s "$BROKEN" "$MIG" && fail_case "red mutation did not change the file"
Rd="$(mk r)"; prep "$Rd"
psql "$Rd" -X -q -v ON_ERROR_STOP=1 -f "$BROKEN" >/dev/null 2>&1 || fail_case "broken apply failed"
if check "$Rd" >/tmp/h458.red 2>&1; then rm -f "$BROKEN"; fail_case "red run passed (assertions are not effective)"; fi
rm -f "$BROKEN"; echo "red OK, failed as required: $(tr '\n' ';' </tmp/h458.red)"
echo "ALL PASS"
