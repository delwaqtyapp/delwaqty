#!/usr/bin/env bash
# Local gate: the same checks CI runs, on our own machine, so a push is
# already green before it leaves. Usage: bash tool/check.sh [quick]
#   quick = skip the full flutter test run (touched-file tests only by hand).
# Writes a one-line result with the HEAD sha to /tmp/gate-<sha>.log so a
# reviewer or merge script can see that this exact head passed.
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
sha=$(git rev-parse HEAD)
step() { echo "== $*"; }

step "pub get + generate"
flutter pub get >/dev/null
dart run build_runner build --delete-conflicting-outputs >/dev/null
git checkout -- lib/features/customer/commerce/domain/entities/merchant.freezed.dart 2>/dev/null || true

step "format"
dart format --set-exit-if-changed .

step "analyze"
flutter analyze --no-fatal-infos --no-fatal-warnings

step "guards"
bash tool/design_guard.sh
bash tool/superseded_migrations_guard.sh
bash tool/pharmacy_purge_guard.sh --self-test
bash tool/pharmacy_purge_guard.sh

step "edge + publisher tests"
node --test tool/edge_safety_test.cjs
node --test tool/edge_staff_admin_test.cjs
python3 -m unittest discover -s tool -p test_publish_development.py

if [ "${1:-}" != "quick" ]; then
  step "flutter test"
  flutter test --no-pub
fi

echo "GATE PASS $sha $(date -u +%FT%TZ) mode=${1:-full}" | tee "/tmp/gate-${sha}.log"
