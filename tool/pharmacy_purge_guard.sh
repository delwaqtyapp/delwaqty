#!/usr/bin/env bash
# Fails if any pharmacy/medicine trace remains in the four Play-bound apps
# (customer, provider, driver, admin): sources, tests, l10n and assets.
# The Windows cashier (pos/) and the database (supabase/) are covered by
# their own removal work and are out of scope here.
#
# Review-audited exceptions live in tool/pharmacy_purge_guard_allowlist.txt
# as exact `path:linenumber` entries (one per line). An entry clears ONLY
# that exact line of that exact file: editing the file shifts line numbers
# and the guard fails until the allowlist is re-audited, which is intended.
#
# --self-test builds a fixture tree and asserts the scanner catches planted
# traces, honors the allowlist, and fails on unreadable scan roots.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST="${ALLOWLIST:-$SCRIPT_DIR/pharmacy_purge_guard_allowlist.txt}"

# English and Arabic pharmacy/medicine terms. Kept deliberately wide: a
# false positive costs a review, a false negative ships a Play rejection.
TERMS='pharmac|صيدل|دواء|أدوية|دوائي|drug|medicine|medication|dosage|prescription|active_ingredient'

scan() {
  # Prints `path:linenumber:content` for every hit under the given roots.
  # Any scanner error (missing root, unreadable file) aborts the guard:
  # an incomplete scan must never report clean.
  local roots=("$@")
  local root
  for root in "${roots[@]}"; do
    if [ ! -e "$root" ]; then
      echo "pharmacy purge guard: scan root '$root' does not exist" >&2
      return 2
    fi
  done
  grep -rniE "$TERMS" "${roots[@]}" || true
}

filtered_hits() {
  # Drops hits whose exact `path:linenumber` is allowlisted. A hit whose
  # line moved or whose content changed is reported again.
  local hits="$1"
  [ -z "$hits" ] && return 0
  local out="" line key
  while IFS= read -r line; do
    key="${line%%:*}" # path
    # path may itself contain no colon on our platforms; split path:line:text
    local path lnum
    path="$(printf '%s' "$line" | cut -d: -f1)"
    lnum="$(printf '%s' "$line" | cut -d: -f2)"
    if [ -f "$ALLOWLIST" ] && grep -qxF "$path:$lnum" "$ALLOWLIST"; then
      continue
    fi
    out+="$line"$'\n'
  done <<< "$hits"
  printf '%s' "$out"
}

guard() {
  local roots=("$@")
  local hits
  hits="$(scan "${roots[@]}")"
  hits="$(filtered_hits "$hits")"
  if [ -n "$hits" ]; then
    echo "FAIL: pharmacy trace found in Play-bound app sources:"
    echo "$hits"
    return 1
  fi
  echo "pharmacy purge guard: clean"
}

self_test() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/lib" "$tmp/test"
  printf 'final x = 1;\n' > "$tmp/lib/clean.dart"
  printf 'final label = "pharmacy";\n' > "$tmp/lib/dirty.dart"
  printf '// دواء\n' > "$tmp/test/dirty_ar.txt"

  if scan "$tmp/lib/clean.dart" | grep -q .; then
    echo "self-test FAIL: clean file reported a hit" >&2
    return 1
  fi
  if ! scan "$tmp/lib" | grep -q 'dirty.dart'; then
    echo "self-test FAIL: planted English term not detected" >&2
    return 1
  fi
  if ! scan "$tmp/test" | grep -q 'dirty_ar.txt'; then
    echo "self-test FAIL: planted Arabic term not detected" >&2
    return 1
  fi
  # Allowlist must clear exactly the listed line and nothing else.
  local allow="$tmp/allowlist.txt"
  printf '%s:1\n' "$tmp/lib/dirty.dart" > "$allow"
  local remaining
  remaining="$(ALLOWLIST="$allow" filtered_hits "$(scan "$tmp/lib")")"
  if [ -n "$remaining" ]; then
    echo "self-test FAIL: allowlisted line still reported" >&2
    return 1
  fi
  printf '%s:2\n' "$tmp/lib/dirty.dart" > "$allow"
  remaining="$(ALLOWLIST="$allow" filtered_hits "$(scan "$tmp/lib")")"
  if [ -z "$remaining" ]; then
    echo "self-test FAIL: wrong line number cleared the hit" >&2
    return 1
  fi
  # A missing scan root must error, never report clean.
  if scan "$tmp/does-not-exist" 2>/dev/null; then
    echo "self-test FAIL: missing scan root did not error" >&2
    return 1
  fi
  echo "pharmacy purge guard: self-test passed"
}

case "${1:-}" in
  --self-test)
    self_test
    ;;
  "")
    cd "$SCRIPT_DIR/.."
    guard lib test assets
    ;;
  *)
    echo "usage: $0 [--self-test]" >&2
    exit 2
    ;;
esac
