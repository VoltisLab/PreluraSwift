#!/usr/bin/env bash
# Build + install + launch on iPhone 14 & Alt, then stream ChatWS OSLog from iPhone 14 for STREAM_SEC seconds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STREAM_SEC="${PRELURA_CHATWS_STREAM_SEC:-90}"
DEV="${PRELURA_CHATWS_LOG_DEVICE:-iPhone 14}"

cd "$ROOT"
./scripts/relaunch-both-live-build.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Streaming ChatWS logs from simulator \"$DEV\" for ${STREAM_SEC}s"
echo "  (subsystem com.prelura.preloved, category ChatWS)"
echo "  Open a chat on that simulator and send/receive - watch for:"
echo "    chat_message_parsed | json_parse_failed | chat_frame_dropped"
echo "  Extend: PRELURA_CHATWS_STREAM_SEC=300 $0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! xcrun simctl list devices available | grep -qF "$DEV"; then
  echo "Device not found: $DEV - skip log stream."
  exit 0
fi

xcrun simctl boot "$DEV" 2>/dev/null || true

# Prefer matching our print("[ChatWS] …") lines; also allow OSLog category ChatWS (varies by OS).
( xcrun simctl spawn "$DEV" log stream --style compact --predicate \
  'eventMessage CONTAINS "ChatWS" OR (subsystem == "com.prelura.preloved" AND category == "ChatWS")' 2>&1 &
  LP=$!
  sleep "$STREAM_SEC"
  kill "$LP" 2>/dev/null || true
  wait "$LP" 2>/dev/null || true
) || true

echo ""
echo "Stream window ended. Manual: xcrun simctl spawn \"$DEV\" log stream --style compact --predicate 'subsystem == \"com.prelura.preloved\" AND category == \"ChatWS\"'"
