#!/bin/bash

# TestFlight Upload Script for Prelura Swift
# Bundle ID: com.prelura.preloved
# Team ID: 94QA2FVSW2

set -e

PROJECT_NAME="Prelura-swift"
SCHEME="Prelura-swift"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/export"
EXPORT_OPTIONS="./ExportOptions.plist"

echo "📦 Building archive for TestFlight..."
echo "Bundle ID: com.prelura.preloved"
echo "Team ID: 94QA2FVSW2"
echo ""

# Clean build folder
rm -rf ./build/${PROJECT_NAME}.xcarchive
rm -rf ${EXPORT_PATH}

# Archive
echo "Step 1: Creating archive..."
xcodebuild archive \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -configuration Release \
    -archivePath ${ARCHIVE_PATH} \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=94QA2FVSW2 \
    PRODUCT_BUNDLE_IDENTIFIER=com.prelura.preloved

if [ $? -ne 0 ]; then
    echo "❌ Archive failed. Please check signing settings in Xcode."
    echo ""
    echo "To fix signing issues:"
    echo "1. Open Prelura-swift.xcodeproj in Xcode"
    echo "2. Select the project in Navigator"
    echo "3. Go to 'Signing & Capabilities' tab"
    echo "4. Ensure 'Automatically manage signing' is checked"
    echo "5. Select Team: 94QA2FVSW2"
    echo "6. Ensure Bundle Identifier is: com.prelura.preloved"
    echo "7. Archive from Xcode: Product > Archive"
    exit 1
fi

echo "✅ Archive created successfully!"
echo ""

# Export IPA
echo "Step 2: Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath ${ARCHIVE_PATH} \
    -exportPath ${EXPORT_PATH} \
    -exportOptionsPlist ${EXPORT_OPTIONS}

if [ $? -ne 0 ]; then
    echo "❌ Export failed."
    exit 1
fi

echo "✅ IPA exported successfully!"
echo ""

# Upload to TestFlight
echo "Step 3: Uploading to TestFlight..."
IPA_PATH="${EXPORT_PATH}/${PROJECT_NAME}.ipa"

if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA file not found at $IPA_PATH"
    exit 1
fi

# Try using altool (deprecated but still works)
if command -v xcrun altool &> /dev/null; then
    echo "Using xcrun altool to upload..."
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey 94QA2FVSW2 \
        --apiIssuer 94QA2FVSW2
else
    echo "⚠️  xcrun altool not available. Please upload manually:"
    echo "   1. Open Xcode"
    echo "   2. Window > Organizer"
    echo "   3. Select the archive"
    echo "   4. Click 'Distribute App'"
    echo "   5. Choose 'App Store Connect'"
    echo "   6. Follow the prompts"
    echo ""
    echo "IPA location: $IPA_PATH"
fi

echo ""
echo "✅ Done! Check App Store Connect for upload status."
