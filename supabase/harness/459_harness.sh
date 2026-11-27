#!/usr/bin/env bash
# 459 harness (template predates 449, so prep adds the 449 _owns_merchant_row helper and the auth schema usage grant that Supabase has): review integrity (one review per order, reply/name fields locked for customers, insert guard),
# exercised with the REAL reply_to_merchant_review RPC on THROWAWAY clones of h435_template.
#  GREEN: apply the REAL 459 (twice); duplicate order review refused (23505); customer cannot fake reply or name on
#         insert or update; customer comment edit still works; merchant owner reply via RPC works; second order ok.
#  RED:   a broken copy (unique index removed) must FAIL.
#  RED:   a broken copy (admin check removed) must FAIL.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes.
# Usage: HARNESS_CONFIRM_DISPOSABLE=yes ./459_harness.sh "postgres://postgres@localhost:54322/postgres"
# Exit: 0 pass; 1 safety refusal; 2 case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/459_review_integrity.sql"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 459_harness.sh <admin-db-url>}"
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
mk() { local n="zz459${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
CUS=00000000-0000-0000-0000-000000459a01
MER=00000000-0000-0000-0000-000000459a02
OTH=00000000-0000-0000-0000-000000459a03
M1=00000000-0000-0000-0000-0000004590a1
O1=00000000-0000-0000-0000-0000004591a1
O2=00000000-0000-0000-0000-0000004591a2
prep() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$f\$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''))::uuid \$f\$;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  CREATE OR REPLACE FUNCTION public._owns_merchant_row(p_merchant_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS \$f\$ SELECT EXISTS (SELECT 1 FROM public.merchants m WHERE m.id = p_merchant_id AND m.owner_user_id = auth.uid()) \$f\$;
  GRANT EXECUTE ON FUNCTION public._owns_merchant_row(uuid) TO authenticated;
  INSERT INTO auth.users(id,email) VALUES ('$CUS','c459@x.i'),('$MER','m459@x.i'),('$OTH','t459@x.i');
  INSERT INTO public.users(id,email,role,full_name) VALUES ('$CUS','c459@x.i','customer','Alice Real'),('$MER','m459@x.i','merchant','Mo'),('$OTH','t459@x.i','customer','Other') ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role, full_name=EXCLUDED.full_name;
  INSERT INTO public.merchants(id,owner_user_id,name,status) VALUES ('$M1','$MER','Harness Kitchen','active');
  INSERT INTO public.orders(id,user_id,merchant_id,status,payment_status,subtotal,total_amount,merchant_name) VALUES
    ('$O1','$CUS','$M1','delivered','paid',50,50,'Harness Kitchen'),('$O2','$CUS','$M1','delivered','paid',60,60,'Harness Kitchen');" || fail_case "prep failed"; }
as() { local out; out=$(psql "$1" -X -At -v ON_ERROR_STOP=1 -c "select set_config('request.jwt.claims','{\"sub\":\"$2\"}',false)" -c "set role ${4:-authenticated}" -c "$3" 2>/tmp/h459.err) || { echo "ERR:$(tr -d '\n' </tmp/h459.err | cut -c1-90)"; return 0; }; printf '%s\n' "$out" | tail -1; }
val() { psql "$1" -X -At -c "$2"; }
check() { local U="$1" bad=0 r n rid
  want() { [ "$2" = "$3" ] || { echo "$1: got '$2' want '$3'"; bad=1; }; }
  r=$(as "$U" $CUS "insert into public.reviews(user_id,merchant_id,order_id,rating,comment,merchant_reply,user_name,merchant_replied_at) values ('$CUS','$M1','$O1',5,'great','FAKE REPLY','Fake Name',now()) returning id"); [ "${r#ERR}" = "$r" ] || { echo "first review insert failed: $r"; bad=1; }
  rid=$(val "$U" "select id from public.reviews where order_id='$O1'")
  n=$(val "$U" "select coalesce(merchant_reply,'-')||'|'||coalesce(user_name,'-')||'|'||(merchant_replied_at is null)::text from public.reviews where id='$rid'"); want "insert guard strips reply, takes profile name" "$n" "-|Alice Real|true"
  r=$(as "$U" $CUS "insert into public.reviews(user_id,merchant_id,order_id,rating) values ('$CUS','$M1','$O1',4)"); case "$r" in ERR*unique*|ERR*duplicate*) ;; *) echo "duplicate order review not refused: $r"; bad=1;; esac
  r=$(as "$U" $CUS "update public.reviews set merchant_reply='faked' where id='$rid'"); case "$r" in ERR*merchant*) ;; *) echo "customer could write merchant_reply: $r"; bad=1;; esac
  r=$(as "$U" $CUS "update public.reviews set user_name='Evil' where id='$rid'"); case "$r" in ERR*name*) ;; *) echo "customer could change user_name: $r"; bad=1;; esac
  as "$U" $CUS "update public.reviews set comment='edited' where id='$rid'" >/dev/null; n=$(val "$U" "select comment from public.reviews where id='$rid'"); want "customer comment edit" "$n" edited
  r=$(as "$U" $MER "select public.reply_to_merchant_review('$rid','thanks')"); want "merchant reply RPC" "$r" t
  n=$(val "$U" "select merchant_reply from public.reviews where id='$rid'"); want "reply stored" "$n" thanks
  r=$(as "$U" $OTH "select public.reply_to_merchant_review('$rid','hijack')"); case "$r" in ERR*) ;; *) echo "non-owner replied: $r"; bad=1;; esac
  r=$(as "$U" $CUS "insert into public.reviews(user_id,merchant_id,order_id,rating) values ('$CUS','$M1','$O2',4) returning id"); [ "${r#ERR}" = "$r" ] || { echo "second order review refused: $r"; bad=1; }
  return $bad; }
echo "== GREEN: real 459"
G="$(mk g)"; prep "$G"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "459 apply failed"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "459 re-apply failed"
check "$G" || fail_case "green assertions failed"
echo "green OK: duplicate order review refused; fake reply/name stripped or refused for customers; comment edit and merchant reply RPC work; non-owner reply refused; second order ok; re-apply clean"
echo "== RED: broken copy (unique index removed, freeze not tightened) must fail"
BROKEN=$(mktemp); sed -e 's/CREATE UNIQUE INDEX IF NOT EXISTS reviews_one_per_order/CREATE INDEX IF NOT EXISTS reviews_one_per_order/' -e "s/IF NEW.user_name IS DISTINCT FROM OLD.user_name THEN/IF false THEN/" "$MIG" > "$BROKEN"
cmp -s "$BROKEN" "$MIG" && fail_case "red mutation did not change the file"
Rd="$(mk r)"; prep "$Rd"
psql "$Rd" -X -q -v ON_ERROR_STOP=1 -f "$BROKEN" >/dev/null 2>&1 || fail_case "broken apply failed"
if check "$Rd" >/tmp/h459.red 2>&1; then rm -f "$BROKEN"; fail_case "red run passed (assertions are not effective)"; fi
rm -f "$BROKEN"; echo "red OK, failed as required: $(tr '\n' ';' </tmp/h459.red)"
echo "ALL PASS"
