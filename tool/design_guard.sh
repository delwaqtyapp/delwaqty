#!/usr/bin/env bash
# tool/design_guard.sh — ratchet guard for design-token adoption.
#
# Fails CI when the number of raw (non-token) style values INCREASES past the
# recorded baseline. Existing debt is grandfathered; new debt is blocked.
# Counts only decrease over time, which is the migration path.
#
# Usage:
#   bash tool/design_guard.sh            # check mode (CI): fail if counts grew
#   bash tool/design_guard.sh --update   # write current counts as new baseline
#   bash tool/design_guard.sh --report   # print counts + top offending files
#
# Baseline lives in tool/design_guard_baseline.txt and is committed to git.
# Only regenerate it with --update when counts went DOWN (the script enforces
# this; use --force to override, e.g. after a big refactor that moves code).

set -euo pipefail
cd "$(dirname "$0")/.."

BASELINE_FILE="tool/design_guard_baseline.txt"

# Directories that ARE allowed to hold raw values: the token definitions
# themselves and the shared widget library that consumes them.
EXCLUDE_REGEX='^lib/(core/theme|shared/widgets)/'

count_pattern() {
  # $1 = ERE pattern matched against *.dart files under lib/
  grep -rE --include='*.dart' "$1" lib 2>/dev/null \
    | grep -vE "$EXCLUDE_REGEX" \
    | wc -l | tr -d ' '
}

current_raw_colors=$(count_pattern 'Color\(0x')
current_raw_radius=$(count_pattern 'BorderRadius\.circular\([0-9]')
current_raw_fontsize=$(count_pattern 'fontSize: [0-9]')

print_counts() {
  printf 'raw_colors=%s\n' "$current_raw_colors"
  printf 'raw_radius=%s\n' "$current_raw_radius"
  printf 'raw_fontsize=%s\n' "$current_raw_fontsize"
}

top_files() {
  # $1 = ERE pattern
  grep -rEc --include='*.dart' "$1" lib 2>/dev/null \
    | grep -vE "$EXCLUDE_REGEX" \
    | awk -F: '$2 > 0' \
    | sort -t: -k2 -rn \
    | head -10
}

case "${1:-}" in
  --update|--force)
    if [ -f "$BASELINE_FILE" ] && [ "${1:-}" != "--force" ]; then
      . "$BASELINE_FILE"
      failed=0
      [ "$current_raw_colors" -gt "$raw_colors" ] && failed=1
      [ "$current_raw_radius" -gt "$raw_radius" ] && failed=1
      [ "$current_raw_fontsize" -gt "$raw_fontsize" ] && failed=1
      if [ "$failed" -eq 1 ]; then
        echo "design_guard: refusing --update, counts went UP. Use --force to override." >&2
        print_counts >&2
        exit 1
      fi
    fi
    print_counts > "$BASELINE_FILE"
    echo "design_guard: baseline written to $BASELINE_FILE"
    print_counts
    exit 0
    ;;
  --report)
    echo "== design guard report =="
    print_counts
    echo
    echo "-- top files: raw Color(0x...) --"
    top_files 'Color\(0x'
    echo
    echo "-- top files: BorderRadius.circular(<n>) --"
    top_files 'BorderRadius\.circular\([0-9]'
    echo
    echo "-- top files: fontSize: <n> --"
    top_files 'fontSize: [0-9]'
    exit 0
    ;;
esac

# --- check mode ---
if [ ! -f "$BASELINE_FILE" ]; then
  echo "design_guard: no baseline at $BASELINE_FILE; run: bash tool/design_guard.sh --force" >&2
  exit 1
fi
. "$BASELINE_FILE"

fail=0
check() {
  # $1 label, $2 current, $3 baseline
  if [ "$2" -gt "$3" ]; then
    echo "design_guard FAIL: $1 grew $3 -> $2 (+$(( $2 - $3 )))" >&2
    fail=1
  elif [ "$2" -lt "$3" ]; then
    echo "design_guard: $1 improved $3 -> $2 (run --update to ratchet down)"
  else
    echo "design_guard: $1 unchanged at $2"
  fi
}

check raw_colors   "$current_raw_colors"   "$raw_colors"
check raw_radius   "$current_raw_radius"   "$raw_radius"
check raw_fontsize "$current_raw_fontsize" "$raw_fontsize"

if [ "$fail" -eq 1 ]; then
  echo >&2
  echo "New raw style values were added outside lib/core/theme and lib/shared/widgets." >&2
  echo "Use the design tokens instead: AppColors / colorScheme, AppSpacing, AppTextStyles." >&2
  echo "Run 'bash tool/design_guard.sh --report' to see the top offending files." >&2
  exit 1
fi

echo "design_guard: OK"
