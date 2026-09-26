#!/data/data/com.termux/files/usr/bin/bash
# Delwaqty OTA Publish Script
#
# Builds all four flavors (customer/admin/driver/provider), uploads the APKs
# to a NEW GitHub Release (tag = version string), and updates ota/versions.json
# so every installed build detects the update on next launch.
#
# Usage:
#   ./scripts/publish_ota.sh [--patch|--minor|--major]
#
# Version is read from pubspec.yaml (e.g. 1.0.0+1). The script bumps the build
# number (the +N suffix) for OTA — Android uses it as versionCode, so any app
# that already has the same versionName sees build N+1 as "newer".

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
ENV_FILE="${ENV_FILE:-.env.dev}"
BUMP="${1:---patch}"

cd "$PROJECT_DIR"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: Env file '$ENV_FILE' not found."
  exit 1
fi

export PATH="$HOME/flutter-3.47.1-test/bin:$PATH"

CURRENT_VERSION=$(grep "^version:" pubspec.yaml | head -1 | awk '{print $2}')

# Deterministic next build number: bump the integer after '+' (or start at 2).
if echo "$CURRENT_VERSION" | grep -q '+'; then
  BASE="${CURRENT_VERSION%%+*}"
  OLD_BUILD="${CURRENT_VERSION##*+}"
else
  BASE="$CURRENT_VERSION"
  OLD_BUILD=1
fi

case "$BUMP" in
  --major) BASE=$(echo "$BASE" | awk -F. '{OFS="."; print $1+1,0,0}') ;;
  --minor) BASE=$(echo "$BASE" | awk -F. '{OFS="."; print $1,$2+1,0}') ;;
  --patch) BASE=$(echo "$BASE" | awk -F. '{OFS="."; print $1,$2,$3+1}') ;;
  *) echo "Unknown bump: $BUMP (use --patch|--minor|--major)"; exit 1 ;;
esac

NEW_BUILD=$((OLD_BUILD + 1))
NEW_VERSION="${BASE}+${NEW_BUILD}"
TAG="v${BASE}"

echo "============================================"
echo "  Delwaqty OTA Publish"
echo "  Old version : $CURRENT_VERSION"
echo "  New version : $NEW_VERSION"
echo "  Tag         : $TAG"
echo "  Env file    : $ENV_FILE"
echo "============================================"
echo ""

# ── 1. Bump version in pubspec.yaml ──────────────────────────────
sed -i "s/^version: $CURRENT_VERSION/version: $NEW_VERSION/" pubspec.yaml
echo "pubspec.yaml -> version: $NEW_VERSION"

flutter pub get >/dev/null 2>&1

# ── 2. Build all four flavors ────────────────────────────────────
declare -A FLAVORS=( [customer]=customer [admin]=admin [driver]=driver [provider]=provider )
declare -A RENAMES=( [customer]=delwaqty-customer [admin]=delwaqty-admin [driver]=delwaqty-driver [provider]=delwaqty-provider )

for flavor in "${!FLAVORS[@]}"; do
  echo ""
  echo "── Building $flavor ────────────────────────────"
  flutter build apk --debug --flavor "$flavor" \
    -t "lib/$flavor/main.dart" --dart-define-from-file="$ENV_FILE" \
    --build-name "${BASE}" --build-number "${NEW_BUILD}"
  SRC="build/app/outputs/flutter-apk/app-${flavor}-debug.apk"
  if [ ! -f "$SRC" ]; then
    echo "ERROR: expected $SRC not found"; exit 1
  fi
done

# ── 3. Create GitHub release (overwrite if the tag already exists) ──
echo ""
echo "── Publishing to GitHub Releases ──────────────"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release delete "$TAG" --yes >/dev/null 2>&1 || true
fi
gh release create "$TAG" --title "Delwaqty $TAG" --latest \
  --notes "OTA build $NEW_VERSION for customer / admin / driver / provider."

for flavor in "${!RENAMES[@]}"; do
  TMP_APK="/data/data/com.termux/files/usr/tmp/opencode/${RENAMES[$flavor]}.apk"
  cp "build/app/outputs/flutter-apk/app-${flavor}-debug.apk" "$TMP_APK"
  gh release upload "$TAG" "$TMP_APK" --clobber >/dev/null
  echo "  uploaded ${RENAMES[$flavor]}.apk"
done
# Upload the OTA manifest as a release asset too — served via the immutable
# per-tag URL /releases/download/<tag>/versions.json which the apps fetch via
# the GitHub API "latest tag" lookup (no raw-file or redirect cache delay).
gh release upload "$TAG" "ota/versions.json" --clobber >/dev/null
echo "  uploaded versions.json"

# ── 4. Update ota/versions.json ───────────────────────────────────
NOTES="${NOTES:-تحديث جديد}"
python3 - "$NEW_BUILD" "$BASE" <<'PYEOF'
import json, sys
build_num, base = sys.argv[1], sys.argv[2]
path = "ota/versions.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
for k, v in data["channels"].items():
    v["version"] = int(build_num)
    v["versionName"] = f"{base}+{build_num}"
    v["notes"] = "تحديث جديد"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print("ota/versions.json updated to build", build_num)
PYEOF

echo ""
echo "============================================"
echo "  DONE — version $NEW_VERSION published as $TAG"
echo "  Commit & push ota/versions.json + pubspec.yaml to go live."
echo "============================================"