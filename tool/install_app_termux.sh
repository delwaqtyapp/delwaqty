#!/data/data/com.termux/files/usr/bin/bash
#
# install_app_termux.sh
#
# Automatic APK installer that works from Termux WITHOUT root.
#
# Why not `pm install`?  Inside PRoot the real Android uid is u0_a526
# (Termux), and `pm install` requires shell/root privileges, so it fails
# with SecurityException.  Instead we hand the APK to the system
# Package Installer through an Intent:
#
#   1. copy the APK into /sdcard/Download (a real, world-readable path)
#   2. broadcast a VIEW intent with mime application/vnd.android.package-archive
#      through TermuxOpenReceiver, which grants a content:// URI via
#      FileProvider and launches the system installer
#   3. the user just taps "Install"
#
# Usage:
#   ./tool/install_app_termux.sh [path/to/app.apk]
#
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

APK="${1:-$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk}"

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -f "$APK" ] || fail "APK not found: $APK"

echo "==> APK: $APK"
echo "==> Size: $(du -h "$APK" | cut -f1)"

# --- 1. copy to shared storage -------------------------------------------
DEST_DIR="/sdcard/Download"
DEST="$DEST_DIR/delwaqty-install.apk"
mkdir -p "$DEST_DIR" || fail "cannot create $DEST_DIR"
echo "==> Copying APK to $DEST ..."
cp -f "$APK" "$DEST" || fail "copy to $DEST failed"
sync
[ -f "$DEST" ] || fail "copy verification failed"
echo "==> Copied OK: $(du -h "$DEST" | cut -f1)"

# --- 2. launch system package installer ----------------------------------
echo "==> Launching package installer ..."
termux-open --content-type application/vnd.android.package-archive "$DEST"
RC=$?
[ $RC -eq 0 ] || fail "termux-open failed (exit $RC)"

echo ""
echo ">>> The Android installer should now be on screen."
echo ">>> Tap 'Install' (and confirm any 'install unknown apps' prompt)."
echo ">>> When done, the app 'دلوقتي / Delwaqty' will be updated."
