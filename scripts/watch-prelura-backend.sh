#!/usr/bin/env bash
# Poll Prelura GraphQL every N seconds; print each result immediately (live on stdout)
# and append to a log file for tail -f in another window.
#
# Usage:
#   ./scripts/watch-prelura-backend.sh
#   ./scripts/watch-prelura-backend.sh --interval 300
#   ./scripts/watch-prelura-backend.sh --log ~/Desktop/prelura-backend.log
#   ./scripts/watch-prelura-backend.sh --once
#
# Live stream in two terminals:
#   Terminal A: ./scripts/watch-prelura-backend.sh --log /tmp/prelura-backend.log
#   Terminal B: tail -f /tmp/prelura-backend.log
#
# Env:
#   PRELURA_GRAPHQL_URL  (default: https://prelura.voltislabs.uk/graphql/)
#   CURL_CONNECT_TIMEOUT  (default: 10)
#   CURL_MAX_TIME         (default: 25)

set -euo pipefail

GRAPHQL_URL="${PRELURA_GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
INTERVAL=300
LOG_PATH=""
ONCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="${2:?}"; shift 2 ;;
    --log)      LOG_PATH="${2:?}"; shift 2 ;;
    --once)     ONCE=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-10}"
MAX_TIME="${CURL_MAX_TIME:-25}"

log_line() {
  local line="$1"
  printf '%s\n' "$line"
  if [[ -n "$LOG_PATH" ]]; then
    printf '%s\n' "$line" >> "$LOG_PATH"
  fi
}

run_check() {
  local ts out body http time_total err_file curl_exit err_txt snippet
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  err_file="$(mktemp)"
  set +e
  out="$(curl -sS \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d '{"query":"{ __typename }"}' \
    -w $'\n%{http_code} %{time_total}' 2>"$err_file")"
  curl_exit=$?
  set -e
  err_txt=""
  if [[ -s "$err_file" ]]; then
    err_txt="$(tr '\n' ' ' < "$err_file" | sed 's/  */ /g')"
  fi
  rm -f "$err_file"

  if [[ $curl_exit -ne 0 ]]; then
    log_line "[$ts] FAIL curl_exit=$curl_exit ${err_txt}"
    return
  fi

  http="$(echo "$out" | tail -n 1 | awk '{print $1}')"
  time_total="$(echo "$out" | tail -n 1 | awk '{print $2}')"
  body="$(echo "$out" | sed '$d')"
  snippet="$(printf '%s' "$body" | head -c 120 | tr '\n' ' ')"

  if [[ "$http" == "200" ]] && printf '%s' "$body" | grep -qE '__typename|"data"'; then
    log_line "[$ts] OK http=$http time=${time_total}s body=${snippet}"
  else
    log_line "[$ts] BAD http=$http time=${time_total}s body=${snippet} err=${err_txt}"
  fi
}

echo "Watching: $GRAPHQL_URL"
echo "Interval: ${INTERVAL}s (use --interval to change)"
[[ -n "$LOG_PATH" ]] && echo "Log file: $LOG_PATH (tail -f it in another terminal)"
echo "----"

while true; do
  run_check || true
  if $ONCE; then
    break
  fi
  sleep "$INTERVAL"
done
