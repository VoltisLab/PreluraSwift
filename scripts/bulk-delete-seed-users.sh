#!/usr/bin/env bash
# Soft-delete (flagUser) every username listed in seed-users-report.csv via staff GraphQL.
# Same auth as scripts/bulk-verify-seed-users-email.sh.
#
# Safety: refuses to run unless CONFIRM_BULK_DELETE=yes (prevents accidental wipes).
#
# Env:
#   CONFIRM_BULK_DELETE=yes   (required)
#   STAFF_AUTH_TOKEN='eyJ...' OR STAFF_USERNAME + STAFF_PASSWORD
#   SEED_CSV (default: repo root seed-users-report.csv)
#   GRAPHQL_URL (default: https://prelura.voltislabs.uk/graphql/)
#   DELETE_LOG (default: bulk-delete-seed-users-log.txt next to CSV)
#   FLAG_REASON (default: OTHER) — TERMS_VIOLATION | SPAM_ACTIVITY | INAPPROPRIATE_CONTENT | HARASSMENT | LEGAL_REQUEST | OTHER
#   FLAG_NOTES (default: Bulk seed reset — scripts/bulk-delete-seed-users.sh)
#
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED_CSV="${SEED_CSV:-$ROOT/seed-users-report.csv}"

if [[ "${CONFIRM_BULK_DELETE:-}" != "yes" ]]; then
  echo "Refusing: bulk delete is destructive. Set CONFIRM_BULK_DELETE=yes to proceed."
  echo "CSV: $SEED_CSV"
  exit 1
fi

if [[ ! -f "$SEED_CSV" ]]; then
  echo "CSV not found: $SEED_CSV"
  exit 1
fi

DELETE_LOG="${DELETE_LOG:-$(dirname "$SEED_CSV")/bulk-delete-seed-users-log.txt}"
FLAG_REASON="${FLAG_REASON:-OTHER}"
FLAG_NOTES="${FLAG_NOTES:-Bulk seed reset — scripts/bulk-delete-seed-users.sh}"

echo "Log: $DELETE_LOG"
echo "bulk-delete started $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DELETE_LOG"
echo "reason=$FLAG_REASON" >> "$DELETE_LOG"

AUTH_HEADER=()

resolve_token() {
  if [[ -n "${STAFF_AUTH_TOKEN:-}" ]]; then
    echo "Using STAFF_AUTH_TOKEN from environment." | tee -a "$DELETE_LOG"
    return 0
  fi
  if [[ -z "${STAFF_USERNAME:-}" || -z "${STAFF_PASSWORD:-}" ]]; then
    echo "Set STAFF_AUTH_TOKEN or STAFF_USERNAME + STAFF_PASSWORD (staff account)." | tee -a "$DELETE_LOG"
    exit 1
  fi
  local payload resp tok
  local LOGIN_Q='mutation Login($username: String!, $password: String!) { login(username: $username, password: $password) { token refreshToken user { id username email } } }'
  payload=$(jq -n \
    --arg q "$LOGIN_Q" \
    --arg u "$STAFF_USERNAME" \
    --arg p "$STAFF_PASSWORD" \
    '{query: $q, variables: {username: $u, password: $p}}')
  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    --data-binary "$payload")
  if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
    echo "Login failed: $(echo "$resp" | jq -c '.errors')" | tee -a "$DELETE_LOG"
    exit 1
  fi
  tok=$(echo "$resp" | jq -r '.data.login.token // empty')
  if [[ -z "$tok" || "$tok" == "null" ]]; then
    echo "Login response missing token: $resp" | tee -a "$DELETE_LOG"
    exit 1
  fi
  STAFF_AUTH_TOKEN="$tok"
  echo "Logged in as staff: $(echo "$resp" | jq -r '.data.login.user.username // empty')" | tee -a "$DELETE_LOG"
}

resolve_token
AUTH_HEADER=( -H "Authorization: Bearer ${STAFF_AUTH_TOKEN}" )

USER_STATS_Q='query UserAdminStats($search: String, $pageCount: Int, $pageNumber: Int) { userAdminStats(search: $search, pageCount: $pageCount, pageNumber: $pageNumber) { id username } }'

FLAG_MUT='mutation FlagUser($id: ID!, $reason: FlagUserReasonEnum!, $notes: String) { flagUser(id: $id, reason: $reason, notes: $notes) { success message } }'

lookup_user_id() {
  local uname="$1"
  local payload resp
  payload=$(jq -n \
    --arg q "$USER_STATS_Q" \
    --arg s "$uname" \
    '{query: $q, variables: {search: $s, pageCount: 30, pageNumber: 1}}')
  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    "${AUTH_HEADER[@]}" \
    --data-binary "$payload")
  echo "$resp" | jq -r --arg u "$uname" '
    def norm: ascii_downcase;
    (.data.userAdminStats // [])[]
    | select((.username // "" | norm) == ($u | norm))
    | .id
    ' | head -1
}

flag_user_id() {
  local uid="$1"
  local uname="$2"
  local payload resp ok msg
  payload=$(jq -n \
    --arg q "$FLAG_MUT" \
    --arg id "$uid" \
    --arg reason "$FLAG_REASON" \
    --arg notes "$FLAG_NOTES" \
    '{query: $q, variables: {id: $id, reason: $reason, notes: $notes}}')
  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    "${AUTH_HEADER[@]}" \
    --data-binary "$payload")
  if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
    echo "FAIL $uname GraphQL: $(echo "$resp" | jq -c '.errors')" | tee -a "$DELETE_LOG"
    return 1
  fi
  ok=$(echo "$resp" | jq -r '.data.flagUser.success // false')
  msg=$(echo "$resp" | jq -r '.data.flagUser.message // empty')
  if [[ "$ok" == "true" ]]; then
    echo "OK   $uname (id=$uid)" | tee -a "$DELETE_LOG"
    return 0
  fi
  echo "FAIL $uname success=$ok msg=$msg" | tee -a "$DELETE_LOG"
  return 1
}

ok=0
fail=0

while IFS= read -r uname; do
  [[ -z "$uname" ]] && continue

  uid_raw=$(lookup_user_id "$uname")
  if [[ -z "$uid_raw" || "$uid_raw" == "null" ]]; then
    echo "SKIP $uname (user not found in admin search)" | tee -a "$DELETE_LOG"
    fail=$((fail + 1))
    sleep 0.1
    continue
  fi
  uid=$(printf '%.0f' "$uid_raw" 2>/dev/null || echo "$uid_raw")

  if flag_user_id "$uid" "$uname"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
  sleep 0.12
done < <(awk -F',' 'NR>2 && $1!="" && $1 !~ /^#/ {print $1}' "$SEED_CSV")

echo "---" | tee -a "$DELETE_LOG"
echo "Done. deleted_ok=$ok failed_or_skip=$fail" | tee -a "$DELETE_LOG"
exit $(( fail > 0 ? 1 : 0 ))
