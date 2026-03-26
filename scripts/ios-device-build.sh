#!/usr/bin/env bash
# Build for a physical iPhone: refreshes provisioning if you're signed into Xcode (same as GUI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEST="${1:-generic/platform=iOS}"

exec xcodebuild \
  -scheme Prelura-swift \
  -destination "$DEST" \
  -configuration Debug \
  -allowProvisioningUpdates \
  build
