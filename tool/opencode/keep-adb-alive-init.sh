#!/data/data/com.termux/files/usr/bin/sh
# keep-adb-alive-init.sh - Termux:Boot autostart for the ADB keepalive daemon.
#
# This script runs OUTSIDE the Ubuntu proot, directly on the Termux host,
# at device boot (Termux:Boot). It starts keep_adb_alive.sh as an
# independent daemon so that Android wireless debugging stays connected
# regardless of the OpenCode/OmniRoute/proot lifecycle.
#
# Architecture (independent branch):
#   Termux:Boot
#     |- keep-adb-alive-init.sh   (this script, host side)
#     `- keep_adb_alive.sh        (host-side daemon, flock-guarded)
#
# The keepalive reaches Shizuku/rish by invoking the rish script that lives
# inside the Ubuntu rootfs (keep_adb_alive.sh resolves it automatically),
# and uses the host adb binary - so it has NO dependency on the proot being
# alive, on OpenCode, on OmniRoute, or on tmux.
#
# Single-instance: keep_adb_alive.sh holds a flock(1) on
#   $TERMUX_HOME/.keep_adb_alive.lock
# A second concurrent start (Termux:Boot + manual, or two boots racing)
# simply fails to acquire the lock and exits. No pgrep reliance.
#
set -u

TERMUX_HOME="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
export TERMUX_HOME
export HOME="$TERMUX_HOME"
export PATH="$PREFIX/bin:$PATH"

KEEP_ADB="/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/root/Projects/delwaqty/tool/opencode/keep_adb_alive.sh"
BOOT_LOG="$TERMUX_HOME/.keep-adb-alive-init.log"

log() { echo "$(date '+%F %T'): $1" >> "$BOOT_LOG"; }

log "boot script started"

if [ ! -x "$KEEP_ADB" ]; then
  log "FAIL: keep_adb_alive.sh not found/executable at $KEEP_ADB"
  log "boot script FAILED"
  exit 1
fi

# Start the daemon fully detached: new session, no controlling tty, output
# redirected so Termux:Boot never blocks on it. The flock inside the script
# is the single-instance gate.
setsid "$KEEP_ADB" loop >> "$BOOT_LOG" 2>&1 < /dev/null &
DAEMON_PID=$!
disown 2>/dev/null || true

# Give it a moment, then confirm the daemon actually holds the loop.
sleep 3
if kill -0 "$DAEMON_PID" 2>/dev/null; then
  log "OK: keep_adb_alive daemon started (pid $DAEMON_PID)"
else
  log "WARN: daemon exited quickly (lock already held by another instance?)"
fi
log "boot script completed"
