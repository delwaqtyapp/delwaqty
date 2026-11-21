#!/data/data/com.termux/files/usr/bin/bash
# One-command OTA v1.0.3 publish — run on Termux in the delwaqty repo root.
# Builds all 4 flavors (debug, signed with this device's debug keystore —
# the same key that signed v1.0.2, so installed apps update cleanly),
# uploads APKs + versions.json to the v1.0.3 GitHub release.
#
# Prereq: .env.prod present (same file used for the v1.0.2 build).
set -e
cd "$(dirname "$0")/.."
git fetch origin master && git checkout master && git pull --ff-only origin master
[ -f .env.prod ] || { echo "ERROR: .env.prod missing"; exit 1; }
ENV_FILE=.env.prod bash scripts/publish_ota.sh --patch
echo "Now: git add pubspec.yaml ota/versions.json && git commit -m 'OTA v1.0.3' && git push"
