#!/data/data/com.termux/files/usr/bin/bash
# install.sh - install the always-on OpenCode server setup on the phone (Termux).
#
# Copies the canonical scripts into ~/.opencode-ctl, symlinks `opencode-ctl` into
# $PREFIX/bin, installs the Termux:Boot autostart, enables the Termux wake-lock
# property, acquires the wake lock, and (re)starts the managed server.
#
# Usage (from a Termux shell, NOT from inside proot):
#   bash ~/delwaqty/tool/opencode/install.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CTL_DIR="$HOME/.opencode-ctl"
TERMUX_BOOT_DIR="$HOME/.termux/boot"
TERMUX_PROPS="$HOME/.termux/termux.properties"

mkdir -p "$CTL_DIR" "$TERMUX_BOOT_DIR"

install -m 755 "$HERE/opencode-ctl" "$CTL_DIR/opencode-ctl"
install -m 755 "$HERE/opencode-launch" "$CTL_DIR/opencode-launch"
install -m 755 "$HERE/opencode-boot.sh" "$TERMUX_BOOT_DIR/opencode-boot.sh"
if [ -f "$HERE/shizuku-init.sh" ]; then
  install -m 755 "$HERE/shizuku-init.sh" "$TERMUX_BOOT_DIR/shizuku-init.sh"
fi

ln -sf "$CTL_DIR/opencode-ctl" "$PREFIX/bin/opencode-ctl"

if ! grep -q '^wake-lock = true' "$TERMUX_PROPS" 2>/dev/null; then
  printf '\n# Always-on: keep the CPU awake while any Termux session runs.\nwake-lock = true\n' >> "$TERMUX_PROPS"
fi

echo "[install] taking wake lock"
termux-wake-lock 2>/dev/null || echo "[install] WARN: termux-wake-lock failed (install termux-api?)"

echo "[install] starting opencode server (managed, detached, auto-healing)"
"$CTL_DIR/opencode-ctl" start

echo "[install] done. Full summary:"
"$CTL_DIR/opencode-ctl" status

echo
echo "Autostart on boot needs Termux:Boot + Termux:API:"
echo "  pkg install termux-boot termux-api"
echo "Then open the Termux:Boot app once so it is not 'stopped' by Android"
echo "and can receive the boot broadcast."
