#!/bin/bash
# Delwaqty Platform - Complete Build Script
# Builds all variants and copies to releases/
#
# Usage:
#   ./scripts/build_all.sh              # Build all variants
#   ./scripts/build_all.sh --debug      # Debug only
#   ./scripts/build_all.sh --release    # Release only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
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
BUILD_DEBUG=false
BUILD_RELEASE=false

for arg in "$@"; do
  case $arg in
    --debug) BUILD_DEBUG=true ;;
    --release) BUILD_RELEASE=true ;;
  esac
done

# Default: build both
if [ "$BUILD_DEBUG" = false ] && [ "$BUILD_RELEASE" = false ]; then
  BUILD_DEBUG=true
  BUILD_RELEASE=true
fi

# Clean
echo "Cleaning..."
flutter clean --quiet

# Get dependencies
echo "Getting dependencies..."
flutter pub get --quiet

# Run analysis
echo "Running analysis..."
flutter analyze --quiet
if [ $? -ne 0 ]; then
  echo "ERROR: Analysis failed. Fix issues before building."
  exit 1
fi

# Run tests
echo "Running tests..."
flutter test --quiet
if [ $? -ne 0 ]; then
  echo "ERROR: Tests failed. Fix issues before building."
  exit 1
fi

# Create releases directory
mkdir -p "$RELEASES_DIR"

# Build Debug APK
if [ "$BUILD_DEBUG" = true ]; then
  echo ""
  echo "Building Debug APK..."
  flutter build apk --debug --quiet
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
  APK_NAME="delwaqty_${VERSION}_debug_${TIMESTAMP}.apk"
  if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$RELEASES_DIR/$APK_NAME"
    echo "✅ Debug APK: $RELEASES_DIR/$APK_NAME"
  fi
fi

# Build Release APK
if [ "$BUILD_RELEASE" = true ]; then
  echo ""
  echo "Building Release APK..."
  flutter build apk --release --quiet
  APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  APK_NAME="delwaqty_${VERSION}_release_${TIMESTAMP}.apk"
  if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$RELEASES_DIR/$APK_NAME"
    echo "✅ Release APK: $RELEASES_DIR/$APK_NAME"
  fi

  echo ""
  echo "Building Release App Bundle..."
  flutter build appbundle --release --quiet
  AAB_PATH="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
  AAB_NAME="delwaqty_${VERSION}_release_${TIMESTAMP}.aab"
  if [ -f "$AAB_PATH" ]; then
    cp "$AAB_PATH" "$RELEASES_DIR/$AAB_NAME"
    echo "✅ Release AAB: $RELEASES_DIR/$AAB_NAME"
  fi
fi

echo ""
echo "============================================"
echo "  Build Complete!"
echo "  Output: $RELEASES_DIR/"
echo "============================================"
ls -la "$RELEASES_DIR/" | grep -E "\.(apk|aab)$"
