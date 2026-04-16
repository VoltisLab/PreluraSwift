#!/usr/bin/env bash
# Full xcodebuild output: stdout + tee to a log file (live: `tail -f "$LOG"` in another terminal).
# Then install + launch on iPhone 14 and iPhone 14 Alt when present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="Prelura-swift.xcodeproj"
SCHEME="Prelura-swift"
BUNDLE="com.prelura.preloved"
LOG="${PRELURA_XCODEBUILD_LOG:-/tmp/prelura-xcodebuild-$(date +%Y%m%d-%H%M%S).log}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Prelura live build log: $LOG"
echo "Live stream (Cursor terminal tab):  tail -f \"$LOG\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$ROOT"

if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build 2>&1 | tee "$LOG"; then
  echo "xcodebuild failed. See: $LOG"
  exit 1
fi

APP="$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app 2>/dev/null | head -1)"
if [[ ! -d "$APP" ]]; then
  echo "❌ Could not find Prelura-swift.app under DerivedData after build."
  echo "   Full log: $LOG"
  exit 1
fi
echo "Using: $APP"

open -a Simulator 2>/dev/null || true

sim_device_available() {
  local name="$1"
  xcrun simctl list devices available 2>/dev/null | grep -F "    ${name} (" >/dev/null
}

boot_and_run() {
  local dev="$1"
  echo "Device: $dev"
  xcrun simctl boot "$dev" 2>/dev/null || true
  xcrun simctl bootstatus "$dev" -b 2>/dev/null || true
  xcrun simctl terminate "$dev" "$BUNDLE" 2>/dev/null || true
  if ! xcrun simctl install "$dev" "$APP" 2>&1; then
    echo "simctl install failed for $dev"
    exit 1
  fi
  local out
  if ! out=$(xcrun simctl launch "$dev" "$BUNDLE" 2>&1); then
    echo "simctl launch failed for $dev: $out"
    exit 1
  fi
  echo "Launch $dev: $out"
}

# Exact names only (grep -F "iPhone 14" wrongly matches "iPhone 14 alt").
if sim_device_available "iPhone 14"; then boot_and_run "iPhone 14"; else echo "Skip (not found): iPhone 14"; fi
if sim_device_available "iPhone 14 Alt"; then boot_and_run "iPhone 14 Alt"; else echo "Skip (not found): iPhone 14 Alt"; fi

echo "Build log (full): $LOG"
