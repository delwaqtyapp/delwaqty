#!/usr/bin/env bash
# 460 harness: remove SOS. THROWAWAY clones of h435_template (it predates later migrations, so the four redefined
# functions are checked structurally: they apply, and no longer reference sos_alerts; real behaviour of those
# bodies is the live prod text minus the SOS lines, diffed in the PR description).
#  GREEN: confirm the template has sos_alerts, apply the REAL 460 (twice); sos_alerts, notify_sos_alert, open_emergency_chat,
#         resolve_sos_alert are gone; the 4 redefined functions exist and no longer mention sos_alerts.
#  RED:   a broken copy (DROP TABLE removed) must FAIL.
# SAFETY: localhost only, prod/staging refs refused, HARNESS_CONFIRM_DISPOSABLE=yes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../migrations/460_remove_sos.sql"
TEMPLATE="h435_template"
ADMIN_URL="${1:?usage: 460_harness.sh <admin-db-url>}"
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
mk() { local n="zz460${1}_$(date +%s)_$RANDOM"
  psql "$ADMIN_URL" -X -q -c "CREATE DATABASE \"$n\" TEMPLATE \"$TEMPLATE\"" >/dev/null || fail_case "clone failed"
  CREATED+=("$n"); printf '%s' "$ADMIN_URL" | sed -E "s#/[a-zA-Z0-9_\"'-]+\$#/$n#"; }
val() { psql "$1" -X -At -c "$2"; }
check() { local U="$1" bad=0 n
  want() { [ "$2" = "$3" ] || { echo "$1: got '$2' want '$3'"; bad=1; }; }
  n=$(val "$U" "select to_regclass('public.sos_alerts') is null"); want "sos_alerts dropped" "$n" t
  n=$(val "$U" "select count(*) from pg_proc where pronamespace='public'::regnamespace and proname in ('notify_sos_alert','open_emergency_chat','resolve_sos_alert')"); want "sos functions dropped" "$n" 0
  n=$(val "$U" "select count(*) from pg_proc where pronamespace='public'::regnamespace and proname in ('delete_user_data','platform_kpi_summary','platform_operational_alerts','get_member_profile')"); want "redefined functions present" "$n" 4
  n=$(val "$U" "select count(*) from pg_proc where pronamespace='public'::regnamespace and proname in ('delete_user_data','platform_kpi_summary','platform_operational_alerts','get_member_profile') and prosrc ilike '%sos_alerts%'"); want "no function mentions sos_alerts" "$n" 0
  return $bad; }
echo "== GREEN: real 460"
G="$(mk g)"
psql "$G" -X -q -v ON_ERROR_STOP=1 -c "select to_regclass('public.sos_alerts') is not null" -At | grep -q t || fail_case "template has no sos_alerts"
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>/tmp/h460.err || { cat /tmp/h460.err; fail_case "460 apply failed"; }
psql "$G" -X -q -v ON_ERROR_STOP=1 -f "$MIG" >/dev/null 2>&1 || fail_case "460 re-apply failed"
check "$G" || fail_case "green assertions failed"
echo "green OK: sos_alerts and the three SOS functions dropped, four functions redefined without sos_alerts, re-apply clean"
echo "== RED: broken copy (DROP TABLE removed) must fail"
BROKEN=$(mktemp); sed 's/^DROP TABLE IF EXISTS public.sos_alerts;//' "$MIG" > "$BROKEN"
cmp -s "$BROKEN" "$MIG" && fail_case "red mutation did not change the file"
Rd="$(mk r)"
psql "$Rd" -X -q -v ON_ERROR_STOP=1 -f "$BROKEN" >/dev/null 2>&1 || fail_case "broken apply failed"
if check "$Rd" >/tmp/h460.red 2>&1; then rm -f "$BROKEN"; fail_case "red run passed (assertions are not effective)"; fi
rm -f "$BROKEN"; echo "red OK, failed as required: $(tr '\n' ';' </tmp/h460.red)"
echo "ALL PASS"
