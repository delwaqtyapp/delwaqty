#!/data/data/com.termux/files/usr/bin/sh
# shizuku-init.sh — Termux:Boot startup script for Shizuku/Rish environment
#
# This script runs automatically at device boot IF Termux:Boot is installed.
# If Termux:Boot is not installed, this script does nothing.
#
# How it works (corrected):
#   rish is installed INSIDE the Ubuntu proot at /usr/local/bin/rish.
#   On the Termux host it is NOT present, so we enter the proot via
#   `proot-distro login ubuntu -- rish -c id` and check the socket.
#
# What it does:
#   1. Sets RISH_APPLICATION_ID
#   2. Verifies rish is accessible inside the Ubuntu proot
#   3. Runs a Shizuku health check
#   4. Logs results
#
# What it does NOT do:
#   - Kill or restart Shizuku
#   - Modify Android settings
#   - Scan ports or reconnect ADB
#   - Attempt root or privilege escalation
#   - Bypass Android security
#   - BLOCK the boot of OpenCode if Shizuku is unavailable

LOGFILE="/data/data/com.termux/files/home/.shizuku-boot.log"
PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOGFILE"
}

log "Boot script started"

export RISH_APPLICATION_ID="com.termux"

# rish lives inside the Ubuntu proot. Reaching it requires proot-distro login.
# If proot-distro is not reachable (reboot, first boot), we degrade gracefully.
if command -v proot-distro >/dev/null 2>&1; then
  log "probing Shizuku/rish inside Ubuntu proot..."
  ID_OUT=$(proot-distro login ubuntu -- /usr/local/bin/rish -c 'id' 2>&1) || true
  if echo "$ID_OUT" | grep -q "uid=2000"; then
    log "OK: Shizuku/Rish is healthy (uid=2000)"
  else
    log "WARN: Shizuku/Rish not reachable — Shizuku app may need restart"
    log "  rish output: $ID_OUT"
  fi
else
  log "WARN: proot-distro unavailable; skipping Shizuku probe (non-fatal)"
fi

MODEL=$(getprop ro.product.model 2>/dev/null || echo "???")
SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "???")
log "Device: $MODEL (SDK $SDK)"

log "Boot script completed"