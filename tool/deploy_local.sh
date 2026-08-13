#!/bin/bash
set -euo pipefail

APK="build/app/outputs/flutter-apk/app-debug.apk"
DEST="/sdcard/Download/delwaqty-debug.apk"

echo "==> Building debug APK..."
cd "$(dirname "$0")/.."
/root/flutter/bin/flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=.env.dev

echo "==> Copying APK to /sdcard/Download/..."
cp "$APK" "$DEST"

echo "==> Opening package installer..."
am start --user 0 \
  -a android.intent.action.VIEW \
  -d "file://$DEST" \
  -t "application/vnd.android.package-archive"

echo "==> Done. Tap Install on the dialog that appeared."
