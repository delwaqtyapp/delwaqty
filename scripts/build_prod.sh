#!/bin/bash
# Build a production APK.
# Usage: bash scripts/build_prod.sh
set -e
cd "$(dirname "$0")/.."
export PUB_CACHE="E:\app\pub-cache"
export GRADLE_USER_HOME="E:\app\.gradle"
export PATH="E:\app\flutter\bin:$PATH"

echo "Building production APK..."
flutter build apk --release --dart-define-from-file=.env.prod

echo ""
echo "Output: build/app/outputs/flutter-apk/app-release.apk"
