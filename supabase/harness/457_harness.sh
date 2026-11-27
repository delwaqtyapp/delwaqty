#!/usr/bin/env bash
# 457 harness: refund requests. On THROWAWAY clones of h435_template:
#  GREEN: apply the REAL 457 (twice); request/review RPC behavior, RLS and grants, wallet credit once,
#         audit rows, self-review block, permission gate.
#  RED:   a deliberately broken copy (permission check removed from admin_review_refund) must FAIL.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes.
# Usage: HARNESS_CONFIRM_DISPOSABLE=yes ./457_harness.sh "postgres://postgres@localhost:54322/postgres"
# Exit: 0 pass; 1 safety refusal; 2 case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/457_refund_requests.sql"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 457_harness.sh <admin-db-url>}"
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
mk() { local n="zz457${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
OWN=00000000-0000-0000-0000-000000457a01   # platform owner (reviewer)
CUS=00000000-0000-0000-0000-000000457a02   # customer
OTH=00000000-0000-0000-0000-000000457a03   # another customer
O_OK=00000000-0000-0000-0000-0000004570a1  # delivered+paid, 100
O_PEND=00000000-0000-0000-0000-0000004570a2 # pending
O_UNPAID=00000000-0000-0000-0000-0000004570a3 # delivered, unpaid
O_OLD=00000000-0000-0000-0000-0000004570a4 # delivered+paid, 20 days old
O_PART=00000000-0000-0000-0000-0000004570a5 # delivered+paid, 100 (partial approve)
O_OWN=00000000-0000-0000-0000-0000004570a6 # the owner's own order (self review)
O_REJ=00000000-0000-0000-0000-0000004570a7 # reject then re-request
prep() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$f\$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''))::uuid \$f\$;
  INSERT INTO auth.users(id,email) VALUES ('$OWN','o457@x.i'),('$CUS','c457@x.i'),('$OTH','t457@x.i');
  INSERT INTO public.users(id,email,role) VALUES ('$OWN','o457@x.i','owner'),('$CUS','c457@x.i','customer'),('$OTH','t457@x.i','customer') ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO public.orders(id,user_id,status,payment_status,subtotal,total_amount,created_at,merchant_name) VALUES
   ('$O_OK','$CUS','delivered','paid',100,100,now(),'m'),
   ('$O_PEND','$CUS','pending','paid',100,100,now(),'m'),
   ('$O_UNPAID','$CUS','delivered','pending',100,100,now(),'m'),
   ('$O_OLD','$CUS','delivered','paid',100,100,now()-interval '20 days','m'),
   ('$O_PART','$CUS','delivered','paid',100,100,now(),'m'),
   ('$O_OWN','$OWN','delivered','paid',100,100,now(),'m'),
   ('$O_REJ','$CUS','delivered','paid',100,100,now(),'m');" || fail_case "prep failed"; }
# as URL UID SQL [role] -> prints the single result line, or 'ERR' on error
as() { local out; out=$(psql "$1" -X -At -v ON_ERROR_STOP=1 -c "select set_config('request.jwt.claims','{\"sub\":\"$2\"}',false)" -c "set role ${4:-authenticated}" -c "$3" 2>/tmp/h457.err) || { echo ERR; return 0; }; printf '%s\n' "$out" | tail -1; }
code() { as "$1" "$2" "select ($3)->>'code'"; }
val() { psql "$1" -X -At -c "$2"; }
check() { local U="$1" bad=0 r n rid
  want() { [ "$2" = "$3" ] || { echo "$1: got '$2' want '$3'"; bad=1; }; }
  # --- request_refund
  r=$(code "$U" $OTH "public.request_refund('$O_OK','missing_item')"); want "other user's order" "$r" NOT_FOUND
  r=$(code "$U" $CUS "public.request_refund('$O_PEND','late')"); want "not delivered" "$r" NOT_DELIVERED
  r=$(code "$U" $CUS "public.request_refund('$O_UNPAID','late')"); want "not paid" "$r" NOT_REFUNDABLE
  r=$(code "$U" $CUS "public.request_refund('$O_OLD','late')"); want "window" "$r" WINDOW_EXPIRED
  r=$(code "$U" $CUS "public.request_refund('$O_OK','bogus')"); want "bad reason" "$r" INVALID_REASON
  r=$(code "$U" $CUS "public.request_refund('$O_OK','late',null,150)"); want "amount over total" "$r" INVALID_AMOUNT
  r=$(code "$U" $CUS "public.request_refund('$O_OK','late',null,0)"); want "zero amount" "$r" INVALID_AMOUNT
  r=$(as "$U" "" "select (public.request_refund('$O_OK','late'))->>'code'" anon); [ "$r" = ERR ] || { echo "anon can execute request_refund"; bad=1; }
  r=$(code "$U" $CUS "public.request_refund('$O_OK','missing_item','one item missing')"); want "valid request" "$r" OK
  r=$(code "$U" $CUS "public.request_refund('$O_OK','late')"); want "duplicate" "$r" ALREADY_REQUESTED
  rid=$(val "$U" "select id from public.refund_requests where order_id='$O_OK'")
  n=$(val "$U" "select count(*) from public.audit_log where action='REFUND_REQUESTED' and resource_id='$rid'"); want "request audited" "$n" 1
  # --- RLS and grants
  r=$(as "$U" $CUS "insert into public.refund_requests(order_id,user_id,amount,reason_code) values ('$O_PART','$CUS',1,'late')"); [ "$r" = ERR ] || { echo "direct insert allowed"; bad=1; }
  r=$(as "$U" $CUS "update public.refund_requests set status='approved' where id='$rid'"); [ "$r" = ERR ] || { echo "direct update allowed"; bad=1; }
  r=$(as "$U" $CUS "delete from public.refund_requests where id='$rid'"); [ "$r" = ERR ] || { echo "direct delete allowed"; bad=1; }
  r=$(as "$U" "" "select count(*) from public.refund_requests" anon); [ "$r" = ERR ] || { echo "anon select allowed"; bad=1; }
  n=$(as "$U" $CUS "select count(*) from public.refund_requests"); want "customer sees own" "$n" 1
  n=$(as "$U" $OTH "select count(*) from public.refund_requests"); want "other customer sees none" "$n" 0
  n=$(as "$U" $OWN "select count(*) from public.refund_requests"); want "reviewer sees all" "$n" 1
  # --- permission gate
  r=$(code "$U" $CUS "public.admin_review_refund('$rid',true)"); want "customer review" "$r" FORBIDDEN
  r=$(code "$U" $OTH "public.admin_review_refund('$rid',true)"); want "other customer review" "$r" FORBIDDEN
  r=$(code "$U" $CUS "public.admin_list_refund_requests()"); want "customer list" "$r" FORBIDDEN
  r=$(code "$U" $OWN "public.admin_list_refund_requests()"); want "owner list" "$r" OK
  n=$(as "$U" $OWN "select jsonb_array_length((public.admin_list_refund_requests())->'requests')"); want "list content" "$n" 1
  # --- reject path then re-request
  r=$(code "$U" $CUS "public.request_refund('$O_REJ','quality')"); want "req for reject" "$r" OK
  local rj; rj=$(val "$U" "select id from public.refund_requests where order_id='$O_REJ'")
  r=$(code "$U" $OWN "public.admin_review_refund('$rj',false)"); want "reject w/o note" "$r" NOTE_REQUIRED
  r=$(code "$U" $OWN "public.admin_review_refund('$rj',false,'not eligible')"); want "reject" "$r" OK
  r=$(code "$U" $OWN "public.admin_review_refund('$rj',true)"); want "review twice" "$r" INVALID_STATUS
  n=$(val "$U" "select count(*) from public.wallet_transactions where reference_id='$rj'"); want "reject no credit" "$n" 0
  r=$(code "$U" $CUS "public.request_refund('$O_REJ','quality')"); want "re-request after reject" "$r" OK
  # --- approve full: credit once, order refunded, audited
  r=$(code "$U" $OWN "public.admin_review_refund('$rid',true,'ok')"); want "approve" "$r" OK
  n=$(val "$U" "select balance from public.wallets where user_id='$CUS'"); want "wallet credited 100" "${n%.*}" 100
  n=$(val "$U" "select count(*) from public.wallet_transactions where reference_id='$rid' and amount=100 and reference_type='refund_request'"); want "ledger row" "$n" 1
  n=$(val "$U" "select payment_status from public.orders where id='$O_OK'"); want "order refunded" "$n" refunded
  r=$(code "$U" $OWN "public.admin_review_refund('$rid',true)"); want "approve twice" "$r" INVALID_STATUS
  n=$(val "$U" "select balance from public.wallets where user_id='$CUS'"); want "no double credit" "${n%.*}" 100
  n=$(val "$U" "select count(*) from public.audit_log where action in ('REFUND_APPROVED','REFUND_REJECTED')"); want "review audited" "$n" 2
  r=$(code "$U" $CUS "public.request_refund('$O_OK','late')"); want "refunded order not re-requestable" "$r" NOT_REFUNDABLE
  # --- partial approve keeps order paid
  r=$(code "$U" $CUS "public.request_refund('$O_PART','damaged')"); want "req partial" "$r" OK
  local pr; pr=$(val "$U" "select id from public.refund_requests where order_id='$O_PART'")
  r=$(code "$U" $OWN "public.admin_review_refund('$pr',true,null,150)"); want "approve over total" "$r" INVALID_AMOUNT
  r=$(code "$U" $OWN "public.admin_review_refund('$pr',true,null,30)"); want "approve 30" "$r" OK
  n=$(val "$U" "select payment_status from public.orders where id='$O_PART'"); want "partial stays paid" "$n" paid
  n=$(val "$U" "select balance from public.wallets where user_id='$CUS'"); want "wallet 130" "${n%.*}" 130
  # --- self review blocked
  r=$(code "$U" $OWN "public.request_refund('$O_OWN','other')"); want "owner own request" "$r" OK
  local sr; sr=$(val "$U" "select id from public.refund_requests where order_id='$O_OWN'")
  r=$(code "$U" $OWN "public.admin_review_refund('$sr',true)"); want "self review" "$r" SELF_REVIEW_NOT_ALLOWED
  return $bad; }
echo "== GREEN: real 457"
G="$(mk g)"; prep "$G"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "457 apply failed"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "457 re-apply failed"
check "$G" || fail_case "green assertions failed"
echo "green OK: request guards, RLS and grants, permission gate, reject then re-request, approve credits once and marks refunded, partial keeps paid, audit rows, self-review blocked, re-apply clean"
echo "== RED: broken copy (reviewer permission check removed) must fail"
BROKEN=$(mktemp); sed "s/IF v_uid IS NULL OR NOT public.has_financial_permission(v_uid, 'review_refund') THEN/IF v_uid IS NULL THEN/" "$MIG" > "$BROKEN"
cmp -s "$BROKEN" "$MIG" && fail_case "red mutation did not change the file"
Rd="$(mk r)"; prep "$Rd"
psql "$Rd" -X -q -v ON_ERROR_STOP=1 -f "$BROKEN" >/dev/null 2>&1 || fail_case "broken apply failed"
if check "$Rd" >/tmp/h457.red 2>&1; then rm -f "$BROKEN"; fail_case "red run passed (assertions are not effective)"; fi
rm -f "$BROKEN"; echo "red OK, failed as required: $(tr '\n' ';' </tmp/h457.red)"
echo "ALL PASS"
