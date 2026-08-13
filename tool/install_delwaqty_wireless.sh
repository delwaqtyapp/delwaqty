#!/data/data/com.termux/files/usr/bin/bash
#
# install_delwaqty_wireless.sh
#
# Fully automatic APK install over Android Wireless Debugging — run from
# Termux/PRoot on the DNP NX9 itself. No root needed.
#
# Usage:
#   ./tool/install_delwaqty_wireless.sh \
#       <adb_ip:port> <pairing_ip:port> <pairing_code>
#
#   e.g. ./tool/install_delwaqty_wireless.sh \
#       192.168.8.36:42017 192.168.8.36:37123 123456
#
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

fail() { echo "ERROR: $*" >&2; exit 1; }

ADB_TARGET="${1:-}"
PAIR_TARGET="${2:-}"
PAIR_CODE="${3:-}"

[ -n "$ADB_TARGET" ] && [ -n "$PAIR_TARGET" ] && [ -n "$PAIR_CODE" ] \
  || fail "usage: $0 <adb_ip:port> <pair_ip:port> <pairing_code>"
[ -f "$APK" ] || fail "APK not found: $APK"

echo "==> APK: $APK ($(du -h "$APK" | cut -f1))"

echo "==> Restarting adb server ..."
adb kill-server 2>/dev/null
adb start-server >/dev/null 2>&1 || fail "cannot start adb server"

echo "==> Pairing with $PAIR_TARGET (code $PAIR_CODE) ..."
adb pair "$PAIR_TARGET" "$PAIR_CODE" 2>&1 | tail -2

echo "==> Connecting to $ADB_TARGET ..."
for i in 1 2 3 4 5; do
  adb connect "$ADB_TARGET" >/dev/null 2>&1 && break
  sleep 2
done

adb devices | grep -q "device$" || fail "device not authorized/connected"

echo "==> Authorizing install (may prompt on phone) ..."
adb shell pm install -r -d "$APK" 2>&1 | tail -3
RC=$?

echo ""
if [ $RC -eq 0 ]; then
  echo ">>> SUCCESS: Delwaqty updated."
  adb shell am force-stop com.delwaqty.app 2>/dev/null
  echo ">>> Launching app ..."
  adb shell monkey -p com.delwaqty.app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
else
  echo ">>> install exit=$RC — check the phone screen for prompts."
fi
