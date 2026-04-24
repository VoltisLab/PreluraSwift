#!/bin/bash
# Install + launch a NotepadPro DMG like clipstack/scripts/install-and-launch-from-dmg.sh.
# Usage:
#   ./scripts/notepadpro-install-dmg.sh /path/to/notepadpro-installer.dmg

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /absolute/path/to/notepadpro-installer.dmg"
  echo "If the .app name differs, set APP_BASENAME (default: NotepadPro.app)."
  exit 1
fi

DMG="$1"
APP_BASENAME="${APP_BASENAME:-NotepadPro.app}"

exec "$SCRIPT_DIR/flutter-install-and-launch-from-dmg.sh" "$DMG" "$APP_BASENAME"
