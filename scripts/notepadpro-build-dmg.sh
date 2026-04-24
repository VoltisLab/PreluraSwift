#!/bin/bash
# NotepadPro: same DMG pipeline as clipstack (via flutter-build-dmg-installer.sh).
# Set NOTEPADPRO_ROOT if the repo is not next to PreluraIOS.
#
# Usage:
#   NOTEPADPRO_ROOT=/path/to/NotepadPro ./scripts/notepadpro-build-dmg.sh
#   ./scripts/notepadpro-build-dmg.sh /custom/output.dmg

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ROOT="${NOTEPADPRO_ROOT:-$REPO_ROOT/../NotepadPro}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd || true)"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "NotepadPro project not found."
  echo "Clone it next to PreluraIOS (../NotepadPro) or set NOTEPADPRO_ROOT to the Flutter project root."
  exit 1
fi

exec "$SCRIPT_DIR/flutter-build-dmg-installer.sh" "$ROOT" "$@"
