#!/bin/bash
# Copy-install a Flutter .app from a DMG to ~/Applications, then launch (same idea as clipstack).
# Usage:
#   ./scripts/flutter-install-and-launch-from-dmg.sh /path/to/installer.dmg MyApp.app

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 /absolute/path/to/installer.dmg AppName.app"
  exit 1
fi

DMG_PATH="$1"
APP_BASENAME="$2"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  exit 1
fi

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
DEST_APP="$INSTALL_DIR/$APP_BASENAME"
APP_EXE_NAME="${APP_BASENAME%.app}"

pkill -f "/Volumes/.*/${APP_BASENAME}/Contents/MacOS/" || true
pkill -f "$INSTALL_DIR/${APP_BASENAME}/Contents/MacOS/" || true

ATTACH_OUTPUT="$(hdiutil attach "$DMG_PATH" -nobrowse)"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk 'match($0, /\/Volumes\/.*/) { mp=substr($0, RSTART, RLENGTH) } END { print mp }')"

if [[ -z "$MOUNT_POINT" ]]; then
  echo "Could not determine DMG mount point."
  exit 1
fi

SRC_APP="$MOUNT_POINT/$APP_BASENAME"
if [[ ! -d "$SRC_APP" ]]; then
  echo "$APP_BASENAME not found in mounted DMG at: $SRC_APP"
  hdiutil detach "$MOUNT_POINT" -force || true
  exit 1
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

xattr -dr com.apple.quarantine "$DEST_APP" || true

hdiutil detach "$MOUNT_POINT" -force || true

open "$DEST_APP"
echo "Installed and launched from: $DEST_APP"
