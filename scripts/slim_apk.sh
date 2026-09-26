#!/data/data/com.termux/files/usr/bin/bash
# slim_apk.sh — repack a debug APK to remove Flutter's zipalign padding voids.
# Usage: slim_apk.sh <input.apk> [output.apk]
# Relies on useLegacyPackaging=true (native libs extract at install), so all
# entries are stored deflate-stored; no mmap page alignment needed.
set -euo pipefail

SRC="$1"
DST="${2:-${SRC%.apk}_slim.apk}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">>> unpacking $SRC"
mkdir -p "$WORK/unz"
unzip -q "$SRC" -d "$WORK/unz"

echo ">>> repacking tight"
( cd "$WORK/unz" && zip -q -X -r -n .arsc "$WORK/tight.zip" . )

echo ">>> zipalign 4-byte"
zipalign -f 4 "$WORK/tight.zip" "$WORK/aligned.apk"

echo ">>> signing with debug keystore"
KEYSTORE="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
apksigner sign --ks "$KEYSTORE" \
  --ks-key-alias androiddebugkey --ks-pass pass:android \
  --key-pass pass:android --out "$DST" "$WORK/aligned.apk"

echo ">>> verifying"
apksigner verify --verbose "$DST" 2>&1 | tail -3
ls -la "$SRC" "$DST"
