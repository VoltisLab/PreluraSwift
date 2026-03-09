#!/bin/bash

# Upload existing IPA to TestFlight
# Looks for IPA at: build/export/Prelura-swift.ipa

set -e

PROJECT_NAME="Prelura-swift"
IPA_PATH="./build/export/${PROJECT_NAME}.ipa"

echo "📤 Uploading to TestFlight..."
echo ""

if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA file not found at: $IPA_PATH"
    echo "Please build the IPA first using: ./scripts/build-ipa-for-testflight.sh"
    exit 1
fi

echo "Found IPA: $IPA_PATH"
echo ""

# Get credentials from keychain
CREDENTIALS_RAW=$(security find-generic-password -s "AC_PASSWORD" -a "Prelura-swift" -w 2>/dev/null)

if [ -z "$CREDENTIALS_RAW" ]; then
    echo "❌ AC_PASSWORD not found in keychain."
    echo "Please run: ./scripts/setup-testflight-keychain.sh"
    exit 1
fi

# Decode hex-encoded credentials if needed
CREDENTIALS=$(echo "$CREDENTIALS_RAW" | xxd -r -p 2>/dev/null || echo "$CREDENTIALS_RAW")

# Parse credentials using Python for reliable JSON parsing
METHOD=$(echo "$CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin)['method'])" 2>/dev/null)

if [ "$METHOD" = "password" ]; then
    # Apple ID + App-specific password
    APPLE_ID=$(echo "$CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin)['apple_id'])" 2>/dev/null)
    APP_SPECIFIC_PASSWORD=$(echo "$CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin)['app_specific_password'])" 2>/dev/null)
    
    echo "Uploading with Apple ID authentication..."
    xcrun altool --upload-app \
        --type ios \
        --file "${IPA_PATH}" \
        --username "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        2>&1 | tee /tmp/testflight_upload.log
    
elif [ "$METHOD" = "api_key" ]; then
    # API Key method
    API_KEY_ID=$(echo "$CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin)['api_key_id'])" 2>/dev/null)
    ISSUER_ID=$(echo "$CREDENTIALS" | python3 -c "import sys, json; print(json.load(sys.stdin)['issuer_id'])" 2>/dev/null)
    
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
