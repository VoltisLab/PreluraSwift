#!/bin/bash

# Setup App Icon from a single source image
# Usage: ./scripts/setup-app-icon.sh /path/to/icon.png

set -e

if [ -z "$1" ]; then
    echo "Usage: ./scripts/setup-app-icon.sh /path/to/icon.png"
    echo "The source image should be at least 1024x1024 pixels"
    exit 1
fi

SOURCE_IMAGE="$1"
ICON_DIR="./Prelura-swift/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    exit 1
fi

echo "📱 Setting up app icon from: $SOURCE_IMAGE"
echo ""

# Create icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

# Generate all required icon sizes using sips (macOS built-in tool)
echo "Generating icon sizes..."

# 1024x1024 (App Store)
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-1024.png" > /dev/null 2>&1

# iPhone icons
sips -z 120 120 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-60@2x.png" > /dev/null 2>&1  # 60pt @2x = 120px
sips -z 180 180 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-60@3x.png" > /dev/null 2>&1  # 60pt @3x = 180px
sips -z 40 40 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-20@2x.png" > /dev/null 2>&1     # 20pt @2x = 40px
sips -z 60 60 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-20@3x.png" > /dev/null 2>&1     # 20pt @3x = 60px
sips -z 58 58 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-29@2x.png" > /dev/null 2>&1     # 29pt @2x = 58px
sips -z 87 87 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-29@3x.png" > /dev/null 2>&1     # 29pt @3x = 87px
sips -z 80 80 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-40@2x.png" > /dev/null 2>&1     # 40pt @2x = 80px
sips -z 120 120 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-40@3x.png" > /dev/null 2>&1    # 40pt @3x = 120px

# iPad icons
sips -z 76 76 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-76.png" > /dev/null 2>&1        # 76pt @1x = 76px
sips -z 152 152 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-76@2x.png" > /dev/null 2>&1   # 76pt @2x = 152px
sips -z 167 167 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-83.5@2x.png" > /dev/null 2>&1 # 83.5pt @2x = 167px
sips -z 20 20 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-20.png" > /dev/null 2>&1        # 20pt @1x = 20px
sips -z 40 40 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-20@2x-1.png" > /dev/null 2>&1    # 20pt @2x = 40px
sips -z 29 29 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-29.png" > /dev/null 2>&1       # 29pt @1x = 29px
sips -z 58 58 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-29@2x-1.png" > /dev/null 2>&1   # 29pt @2x = 58px
sips -z 40 40 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-40.png" > /dev/null 2>&1       # 40pt @1x = 40px
sips -z 80 80 "$SOURCE_IMAGE" --out "$ICON_DIR/AppIcon-40@2x-1.png" > /dev/null 2>&1   # 40pt @2x = 80px

echo "✅ All icon sizes generated!"
echo ""
echo "Icons created in: $ICON_DIR"
echo ""
echo "Next steps:"
echo "1. Rebuild the archive: ./scripts/build-ipa-for-testflight.sh"
echo "2. Upload to TestFlight: ./upload-testflight.sh"
