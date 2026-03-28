#!/usr/bin/env bash
# Live unified logs from the Prelura app running in the iOS Simulator → your terminal.
# Usage:
#   ./scripts/stream-prelura-simulator-logs.sh              # default: iPhone 14, **focused** (auth/push/app Logger)
#   ./scripts/stream-prelura-simulator-logs.sh "iPhone 14 Alt"
#   PRELURA_LOG_VERBOSE=1 ./scripts/stream-prelura-simulator-logs.sh   # full firehose (same as old behavior)
#
# Leave this running, then use the app in that simulator. Ctrl+C to stop.
# Requires the simulator booted (e.g. after relaunch-both or open Simulator.app).
#
# Important: `log stream` only shows **new** lines after it starts. After reinstall/login, keep this
# running or restart it — scrolling an old terminal buffer will not “update” live.

set -euo pipefail

DEVICE="${1:-iPhone 14}"

if ! xcrun simctl list devices available | grep -qF "$DEVICE"; then
  echo "No available simulator named \"$DEVICE\". Try:"
  xcrun simctl list devices available | grep -E "iPhone" || true
  exit 1
fi

if [[ "${PRELURA_LOG_VERBOSE:-}" == "1" ]]; then
  PRED='(process == "Prelura-swift") OR (subsystem == "com.prelura.preloved") OR (eventMessage CONTAINS[c] "[Push]") OR (eventMessage CONTAINS[c] "[Auth]")'
  MODE="verbose (entire Prelura-swift process + app subsystem)"
else
  # Default: **do not** filter by process alone — that matches every UIKit/CFNetwork/defaults line.
  # Logger(subsystem: com.prelura.preloved) + Swift print lines we tag with [Push] / [Auth].
  PRED='(subsystem == "com.prelura.preloved") OR (eventMessage CONTAINS[c] "[Push]") OR (eventMessage CONTAINS[c] "[Auth]") OR (eventMessage CONTAINS[c] "[FCM TEST]")'
  MODE="focused (com.prelura.preloved + [Auth]/[Push] prints only)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Live log stream — simulator: $DEVICE  ($MODE)"
echo "Verbose firehose:  PRELURA_LOG_VERBOSE=1 $0 \"$DEVICE\""
echo "Stop: Ctrl+C"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exec xcrun simctl spawn "$DEVICE" log stream \
  --style compact \
  --level debug \
  --predicate "$PRED"
