#!/bin/bash

# Build and upload to TestFlight for Prelura Swift
# Usage: ./scripts/build-ipa-for-testflight.sh [--upload]

set -e

PROJECT_NAME="Prelura-swift"
SCHEME="Prelura-swift"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/export"
IPA_PATH="./build/ipa/${PROJECT_NAME}.ipa"
EXPORT_OPTIONS="./ExportOptions.plist"

UPLOAD=false
if [[ "$1" == "--upload" ]]; then
    UPLOAD=true
fi

echo "📦 Building IPA for TestFlight..."
echo "Bundle ID: com.prelura.preloved"
echo "Team ID: 94QA2FVSW2"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf ./build/${PROJECT_NAME}.xcarchive
rm -rf ${EXPORT_PATH}
mkdir -p ./build/ipa

# Step 1: Archive
echo ""
echo "Step 1: Creating archive..."
xcodebuild archive \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -configuration Release \
    -archivePath ${ARCHIVE_PATH} \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=94QA2FVSW2 \
    PRODUCT_BUNDLE_IDENTIFIER=com.prelura.preloved \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Archive failed."
    exit 1
fi

echo "✅ Archive created successfully!"

# Step 2: Export IPA
echo ""
echo "Step 2: Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath ${ARCHIVE_PATH} \
    -exportPath ${EXPORT_PATH} \
    -exportOptionsPlist ${EXPORT_OPTIONS} \
    -allowProvisioningUpdates

if [ $? -ne 0 ]; then
    echo "❌ Export failed."
    exit 1
fi

# Move IPA to standard location
if [ -f "${EXPORT_PATH}/${PROJECT_NAME}.ipa" ]; then
    cp "${EXPORT_PATH}/${PROJECT_NAME}.ipa" "${IPA_PATH}"
    echo "✅ IPA exported successfully: ${IPA_PATH}"
else
    echo "❌ IPA file not found at ${EXPORT_PATH}/${PROJECT_NAME}.ipa"
    exit 1
fi

# Step 3: Upload if requested
if [ "$UPLOAD" = true ]; then
    echo ""
    echo "Step 3: Uploading to TestFlight..."
    
    # Get credentials: project file first (permanent store), then keychain
    CREDS_FILE="$(cd "$(dirname "$0")/.." && pwd)/scripts/testflight-credentials.json"
    if [ -f "$CREDS_FILE" ]; then
        CREDENTIALS=$(cat "$CREDS_FILE")
        echo "Using credentials from scripts/testflight-credentials.json"
    fi
    if [ -z "$CREDENTIALS" ]; then
        CREDENTIALS=$(security find-generic-password -s "AC_PASSWORD" -a "Prelura-swift" -w 2>/dev/null)
    fi
    
    if [ -z "$CREDENTIALS" ]; then
        echo "❌ No credentials found (keychain or scripts/testflight-credentials.json)."
        echo "   Either run: ./scripts/setup-testflight-keychain.sh"
        echo "   Or create scripts/testflight-credentials.json (see scripts/testflight-credentials.json.example)"
        exit 1
    fi
    
    # Parse credentials (must be JSON with "method": "password" or "api_key")
    METHOD=$(echo "$CREDENTIALS" | tr -d '\n' | grep -oE '"method"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    
    if [ -z "$METHOD" ]; then
        echo "❌ Credentials are not valid JSON with a \"method\" field."
        echo "   Use scripts/testflight-credentials.json.example as template, or run ./scripts/setup-testflight-keychain.sh"
        exit 1
    fi
    
    if [ "$METHOD" = "password" ]; then
        # Apple ID + App-specific password (parse with Python for reliability with any JSON formatting)
        if command -v python3 &>/dev/null; then
            APPLE_ID=$(echo "$CREDENTIALS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('apple_id', ''))" 2>/dev/null)
            APP_SPECIFIC_PASSWORD=$(echo "$CREDENTIALS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('app_specific_password', ''))" 2>/dev/null)
        fi
        if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
            APPLE_ID=$(echo "$CREDENTIALS" | tr -d '\n' | grep -oE '"apple_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            APP_SPECIFIC_PASSWORD=$(echo "$CREDENTIALS" | tr -d '\n' | grep -oE '"app_specific_password"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
        fi
        
        echo "Uploading with Apple ID authentication..."
        xcrun altool --upload-app \
            --type ios \
            --file "${IPA_PATH}" \
            --username "$APPLE_ID" \
            --password "$APP_SPECIFIC_PASSWORD" \
            2>&1 | tee /tmp/testflight_upload.log
        
    elif [ "$METHOD" = "api_key" ]; then
        # API Key method
        API_KEY_ID=$(echo "$CREDENTIALS" | grep -o '"api_key_id":"[^"]*"' | cut -d'"' -f4)
        ISSUER_ID=$(echo "$CREDENTIALS" | grep -o '"issuer_id":"[^"]*"' | cut -d'"' -f4)
        
        echo "Uploading with API Key authentication..."
        xcrun altool --upload-app \
            --type ios \
            --file "${IPA_PATH}" \
            --apiKey "$API_KEY_ID" \
            --apiIssuer "$ISSUER_ID" \
            2>&1 | tee /tmp/testflight_upload.log
    else
        echo "❌ Unknown authentication method: $METHOD"
        exit 1
    fi
    
    # Check upload result
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo ""
        echo "✅ Upload successful!"
        echo "Check App Store Connect for processing status."
        echo ""
        echo "Upload log saved to: /tmp/testflight_upload.log"
    else
        echo ""
        echo "❌ Upload failed. Check log: /tmp/testflight_upload.log"
        cat /tmp/testflight_upload.log | grep -i "error" | tail -10
        exit 1
    fi
else
    echo ""
    echo "ℹ️  IPA ready at: ${IPA_PATH}"
    echo "To upload, run: $0 --upload"
fi
