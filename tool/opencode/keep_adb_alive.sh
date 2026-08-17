#!/data/data/com.termux/files/usr/bin/bash
#
# keep_adb_alive.sh — keep Android wireless debugging (adb over Wi-Fi) alive
# for the whole coding session on the DNP NX9 (HONOR, MagicOS).
#
# Why this exists:
#   * MagicOS "PowerGenius" and its smart battery manager can suspend adbd or
#     drop the Wi-Fi transport while the screen is off / app in background.
#   * The wireless-debugging PORT is DYNAMIC: every toggle of "Wireless
#     debugging" or adbd restart picks a new random port, so a previously
#     saved `adb connect IP:OLD_PORT` silently dies.
#   * The adb server keeps stale "offline" entries for old ports and must be
#     told about the CURRENT port.
#
# Lifecycle: run as an INDEPENDENT Termux:Boot daemon (OUTSIDE the Ubuntu
# proot) via ~/.termux/boot/keep-adb-alive-init.sh. It may also be run from
# inside the proot; both environments are detected automatically.
#
# What it does (every loop iteration, ~20s):
#   1. Re-asserts the Android-side battery/network settings that stop the
#      phone from power-managing the session (via Shizuku/rish, shell uid).
#   2. Detects the CURRENT wireless-debugging port by scanning the phone's
#      listening TCP ports for the adbd TLS handshake via `adb connect`.
#   3. `adb kill-server` only when NO valid transport exists (avoid killing
#      a healthy connection / the opencode 4096 chain).
#   4. Auto-reconnects to the discovered port; prunes stale offline entries.
#
# Single-instance: a flock(1) on $LOCK_FILE guarantees exactly one loop even
# if Termux:Boot and a manual launcher race at nearly the same time.
#
# Usage:
#   ./tool/opencode/keep_adb_alive.sh          # loop forever (flock-guarded)
#   ./tool/opencode/keep_adb_alive.sh once     # single pass, print report
#
set -u

PREFIX=/data/data/com.termux/files/usr
export PATH="$PREFIX/bin:$PATH"

TERMUX_HOME="${TERMUX_HOME:-/data/data/com.termux/files/home}"
PHONE_IP=192.168.8.36
INTERVAL="${KEEP_ADB_INTERVAL:-20}"
LOG="${KEEP_ADB_LOG:-$TERMUX_HOME/keep_adb_alive.log}"
LOCK_FILE="${KEEP_ADB_LOCK:-$TERMUX_HOME/.keep_adb_alive.lock}"

if [ -x /usr/local/bin/rish ]; then
  RISH=/usr/local/bin/rish
elif [ -x /data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/usr/local/bin/rish ]; then
  RISH=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs/usr/local/bin/rish
else
  RISH=""
fi

say() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

# Run adb with the lock fd (9) closed so the long-lived adb SERVER daemon never
# inherits the flock. flock() is tied to the open file description: if the
# forked server keeps fd 9 open, it holds the lock forever even after the
# keepalive script exits, blocking any future instance.
adb() { ( exec 9>&-; /data/data/com.termux/files/usr/bin/adb "$@" ); }

settings_fix() {
  # Re-assert the battery/network knobs that keep the session alive.
  [ -n "$RISH" ] || return 0
  $RISH -c 'settings put global stay_on_while_plugged_in 7' >/dev/null 2>&1
  $RISH -c 'settings put global wifi_sleep_policy 2' >/dev/null 2>&1
  $RISH -c 'settings put global adb_wifi_enabled 1' >/dev/null 2>&1
  $RISH -c 'dumpsys deviceidle whitelist +com.termux' >/dev/null 2>&1
  $RISH -c 'cmd appops set com.termux RUN_IN_BACKGROUND allow' >/dev/null 2>&1
  $RISH -c 'cmd appops set com.termux RUN_ANY_IN_BACKGROUND allow' >/dev/null 2>&1
}

acquire_lock() {
  exec 9>"$LOCK_FILE" || return 1
  flock -n 9 2>/dev/null || return 1
  return 0
}

find_working_port() {
  # Prefer live discovery: adbd's Wi-Fi debugging TLS listener is the
  # listening TCP socket owned by uid 2000 (shell) inside the phone's
  # network namespace. Read it via rish (host shell can see the phone's
  # /proc/net/tcp*), decode the hex port, then validate with `adb connect`.
  local p port_candidates=()
  if [ -n "$RISH" ]; then
    port_candidates=( $($RISH -c 'awk '\''NR>1 && $4=="0A" && $8==2000 {print $2}'\'' /proc/net/tcp 2>/dev/null; awk '\''NR>1 && $4=="0A" && $8==2000 {print $2}'\'' /proc/net/tcp6 2>/dev/null' 2>/dev/null | cut -d: -f2 | sort -u) )
  fi
  [ "${#port_candidates[@]}" -eq 0 ] && port_candidates=(34797 39775 36923 38411 39531 46121 62110)
  for hexp in "${port_candidates[@]}"; do
    p=$((16#$hexp))
    rc="$(timeout 6 adb connect "$PHONE_IP:$p" 2>/dev/null >/dev/null; echo $?)"
    if [ "$rc" = "0" ]; then
      if adb devices | grep -q "^$PHONE_IP:$p[[:space:]]*device"; then
        echo "$p"
        return 0
      fi
    fi
  done
  return 1
}

prune_stale() {
  adb devices | awk '/offline/{print $1}' | while read -r d; do
    adb disconnect "$d" >/dev/null 2>&1
  done
  adb kill-server >/dev/null 2>&1
  adb start-server >/dev/null 2>&1
}

pass() {
  settings_fix

  if adb devices 2>/dev/null | grep -q "device$"; then
    # Healthy transport exists — just prune stale offline entries.
    adb devices | awk '/offline/{print $1}' | while read -r d; do
      adb disconnect "$d" >/dev/null 2>&1
    done
    return 0
  fi

  say "no healthy transport; rediscovering port..."
  adb kill-server >/dev/null 2>&1
  adb start-server >/dev/null 2>&1
  local p
  p="$(find_working_port)" && {
    say "connected via $PHONE_IP:$p"
    return 0
  } || say "no wireless port reachable right now (retrying)"
}

case "${1:-loop}" in
  once) pass ;;
  loop)
    if acquire_lock; then
      say "keep_adb_alive loop started (interval ${INTERVAL}s)"
      while true; do
        pass
        sleep "$INTERVAL"
      done
    else
      say "another keep_adb_alive instance holds the lock; exiting"
      exit 1
    fi
    ;;
esac
