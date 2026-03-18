#!/bin/bash
# Build, install, launch Prelura on iPhone 14 simulator, then stream app logs to terminal.
# PAY_DEBUG logs appear when you tap "Pay by card". Press Ctrl+C to stop the log stream.
set -e
cd "$(dirname "$0")/.."
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Prelura-swift.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
[ -z "$APP_PATH" ] && { echo "Prelura-swift.app not found. Run a build first."; exit 1; }

echo "Building..."
xcodebuild -project Prelura-swift.xcodeproj -scheme Prelura-swift -destination 'platform=iOS Simulator,name=iPhone 14' -configuration Debug build -quiet

echo "Terminating old app (if running)..."
xcrun simctl terminate "iPhone 14" com.prelura.preloved 2>/dev/null || true

echo "Installing and launching..."
xcrun simctl install "iPhone 14" "$APP_PATH"
xcrun simctl launch "iPhone 14" com.prelura.preloved

echo ""
echo "App is running. Streaming logs (PAY_DEBUG = payment flow). Tap 'Pay by card' to see flow. Ctrl+C to stop."
echo "---"
xcrun simctl spawn booted log stream --level debug --predicate 'composedMessage CONTAINS "PAY_DEBUG" OR subsystem == "com.prelura.preloved"'
