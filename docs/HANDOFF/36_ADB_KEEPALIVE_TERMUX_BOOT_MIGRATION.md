# ADB Keepalive Migration to Independent Termux:Boot Lifecycle

## Scope
Move the Android Wi-Fi debugging keepalive (`keep_adb_alive.sh`) out of the
OpenCode/OmniRoute/PRoot lifecycle and into an independent Termux:Boot daemon so
the phone's wireless-debug transport survives OpenCode restarts and proot
restarts. Migrated live without dropping the DNP-NX9 session (incident resolved).

## Root Cause of the Incident During Migration
Two adb binaries shared one 5037 server and conflicted:
- proot `/usr/bin/adb` (v34.0.5-debian)
- host `/data/data/com.termux/files/usr/bin/adb` (v35.0.2)

Each could `kill-server` the other's server mid-session. The old PRoot-supervised
instance (PID 13774) and the new independent instance (eventually PID 13974) both
probed the same server, dropping the transport repeatedly. Additionally the
phone's wireless-debug PORT is dynamic and rotated; the previous static
`KNOWN_PORTS` list was stale, and the window's placed on system services
(uid 1000) instead of the real adbd listener.

Two further defects were found and fixed:
1. **Key mismatch** - the phone had only authorized the proot key. Host adb was
   presenting a different key -> `offline` despite TCP connect succeeding.
2. **flock leak** - the long-lived adb *server* (forked by an `adb` client)
   inherited fd 9 (the flock fd), so the keepalive lock was held by the adb
   server daemon even after the keepalive script exited, blocking later
   instances ("another keep_adb_alive instance holds the lock").

## Changes Made
### keep_adb_alive.sh (`tool/opencode/keep_adb_alive.sh`)
- Env-adaptive RISH path (`/usr/local/bin/rish` else rootfs host path).
- LOG/LOCK paths default to `$TERMUX_HOME` (host).
- Single-instance flock on `$LOCK_FILE`.
- **Dynamic port discovery** replacing stale `KNOWN_PORTS`: read the phone's
  `/proc/net/tcp` + `/proc/net/tcp6` listeners owned by uid 2000 (the adbd shell
  process) via rish, decode hex port (`0x87ED` -> 34797, `0xB169` -> 45417),
  validate with `adb connect`. Static list kept only as fallback.
- **flock fd isolation**: `adb()` wrapper runs `( exec 9>&-; adb ... )` so the
  forked adb server never inherits lock fd 9.
- `passthrough` healthy path now only prunes stale offline entries (does not
  `kill-server` a healthy transport).

### keep-adb-alive-init.sh (new, installed)
- Installed at `/data/data/com.termux/files/home/.termux/boot/keep-adb-alive-init.sh`
  (755). Launches the loop in its own session:
  `setsid "$KEEP_ADB" loop >> "$BOOT_LOG" 2>&1 < /dev/null &`.

### opencode-omniroute-start (`~/.opencode-ctl/opencode-omniroute-start`)
- Removed the background keepalive hook (lines 42-51) and the `KEEP_ADB` var.
  OmniRoute daemon logic untouched. Syntax verified with `bash -n`.

## Verification
- Single keepalive instance running outside PRoot:
  PID 13974, PPID 13960, TracerPid 0, UID 10526 (host). Old tracee PID 13774 GONE.
- Lock file held by keepalive (13974 + sleep child) — NOT the adb server.
- Transport healthy through a port rotation: 34797 -> 45417, rediscovered
  automatically (`connected via 192.168.8.36:45417` in log).
- `adb devices` -> `192.168.8.36:45417 device`.
- OpenCode `:4096/global/health` -> HTTP 200.
- OmniRoute `:20128` listening, daemon pidfile intact.

## Dormant / Removed
- Under AGENTS.md v12.1: the keepalive hook in `opencode-omniroute-start` was
  Dormant Infrastructure (a now-redundant second launch path). Removed because a
  superior replacement (independent Termux:Boot daemon) exists. Documented here.
- `KNOWN_PORTS` retained as fallback only (not deleted; adbd uid-2000 discovery
  is primary).

## Files Touched
- `tool/opencode/keep_adb_alive.sh`
- `tool/opencode/keep-adb-alive-init.sh` (new)
- `~/.termux/boot/keep-adb-alive-init.sh` (installed copy)
- `~/.opencode-ctl/opencode-omniroute-start`
- `~/.android/adbkey{,.pub}` + backups `.bak.oldhost` (key alignment)
- `~/.keep_adb_alive.lock`, `~/keep_adb_alive.log`, `~/.keep-adb-alive-init.log`