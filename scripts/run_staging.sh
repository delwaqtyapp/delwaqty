#!/bin/bash
# Run the app in staging mode.
# Usage: bash scripts/run_staging.sh
set -e
cd "$(dirname "$0")/.."
export PUB_CACHE="E:\app\pub-cache"
export GRADLE_USER_HOME="E:\app\.gradle"
export PATH="E:\app\flutter\bin:$PATH"

echo "Starting staging build..."
flutter run --dart-define-from-file=.env.staging
