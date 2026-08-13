#!/data/data/com.termux/files/usr/bin/sh
# opencode-boot.sh — Termux:Boot autostart for the OpenCode server.
#
# Runs automatically at device boot ONLY if Termux:Boot is installed.
# Boot sequence (canonical chain):
#   Termux:Boot -> opencode-ctl start -> tmux "opencode" -> opencode-launch
#     -> proot-distro (Ubuntu) -> opencode -> 127.0.0.1:4096
#
# Guarantees:
#   * idempotent: `opencode-ctl start` refuses to double-start an already
#     healthy server (exactly one tmux session, exactly one listener on 4096).
#   * wait-for-healthy: after start it probes /global/health (with auth) and
#     logs the final result to ~/.opencode-ctl/boot.log.
#   * wake-lock re-acquired so screen lock cannot suspend the runtime.
#   * explicit Termux home is used even if $HOME is not set by the launcher.

set -u

TERMUX_HOME="/data/data/com.termux/files/home"
: "${PREFIX:=/data/data/com.termux/files/usr}"
: "${HOME:=$TERMUX_HOME}"

export HOME
export PATH="$PREFIX/bin:$PATH"
export TERMUX_HOME

CTL="$TERMUX_HOME/.opencode-ctl/opencode-ctl"
STATE="$TERMUX_HOME/.opencode-ctl"
LOGFILE="$STATE/boot.log"

mkdir -p "$STATE"

log() {
  echo "$(date '+%F %T'): $1" >> "$LOGFILE"
}

log "boot script started (home=$HOME)"

if [ ! -x "$CTL" ]; then
  log "opencode-ctl missing at $CTL"
  log "boot script FAILED"
  exit 1
fi

termux-wake-lock 2>/dev/null && log "wake-lock acquired" || log "wake-lock FAILED (is termux-api installed?)"

"$CTL" start >> "$LOGFILE" 2>&1
log "opencode-ctl start finished"

HOST=127.0.0.1
PORT=4096
UP=0
log "waiting for server health on $HOST:$PORT..."
i=1
while [ "$i" -le 30 ]; do
  if curl -s -u opencode:test-local-only -o /dev/null -m 2 "http://$HOST:$PORT/global/health" 2>/dev/null; then
    UP=1
    break
  fi
  i=$((i + 1))
  sleep 3
done

if [ "$UP" -eq 1 ]; then
  log "boot SUCCESS: OpenCode became healthy on $HOST:$PORT (auth OK)"
else
  log "boot FAILED: server not healthy after 90s"
fi

"$CTL" status >> "$LOGFILE" 2>&1
log "boot script completed"
