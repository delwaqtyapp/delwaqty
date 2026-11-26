#!/usr/bin/env bash
# 456 harness: category-images storage policies. On THROWAWAY clones of h435_template:
#  GREEN: apply the REAL 456; Owner may insert/update/delete under categories/, a non-owner
#         and anon may not, wrong bucket or wrong prefix is refused, public read stays,
#         the old service_role-only policies are gone; re-apply is clean.
#  RED:   a deliberately broken copy (owner check removed) must FAIL the same assertions.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes.
# Usage: HARNESS_CONFIRM_DISPOSABLE=yes ./456_harness.sh "postgres://postgres@localhost:54322/postgres"
# Exit: 0 pass; 1 safety refusal; 2 case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/456_category_images_owner_storage.sql"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 456_harness.sh <admin-db-url>}"
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
mk() { local n="zz456${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
OWN=00000000-0000-0000-0000-000000456a01
USR=00000000-0000-0000-0000-000000456a02
prep() { psql "$1" -X -q -v ON_ERROR_STOP=1 -c "
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS \$f\$ SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''))::uuid \$f\$;
  ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
  GRANT USAGE ON SCHEMA storage TO authenticated, anon;
  GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated, anon;
  INSERT INTO auth.users(id,email) VALUES ('$OWN','o456@x.i'),('$USR','u456@x.i');
  INSERT INTO public.users(id,email,role) VALUES ('$OWN','o456@x.i','owner'),('$USR','u456@x.i','customer') ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  INSERT INTO storage.objects(bucket_id,name) VALUES ('category-images','categories/seed/a.png');" || fail_case "prep failed"; }
# run SQL as a role/user; prints 'ok' or 'denied'
as() { # url uid sql
  psql "$1" -X -At -v ON_ERROR_STOP=1 -c "select set_config('request.jwt.claims','{\"sub\":\"$2\"}',false)" -c "set role ${4:-authenticated}" -c "$3" >/dev/null 2>/tmp/h456.err && echo ok || echo denied; }
rows() { psql "$1" -X -At -c "$2"; }
check() { # url label  -> returns 0 if all assertions hold
  local U="$1" bad=0 r
  r=$(as "$U" $OWN "insert into storage.objects(bucket_id,name) values ('category-images','categories/c1/x.png')"); [ "$r" = ok ] || { echo "owner insert: $r"; bad=1; }
  r=$(as "$U" $OWN "update storage.objects set owner='$OWN' where name='categories/c1/x.png'; select 1/(count(*)) from storage.objects where owner='$OWN'"); [ "$r" = ok ] || { echo "owner update: $r"; bad=1; }
  r=$(as "$U" $OWN "delete from storage.objects where name='categories/c1/x.png'; select 1/(1-count(*)) from storage.objects where name='categories/c1/x.png'"); [ "$r" = ok ] || { echo "owner delete: $r"; bad=1; }
  r=$(as "$U" $USR "insert into storage.objects(bucket_id,name) values ('category-images','categories/c2/x.png')"); [ "$r" = denied ] || { echo "non-owner insert allowed"; bad=1; }
  r=$(as "$U" $USR "update storage.objects set owner='$USR' where name='categories/seed/a.png'; select 1/(count(*)) from storage.objects where owner='$USR'"); [ "$r" = denied ] || { echo "non-owner update allowed"; bad=1; }
  r=$(as "$U" $USR "delete from storage.objects where name='categories/seed/a.png'; select 1/(1-count(*)) from storage.objects where name='categories/seed/a.png'"); [ "$r" = denied ] || { echo "non-owner delete allowed"; bad=1; }
  r=$(as "$U" $OWN "insert into storage.objects(bucket_id,name) values ('category-images','other/x.png')"); [ "$r" = denied ] || { echo "wrong prefix allowed"; bad=1; }
  r=$(as "$U" $OWN "insert into storage.objects(bucket_id,name) values ('profiles','categories/x.png')"); [ "$r" = denied ] || { echo "wrong bucket allowed"; bad=1; }
  r=$(as "$U" $OWN "insert into storage.objects(bucket_id,name) values ('category-images','categories/c3/x.png')" anon); [ "$r" = denied ] || { echo "anon insert allowed"; bad=1; }
  n=$(rows "$U" "select count(*) from pg_policies where schemaname='storage' and tablename='objects' and policyname in ('Category images admin upload','Category images admin delete')"); [ "$n" = 0 ] || { echo "old policies remain"; bad=1; }
  n=$(rows "$U" "select count(*) from pg_policies where schemaname='storage' and tablename='objects' and policyname = 'Category images public read'"); [ "$n" = 1 ] || { echo "public read lost"; bad=1; }
  return $bad; }
echo "== GREEN: real 456"
G="$(mk g)"; prep "$G"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "456 apply failed"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "456 re-apply failed"
check "$G" || fail_case "green assertions failed"
echo "green OK: owner insert/update/delete allowed; non-owner, anon, wrong prefix, wrong bucket denied; old policies gone; public read kept; re-apply clean"
echo "== RED: broken copy (owner check removed) must fail"
BROKEN=$(mktemp); sed 's/AND public._is_owner_uid(auth.uid())//' "$MIG" > "$BROKEN"
Rd="$(mk r)"; prep "$Rd"
psql "$Rd" -X -q -v ON_ERROR_STOP=1 -f "$BROKEN" >/dev/null 2>&1 || fail_case "broken apply failed"
if check "$Rd" >/tmp/h456.red 2>&1; then rm -f "$BROKEN"; fail_case "red run passed (assertions are not effective)"; fi
rm -f "$BROKEN"; echo "red OK, failed as required: $(tr '\n' ';' </tmp/h456.red)"
echo "ALL PASS"
