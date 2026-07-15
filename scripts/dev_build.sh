#!/bin/bash
# Quick development build - debug APK only
cd "$(dirname "$0")/.."
echo "Building debug APK for development..."
flutter pub get --quiet
flutter build apk --debug --quiet
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK_PATH" ]; then
  cp "$APK_PATH" "releases/delwaqty_debug_$(date +%Y%m%d_%H%M%S).apk"
  echo "Debug APK ready!"
else
  echo "Build failed!"
  exit 1
fi
