#!/usr/bin/env bash
# Fails if any pharmacy/medicine trace remains in the four Play-bound apps
# (customer, provider, driver, admin): sources, tests, l10n and assets.
# The Windows cashier (pos/) and the database (supabase/) are covered by
# their own removal work and are out of scope here.
#
# Review-audited exceptions live in tool/pharmacy_purge_guard_allowlist.txt
# as exact `path:linenumber:sha1(line content)` entries (one per line). An
# entry clears ONLY that exact content at that exact line of that exact
# file: editing the line, moving it, or appending to it makes the guard
# fail until the allowlist is re-audited, which is intended.
#
# --self-test builds a fixture tree and asserts the scanner catches planted
# traces, honors the allowlist, rejects a modified allowlisted line, and
# fails on scan errors (missing root, unreadable file).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST="${ALLOWLIST:-$SCRIPT_DIR/pharmacy_purge_guard_allowlist.txt}"

# English and Arabic pharmacy/medicine terms. Kept deliberately wide: a
# false positive costs a review, a false negative ships a Play rejection.
TERMS='pharmac|صيدل|دواء|أدوية|دوائي|drug|medicine|medication|dosage|prescription|active_ingredient'

scan() {
  # Prints `path:linenumber:content` for every hit under the given roots.
  # grep exit 1 (no hits) is clean; exit >= 2 (missing root, unreadable
  # file) aborts the guard: an incomplete scan must never report clean.
  local roots=("$@")
  local root
  for root in "${roots[@]}"; do
    if [ ! -e "$root" ]; then
      echo "pharmacy purge guard: scan root '$root' does not exist" >&2
      return 2
    fi
  done
  local out rc errf
  errf="$(mktemp)"
  set +e
  out="$(grep -rniE "$TERMS" "${roots[@]}" 2>"$errf")"
  rc=$?
  set -e
  if [ "$rc" -ge 2 ]; then
    echo "pharmacy purge guard: scan error, refusing to report clean:" >&2
    cat "$errf" >&2
    rm -f "$errf"
    return 2
  fi
  rm -f "$errf"
  printf '%s' "$out"
}

line_key() {
  # Builds the allowlist key `path:linenumber:sha1(content)` for one
  # `path:linenumber:content` grep hit.
  local hit="$1" path lnum content
  path="$(printf '%s' "$hit" | cut -d: -f1)"
  lnum="$(printf '%s' "$hit" | cut -d: -f2)"
  content="$(printf '%s' "$hit" | cut -d: -f3-)"
  printf '%s:%s:%s' "$path" "$lnum" "$(printf '%s' "$content" | sha1sum | cut -d' ' -f1)"
}

filtered_hits() {
  # Drops hits whose exact `path:linenumber:sha1(content)` is allowlisted.
  # A hit whose line moved or whose content changed is reported again.
  local hits="$1"
  [ -z "$hits" ] && return 0
  local out="" line key
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key="$(line_key "$line")"
    if [ -f "$ALLOWLIST" ] && grep -qxF "$key" "$ALLOWLIST"; then
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
  trap 'chmod -R u+r "$tmp" 2>/dev/null; rm -rf "$tmp"' RETURN
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

  # Allowlist must clear exactly the listed line content and nothing else.
  local allow="$tmp/allowlist.txt" remaining
  line_key "$(scan "$tmp/lib" | head -1)" > "$allow"
  remaining="$(ALLOWLIST="$allow" filtered_hits "$(scan "$tmp/lib")")"
  if [ -n "$remaining" ]; then
    echo "self-test FAIL: allowlisted line still reported" >&2
    return 1
  fi
  # A wrong line number must not clear the hit.
  printf '%s' "$(sed 's/^\([^:]*:\)[0-9]*/\1999/' "$allow")" > "$allow"
  remaining="$(ALLOWLIST="$allow" filtered_hits "$(scan "$tmp/lib")")"
  if [ -z "$remaining" ]; then
    echo "self-test FAIL: wrong line number cleared the hit" >&2
    return 1
  fi
  # Modified content on the same line must not clear the hit.
  printf 'final label = "pharmacy"; // changed\n' > "$tmp/lib/dirty.dart"
  line_key "$(printf '%s:1:%s' "$tmp/lib/dirty.dart" 'final label = "pharmacy";')" > "$allow"
  remaining="$(ALLOWLIST="$allow" filtered_hits "$(scan "$tmp/lib")")"
  if [ -z "$remaining" ]; then
    echo "self-test FAIL: modified allowlisted line was cleared" >&2
    return 1
  fi

  # A missing scan root must error, never report clean.
  if scan "$tmp/does-not-exist" 2>/dev/null; then
    echo "self-test FAIL: missing scan root did not error" >&2
    return 1
  fi
  # An unreadable FILE must error, never report clean.
  printf 'final y = 2;\n' > "$tmp/lib/unreadable.dart"
  chmod 000 "$tmp/lib/unreadable.dart"
  if scan "$tmp/lib" 2>/dev/null; then
    echo "self-test FAIL: unreadable file did not error" >&2
    return 1
  fi
  chmod 644 "$tmp/lib/unreadable.dart"

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
