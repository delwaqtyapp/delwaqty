#!/usr/bin/env bash
# Superseded-migrations guard: every file listed in
# supabase/migrations/SUPERSEDED.txt must (a) still exist, (b) carry a
# SUPERSEDED marker header naming its replacement, so an automated or
# manual full-chain apply never picks it up.
set -euo pipefail
LIST="$(dirname "$0")/../supabase/migrations/SUPERSEDED.txt"
[ -f "$LIST" ] || { echo "superseded guard: $LIST missing"; exit 1; }
rc=0
while IFS='|' read -r file _rest; do
  file="$(printf '%s' "$file" | sed 's/^ *//; s/ *$//')"
  case "$file" in ''|\#*) continue;; esac
  path="supabase/migrations/$file"
  if [ ! -f "$path" ]; then
    echo "superseded guard: $file listed but missing"
    rc=1
    continue
  fi
  if ! head -5 "$path" | grep -q '^-- SUPERSEDED:'; then
    echo "superseded guard: $file lacks the SUPERSEDED marker header"
    rc=1
  fi
done < "$LIST"
exit $rc
