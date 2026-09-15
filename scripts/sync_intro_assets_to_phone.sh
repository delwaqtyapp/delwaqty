#!/bin/bash
# Sync the bundled intro art into the phone-side Logo folder so the intro
# loads the images from the phone at runtime (fallback = bundled assets).
#
# Usage:
#   ./scripts/sync_intro_assets_to_phone.sh [adb-serial]
#     default serial: 192.168.8.36:5555
set -euo pipefail

SERIAL="${1:-192.168.8.36:5555}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGO_DIR="/storage/emulated/0/Pictures/Logo"
FILES=(
  "assets/egypt/intro_egypt_cinematic_background.png"
  "assets/egypt/delwaqty_logo_mark.png"
)

adb -s "$SERIAL" shell "mkdir -p $LOGO_DIR"
for f in "${FILES[@]}"; do
  adb -s "$SERIAL" push "$PROJECT_DIR/$f" "$LOGO_DIR/"
done
echo "Synced intro assets to $LOGO_DIR on $SERIAL"
echo "Replace the files there to use custom logo/background images."