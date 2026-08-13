# OpenCode Server — Always-On Setup (Termux)

Canonical chain: **Termux → tmux → proot-distro (Ubuntu) → opencode → 127.0.0.1:4096**

These scripts keep the OpenCode server alive on the phone **even when the screen
locks or the terminal is closed**, exactly as configured on the DNP NX9.

## Why it used to disconnect

The server was started attached to a live terminal and **no wake-lock was held**.
When the phone screen locked, Android suspended/killed the Termux process tree,
so the server stopped answering and the client "disconnected". The fix keeps the
server fully detached and the CPU awake.

## What each file does

| File | Purpose |
|------|---------|
| `opencode-ctl` | Control script: `start / status / stop / restart / log`. Run it from a **Termux** shell. |
| `opencode-launch` | tmux payload. Runs the whole proot+opencode tree detached, with a **respawn loop** so a crash restarts the server automatically. |
| `opencode-boot.sh` | Termux:Boot autostart: takes the wake lock and starts the server at device boot. |
| `shizuku-init.sh` | Termux:Boot: probes Shizuku/rish from inside the proot (non-fatal if Shizuku is down). |
| `install.sh` | Installs the above on the phone, enables the Termux wake-lock property, and starts the managed server. |

## Install on the phone

```bash
bash ~/delwaqty/tool/opencode/install.sh
```

Or manually, from a Termux shell:

```bash
cp tool/opencode/opencode-ctl ~/.opencode-ctl/
cp tool/opencode/opencode-launch ~/.opencode-ctl/
chmod +x ~/.opencode-ctl/opencode-ctl ~/.opencode-ctl/opencode-launch
ln -sf ~/.opencode-ctl/opencode-ctl $PREFIX/bin/opencode-ctl
cp tool/opencode/opencode-boot.sh ~/.termux/boot/
cp tool/opencode/shizuku-init.sh ~/.termux/boot/
chmod +x ~/.termux/boot/opencode-boot.sh ~/.termux/boot/shizuku-init.sh
```

## Daily commands (Termux shell)

```bash
opencode-ctl status     # health, PIDs, port, tmux state
opencode-ctl restart    # clean stop + start (managed, detached)
opencode-ctl log        # recent server logs
```

## Connect to the server (IMPORTANT)

Start the server **once** with `opencode-ctl start` (or it auto-starts on boot).
Then **connect** — never re-start the server to "connect":

```bash
# inside the prorot/ubuntu app shell
opencode attach http://127.0.0.1:4096
```

The password defaults to `OPENCODE_SERVER_PASSWORD`; set it first:
`export OPENCODE_SERVER_PASSWORD=test-local-only` (an `oc` alias provides this).

> Wrong: `proot-distro login ubuntu -- bash -lc '... exec opencode serve ...'` is a
> server-START command attached to the terminal, not a connect command. Running it
> again while the managed server is up fails with `ServeError` (port in use) and
> recreates the fragile attached-to-terminal setup that disconnects on screen lock.

## Always-on guarantees

1. **Wake lock** — `termux-wake-lock` is taken on start, plus `wake-lock = true`
   in `~/.termux/termux.properties`, so the CPU stays awake with the screen off.
2. **Detached** — the tree lives in its own tmux session (`opencode`) started
   with `setsid`; closing the terminal or backgrounding the app does not kill it.
3. **Auto-heal** — `opencode-launch` respawns proot/opencode if it crashes.
   `opencode-ctl stop` sets a `.stop` flag first so a manual stop is not undone.
4. **Boot autostart** — `~/.termux/boot/opencode-boot.sh` restores the server
   after a reboot, but only when **Termux:Boot** and **Termux:API** are installed:
   `pkg install termux-boot termux-api`, then open the **Termux:Boot app once**
   — Android keeps it `stopped` until its Activity has launched, and a stopped
   app never receives `ACTION_BOOT_COMPLETED`. (Verified fix: `am start
   -n com.termux.boot/.BootActivity` flips its state to `stopped=false`.)

## Manual one-time step (recommended)

Battery optimization can still kill Termux in the background. Whitelist it:
**Android Settings → Apps → Termux → Battery → Unrestricted**
(or, from a PC: `adb shell dumpsys deviceidle whitelist +com.termux`).

## Runtime state

- Server: `http://127.0.0.1:4096` (user `opencode` / pass `test-local-only`)
- Control dir: `~/.opencode-ctl/` (launch log, stop flag)
- Server log: `<ubuntu-rootfs>/root/.local/share/opencode/log/opencode.log`
- Requires: `termux-api` (wake-lock), `tmux`, `proot-distro`, `curl`, plus the
  `ubuntu` proot distro already installed.
