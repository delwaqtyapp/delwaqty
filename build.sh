#!/data/data/com.termux/files/usr/bin/bash
# Delwaqty Platform - Build Script
# Generates Debug APK for development and testing
#
# Usage:
#   ./build.sh              # Build debug APK
#   ./build.sh --release    # Build release APK (unsigned)
#   ./build.sh --clean      # Clean build artifacts
#   ./build.sh --test       # Run tests before building

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
RELEASES_DIR="$PROJECT_DIR/releases"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VERSION=$(grep "version:" "$PROJECT_DIR/pubspec.yaml" | head -1 | awk '{print $2}')

echo "============================================"
echo "  Delwaqty Platform Build"
echo "  Version: $VERSION"
echo "  Timestamp: $TIMESTAMP"
echo "============================================"
echo ""

# Parse arguments
BUILD_RELEASE=false
CLEAN_BUILD=false
RUN_TESTS=false

for arg in "$@"; do
  case $arg in
    --release) BUILD_RELEASE=true ;;
    --clean) CLEAN_BUILD=true ;;
    --test) RUN_TESTS=true ;;
    --env) : ;; # value consumed below
    --env=*) ENV_FILE=".env.${arg#*=}" ;;
    --help|-h)
      echo "Usage: ./build.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --release    Build release APK (unsigned)"
      echo "  --clean      Clean build artifacts before building"
      echo "  --test       Run flutter test before building"
      echo "  --env <f>    Use env file: dev (default), staging, prod"
      echo "  --help       Show this help message"
      exit 0
      ;;
  esac
done

# Resolve --env <value> (separate argument form) and verify the file exists.
ENV_FILE_MODE=false
for arg in "$@"; do
  if [ "$ENV_FILE_MODE" = true ]; then
    ENV_FILE=".env.$arg"
    ENV_FILE_MODE=false
  elif [ "$arg" = "--env" ]; then
    ENV_FILE_MODE=true
  fi
done
: "${ENV_FILE:=.env.dev}"
if [ ! -f "$PROJECT_DIR/$ENV_FILE" ]; then
  echo "ERROR: Env file '$ENV_FILE' not found. Create it first (see .env.example)."
  exit 1
fi
echo "Using env file: $ENV_FILE"

# Step 1: Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
  echo "Cleaning build artifacts..."
  flutter clean
  echo ""
fi

# Step 2: Get dependencies
echo "Getting dependencies..."
flutter pub get
echo ""

# Step 3: Run tests if requested
if [ "$RUN_TESTS" = true ]; then
  echo "Running tests..."
  flutter test
  if [ $? -ne 0 ]; then
    echo "ERROR: Tests failed. Aborting build."
    exit 1
  fi
  echo ""
fi

# Step 4: Create releases directory
mkdir -p "$RELEASES_DIR"

# Step 5: Build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building release APK..."

  # IMPORTANT: On the Termux ARM host SDK (~/flutter-3.47.1-test), release/AOT
  # builds are NOT possible: the engine does not publish an arm64-host
  # android-arm64-release gen_snapshot ("Failed to find ...
  # android-arm64-release/linux-x64/gen_snapshot"). See docs/DECISION_LOG.md ADR-044.
  # Keep the required shape below anyway in case a capable SDK is used.
  flutter build apk --release --flavor customer \
    -t lib/customer/main.dart --dart-define-from-file=$ENV_FILE
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-customer-release.apk"
  APK_NAME="delwaqty_${VERSION}_release_${TIMESTAMP}.apk"
else
  echo "Building debug APK (customer flavor)..."
  flutter build apk --debug --target-platform android-arm64 --flavor customer \
    -t lib/customer/main.dart --dart-define-from-file=$ENV_FILE
  if [ "${SKIP_SLIM:-false}" != "true" ] && command -v scripts/slim_apk.sh >/dev/null 2>&1; then
    # Drops the ~4MB+ zipalign padding void; re-signs in place with the debug keystore.
    APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-customer-debug.apk"
    scripts/slim_apk.sh "$APK" "$APK"
  fi
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-customer-debug.apk"
  APK_NAME="delwaqty_${VERSION}_debug_${TIMESTAMP}.apk"
fi

# Step 6: Copy to releases
if [ -f "$APK_PATH" ]; then
  cp "$APK_PATH" "$RELEASES_DIR/$APK_NAME"
  echo ""
  echo "============================================"
  echo "  Build Successful!"
  echo "  APK: $RELEASES_DIR/$APK_NAME"
  echo "  Size: $(du -h "$RELEASES_DIR/$APK_NAME" | cut -f1)"
  echo "============================================"
else
  echo "ERROR: APK not found at $APK_PATH"
  exit 1
fi
