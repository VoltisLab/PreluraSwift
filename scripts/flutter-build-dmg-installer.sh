#!/bin/bash
# Same flow as clipstack/scripts/build-dmg-installer.sh — works for any Flutter macOS app.
# Usage:
#   ./scripts/flutter-build-dmg-installer.sh /path/to/flutter_project
#   ./scripts/flutter-build-dmg-installer.sh /path/to/flutter_project /custom/output.dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <flutter_project_root> [output.dmg]"
  exit 1
fi

PROJECT_ROOT="$(cd "$1" && pwd)"
shift || true

if [[ $# -gt 0 ]]; then
  OUTPUT_PATH="$1"
else
  TS="$(date +%Y%m%d-%H%M%S)"
  PUB_NAME="$(grep -m1 '^name:' "$PROJECT_ROOT/pubspec.yaml" 2>/dev/null | sed 's/^name:[[:space:]]*//;s/[[:space:]].*//;s/^"//;s/"$//' || echo app)"
  OUTPUT_PATH="$HOME/Downloads/${PUB_NAME}-installer-$TS.dmg"
fi

if [[ ! -f "$PROJECT_ROOT/pubspec.yaml" ]]; then
  echo "Not a Flutter project (missing pubspec.yaml): $PROJECT_ROOT"
  exit 1
fi
if [[ ! -d "$PROJECT_ROOT/macos" ]]; then
  echo "No macos/ folder — run 'flutter create . --platforms=macos' in that project first."
  exit 1
fi

OUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUT_DIR"

if ! touch "$OUT_DIR/.flutter_dmg_write_test" 2>/dev/null; then
  PUB_NAME="$(grep -m1 '^name:' "$PROJECT_ROOT/pubspec.yaml" 2>/dev/null | sed 's/^name:[[:space:]]*//;s/[[:space:]].*//;s/^"//;s/"$//' || echo app)"
  OUTPUT_PATH="$PROJECT_ROOT/build/dmg/${PUB_NAME}-installer.dmg"
  OUT_DIR="$(dirname "$OUTPUT_PATH")"
  mkdir -p "$OUT_DIR"
else
  rm -f "$OUT_DIR/.flutter_dmg_write_test"
fi

export PATH="$HOME/flutter/bin:$HOME/.gem/ruby/2.6.0/bin:$PATH"
if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not on PATH. Install Flutter or add e.g. ~/flutter/bin to PATH."
  exit 1
fi

cd "$PROJECT_ROOT"
flutter build macos --release

RELEASE_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"
shopt -s nullglob
APPS=( "$RELEASE_DIR"/*.app )
shopt -u nullglob
if [[ ${#APPS[@]} -eq 0 ]]; then
  echo "No .app found under: $RELEASE_DIR"
  exit 1
fi
APP="${APPS[0]}"
APP_BASENAME="$(basename "$APP")"
VOLNAME="${APP_BASENAME%.app}"

DMG_STAGING="$PROJECT_ROOT/build/dmg/install-root"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$DMG_STAGING" \
  -format UDZO \
  "$OUTPUT_PATH"

echo "DMG exported to: $OUTPUT_PATH"
