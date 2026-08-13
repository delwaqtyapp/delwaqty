#!/bin/bash
# deploy_shizuku.sh — Build and install APK via Shizuku's Android shell
# Architecture: deploy → android-control → rish → Shizuku → pm install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

export RISH_APPLICATION_ID="${RISH_APPLICATION_ID:-com.termux}"

# --- Pre-flight: verify Android Control Layer ---
if ! android-control shell id >/dev/null 2>&1; then
  echo "ERROR: Android Control Layer not available." >&2
  echo "Ensure Shizuku is running and android-control is installed." >&2
  exit 1
fi

echo "==> Building debug APK..."
cd "$PROJECT_DIR"
/root/flutter/bin/flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=.env.dev

echo "==> Copying APK to device storage..."
cp "$APK" /sdcard/Download/delwaqty-debug.apk

echo "==> Installing via Android shell (uid=2000)..."
android-control shell pm install -r -g /sdcard/Download/delwaqty-debug.apk

echo "==> Done."
