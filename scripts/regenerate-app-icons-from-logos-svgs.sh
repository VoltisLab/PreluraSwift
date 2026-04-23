#!/bin/bash
# Regenerate the primary iOS app icon PNGs from "Primary Logo.svg" in a folder
# and, when present, "Admin Logo.svg" into `AppIcon-Admin` (MyPrelura / staff build).
# Default: ~/Downloads/Logos/Primary Logo.svg
#
# Requires: macOS qlmanage + sips (no extra installs).
# Usage: ./scripts/regenerate-app-icons-from-logos-svgs.sh [/path/to/Logos]

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGOS="${1:-$HOME/Downloads/Logos}"
ASSETS="$ROOT/Prelura-swift/Assets.xcassets"
SVG="$LOGOS/Primary Logo.svg"
SVG_ADMIN="$LOGOS/Admin Logo.svg"

gen_icons() {
  local svg_path="$1"
  local icon_dir="$2"
  local tmp
  tmp="$(mktemp -d)"
  qlmanage -t -s 1024 -o "$tmp" "$svg_path" 2>/dev/null || true
  local thumb
  thumb="$(ls "$tmp"/*.png 2>/dev/null | head -1)"
  if [[ -z "$thumb" || ! -f "$thumb" ]]; then
    echo "❌ No PNG thumbnail from qlmanage for: $svg_path"
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$icon_dir"
  sips -z 1024 1024 "$thumb" --out "$tmp/base1024.png" >/dev/null
  SRC="$tmp/base1024.png"
  sips -z 1024 1024 "$SRC" --out "$icon_dir/AppIcon-1024.png" >/dev/null
  sips -z 120 120 "$SRC" --out "$icon_dir/AppIcon-60@2x.png" >/dev/null
  sips -z 180 180 "$SRC" --out "$icon_dir/AppIcon-60@3x.png" >/dev/null
  sips -z 40 40 "$SRC" --out "$icon_dir/AppIcon-20@2x.png" >/dev/null
  sips -z 60 60 "$SRC" --out "$icon_dir/AppIcon-20@3x.png" >/dev/null
  sips -z 58 58 "$SRC" --out "$icon_dir/AppIcon-29@2x.png" >/dev/null
  sips -z 87 87 "$SRC" --out "$icon_dir/AppIcon-29@3x.png" >/dev/null
  sips -z 80 80 "$SRC" --out "$icon_dir/AppIcon-40@2x.png" >/dev/null
  sips -z 120 120 "$SRC" --out "$icon_dir/AppIcon-40@3x.png" >/dev/null
  sips -z 76 76 "$SRC" --out "$icon_dir/AppIcon-76.png" >/dev/null
  sips -z 152 152 "$SRC" --out "$icon_dir/AppIcon-76@2x.png" >/dev/null
  sips -z 167 167 "$SRC" --out "$icon_dir/AppIcon-83.5@2x.png" >/dev/null
  sips -z 20 20 "$SRC" --out "$icon_dir/AppIcon-20.png" >/dev/null
  sips -z 40 40 "$SRC" --out "$icon_dir/AppIcon-20@2x-1.png" >/dev/null
  sips -z 29 29 "$SRC" --out "$icon_dir/AppIcon-29.png" >/dev/null
  sips -z 58 58 "$SRC" --out "$icon_dir/AppIcon-29@2x-1.png" >/dev/null
  sips -z 40 40 "$SRC" --out "$icon_dir/AppIcon-40.png" >/dev/null
  sips -z 80 80 "$SRC" --out "$icon_dir/AppIcon-40@2x-1.png" >/dev/null
  rm -rf "$tmp"
  echo "✅ $icon_dir"
}

[[ -d "$LOGOS" ]] || { echo "❌ Logos folder not found: $LOGOS"; exit 1; }
[[ -f "$SVG" ]] || { echo "❌ Missing: $SVG"; exit 1; }

gen_icons "$SVG" "$ASSETS/AppIcon.appiconset"

if [[ -f "$SVG_ADMIN" ]]; then
  mkdir -p "$ASSETS/AppIcon-Admin.appiconset"
  cp "$ASSETS/AppIcon.appiconset/Contents.json" "$ASSETS/AppIcon-Admin.appiconset/Contents.json"
  gen_icons "$SVG_ADMIN" "$ASSETS/AppIcon-Admin.appiconset"
else
  echo "ℹ️  No Admin Logo.svg at: $SVG_ADMIN (skip AppIcon-Admin)"
fi

echo "Done. Rebuild the app in Xcode."
