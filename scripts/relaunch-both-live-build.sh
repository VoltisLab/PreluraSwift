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
set -o pipefail
# xcodebuild sometimes exits non-zero with "failed without specifying errors" even after
# a valid signed .app is produced; we only fail if there is no app bundle.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build 2>&1 | tee "$LOG" || true

APP="$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app 2>/dev/null | head -1)"
if [[ ! -d "$APP" ]]; then
  echo "❌ Could not find Prelura-swift.app under DerivedData after build."
  echo "   Full log: $LOG"
  exit 1
fi
echo "Using: $APP"

for DEV in "iPhone 14" "iPhone 14 Alt"; do
  if xcrun simctl list devices available | grep -qF "$DEV"; then
    xcrun simctl boot "$DEV" 2>/dev/null || true
    xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
    xcrun simctl install "$DEV" "$APP"
    echo "Launch $DEV: $(xcrun simctl launch "$DEV" "$BUNDLE")"
  else
    echo "Skip (not found): $DEV"
  fi
done

echo "Build log (full): $LOG"
