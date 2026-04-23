#!/usr/bin/env bash
# Full xcodebuild output: stdout + tee to a log file (live: `tail -f "$LOG"` in another terminal).
# Then install + launch on iPhone 14 and iPhone 14 Alt when present (UDID-resolved; install retries).
# Optional env: PRELURA_SIM_APP=/path/to/Prelura-swift.app (custom DerivedData output),
#               PRELURA_XCODEBUILD_LOG=/path/to.log
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

if [[ -n "${PRELURA_SIM_APP:-}" && -d "${PRELURA_SIM_APP}" ]]; then
  APP="$PRELURA_SIM_APP"
else
  APP="$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Prelura-swift-*/Build/Products/Debug-iphonesimulator/Prelura-swift.app 2>/dev/null | head -1)"
fi
if [[ ! -d "$APP" ]]; then
  echo "❌ Could not find Prelura-swift.app under DerivedData after build."
  echo "   Set PRELURA_SIM_APP to a .app bundle path, or build with default DerivedData."
  echo "   Full log: $LOG"
  exit 1
fi
echo "Using: $APP"

open -a Simulator 2>/dev/null || true

# Resolve exact device name → UDID (avoids ambiguous simctl name matching and whitespace/grep drift).
udid_for_device_name() {
  local want="$1"
  PRELURA_WANT="$want" python3 <<'PY'
import json, os, subprocess, sys
want = os.environ["PRELURA_WANT"]
raw = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    text=True,
)
data = json.loads(raw)
cands = []
for _runtime, devices in data.get("devices", {}).items():
    for d in devices:
        if d.get("name") != want:
            continue
        if d.get("isAvailable") is False:
            continue
        cands.append(d)
if not cands:
    sys.exit(1)
booted = [d for d in cands if d.get("state") == "Booted"]
pick = booted[0] if booted else cands[0]
print(pick["udid"])
PY
}

install_with_retries() {
  local udid="$1"
  local attempt=1
  local max=4
  while [[ "$attempt" -le "$max" ]]; do
    if xcrun simctl install "$udid" "$APP" 2>&1; then
      return 0
    fi
    echo "simctl install retry $attempt/$max for $udid (CoreSimulator race?)"
    sleep 2
    attempt=$((attempt + 1))
  done
  return 1
}

boot_and_run() {
  local label="$1"
  local udid
  if ! udid=$(udid_for_device_name "$label"); then
    echo "Skip (not found): $label"
    return 0
  fi
  echo "Device: $label ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b 2>/dev/null || true
  xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
  if ! install_with_retries "$udid"; then
    echo "simctl install failed for $label ($udid) after retries"
    exit 1
  fi
  local out
  if ! out=$(xcrun simctl launch "$udid" "$BUNDLE" 2>&1); then
    echo "simctl launch failed for $label ($udid): $out"
    exit 1
  fi
  echo "Launch $label: $out"
}

boot_and_run "iPhone 14"
sleep 1
boot_and_run "iPhone 14 Alt"

echo "Build log (full): $LOG"
