#!/bin/bash

# Setup TestFlight keychain item for Prelura Swift
# This script sets up the AC_PASSWORD keychain item used for TestFlight uploads.
#
# Quick setup with Apple ID + 16-character app-specific password (the code from Apple):
#   ./scripts/setup-testflight-keychain.sh password "your@appleid.com" "xxxx-xxxx-xxxx-xxxx"
# Create the app-specific password at: https://appleid.apple.com → Sign-In and Security → App-Specific Passwords

set -e

echo "🔐 Setting up TestFlight keychain authentication..."
echo ""
echo "This will store your App Store Connect credentials in the keychain."
echo "You'll need either:"
echo "  1. Apple ID + App-specific password (the 16-character code from Apple), OR"
echo "  2. API Key ID + Issuer ID + API Key file (.p8)"
echo ""
echo "  One-liner: $0 password \"your@appleid.com\" \"xxxx-xxxx-xxxx-xxxx\""
echo ""

# Check if AC_PASSWORD already exists
if security find-generic-password -s "AC_PASSWORD" -a "Prelura-swift" &>/dev/null; then
    echo "⚠️  AC_PASSWORD already exists in keychain."
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping keychain setup."
        exit 0
    fi
    security delete-generic-password -s "AC_PASSWORD" -a "Prelura-swift" 2>/dev/null || true
fi

# Check for environment variables or command-line arguments
if [ -n "$APPLE_ID" ] && [ -n "$APP_SPECIFIC_PASSWORD" ]; then
    METHOD_CHOICE=1
    # Use environment variables
elif [ -n "$API_KEY_ID" ] && [ -n "$ISSUER_ID" ] && [ -n "$API_KEY_FILE" ]; then
    METHOD_CHOICE=2
    # Use environment variables
elif [ "$1" = "api" ] && [ -n "$2" ] && [ -n "$3" ] && [ -n "$4" ]; then
    METHOD_CHOICE=2
    API_KEY_ID="$2"
    ISSUER_ID="$3"
    KEY_FILE_PATH="$4"
elif [ "$1" = "password" ] && [ -n "$2" ] && [ -n "$3" ]; then
    METHOD_CHOICE=1
    APPLE_ID="$2"
    APP_SPECIFIC_PASSWORD="$3"
else
    echo "Choose authentication method:"
    echo "1. Apple ID + App-specific password"
    echo "2. API Key (Key ID + Issuer ID + .p8 file path)"
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo
    METHOD_CHOICE="$REPLY"
fi

if [[ $METHOD_CHOICE =~ ^[1]$ ]]; then
    # Apple ID + App-specific password
    if [ -z "$APPLE_ID" ]; then
        read -p "Enter your Apple ID: " APPLE_ID
    fi
    if [ -z "$APP_SPECIFIC_PASSWORD" ]; then
        read -sp "Enter your App-specific password: " APP_SPECIFIC_PASSWORD
        echo
    fi
    
    # Store as JSON in keychain
    CREDENTIALS=$(cat <<EOF
{
  "method": "password",
  "apple_id": "$APPLE_ID",
  "app_specific_password": "$APP_SPECIFIC_PASSWORD"
}
EOF
)
    
    echo "$CREDENTIALS" | security add-generic-password -s "AC_PASSWORD" -a "Prelura-swift" -w "$CREDENTIALS" -U
    
elif [[ $METHOD_CHOICE =~ ^[2]$ ]]; then
    # API Key method
    if [ -z "$API_KEY_ID" ]; then
        read -p "Enter API Key ID: " API_KEY_ID
    fi
    if [ -z "$ISSUER_ID" ]; then
        read -p "Enter Issuer ID (UUID): " ISSUER_ID
    fi
    if [ -z "$KEY_FILE_PATH" ]; then
        KEY_FILE_PATH="$API_KEY_FILE"
    fi
    if [ -z "$KEY_FILE_PATH" ]; then
        read -p "Enter path to .p8 key file: " KEY_FILE_PATH
    fi
    
    if [ ! -f "$KEY_FILE_PATH" ]; then
        echo "❌ Key file not found: $KEY_FILE_PATH"
        exit 1
    fi
    
    # Copy key file to standard location
    mkdir -p ~/.appstoreconnect/private_keys
    cp "$KEY_FILE_PATH" ~/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8
    chmod 600 ~/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8
    
    # Store credentials as JSON
    CREDENTIALS=$(cat <<EOF
{
  "method": "api_key",
  "api_key_id": "$API_KEY_ID",
  "issuer_id": "$ISSUER_ID",
  "key_file": "~/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
}
EOF
)
    
    echo "$CREDENTIALS" | security add-generic-password -s "AC_PASSWORD" -a "Prelura-swift" -w "$CREDENTIALS" -U
else
    echo "❌ Invalid choice"
    exit 1
fi

echo ""
echo "✅ Keychain setup complete!"
echo "You can now use scripts/build-ipa-for-testflight.sh --upload"
