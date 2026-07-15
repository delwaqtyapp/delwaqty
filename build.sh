#!/bin/bash
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
    --help|-h)
      echo "Usage: ./build.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --release    Build release APK (unsigned)"
      echo "  --clean      Clean build artifacts before building"
      echo "  --test       Run flutter test before building"
      echo "  --help       Show this help message"
      exit 0
      ;;
  esac
done

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
  flutter build apk --release
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  APK_NAME="delwaqty_${VERSION}_release_${TIMESTAMP}.apk"
else
  echo "Building debug APK..."
  flutter build apk --debug
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
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
