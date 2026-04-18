#!/usr/bin/env bash
# Mark seed users as email-verified via staff GraphQL (same as Staff “Mark email verified”).
#
# Requires staff access. Either:
#   export STAFF_AUTH_TOKEN='eyJ...'   # JWT from a logged-in staff session, or
#   export STAFF_USERNAME='yourstaff' STAFF_PASSWORD='...'   # staff account (login mutation)
#
# Optional:
#   SEED_CSV (default: seed-users-report.csv next to repo / cwd)
#   GRAPHQL_URL (default: https://prelura.voltislabs.uk/graphql/)
#   VERIFY_LOG (default: bulk-verify-email-log.txt in same dir as CSV)
#
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED_CSV="${SEED_CSV:-$ROOT/seed-users-report.csv}"

if [[ ! -f "$SEED_CSV" ]]; then
  echo "CSV not found: $SEED_CSV"
  exit 1
fi

VERIFY_LOG="${VERIFY_LOG:-$(dirname "$SEED_CSV")/bulk-verify-email-log.txt}"
echo "Log: $VERIFY_LOG"
echo "bulk-verify started $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$VERIFY_LOG"

AUTH_HEADER=()

resolve_token() {
  if [[ -n "${STAFF_AUTH_TOKEN:-}" ]]; then
    echo "Using STAFF_AUTH_TOKEN from environment." | tee -a "$VERIFY_LOG"
    return 0
  fi
  if [[ -z "${STAFF_USERNAME:-}" || -z "${STAFF_PASSWORD:-}" ]]; then
    echo "Set STAFF_AUTH_TOKEN or STAFF_USERNAME + STAFF_PASSWORD (staff account)." | tee -a "$VERIFY_LOG"
    exit 1
  fi
  local payload resp tok
  # Must match AuthService.login (one closing brace per nesting level; no extra `}`).
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
    echo "Login failed: $(echo "$resp" | jq -c '.errors')" | tee -a "$VERIFY_LOG"
    exit 1
  fi
  tok=$(echo "$resp" | jq -r '.data.login.token // empty')
  if [[ -z "$tok" || "$tok" == "null" ]]; then
    echo "Login response missing token: $resp" | tee -a "$VERIFY_LOG"
    exit 1
  fi
  STAFF_AUTH_TOKEN="$tok"
  echo "Logged in as staff: $(echo "$resp" | jq -r '.data.login.user.username // empty')" | tee -a "$VERIFY_LOG"
}

resolve_token
AUTH_HEADER=( -H "Authorization: Bearer ${STAFF_AUTH_TOKEN}" )

USER_STATS_Q='query UserAdminStats($search: String, $pageCount: Int, $pageNumber: Int) { userAdminStats(search: $search, pageCount: $pageCount, pageNumber: $pageNumber) { id username } }'

VERIFY_MUT='mutation AdminSetUserEmailVerified($userId: Int!, $emailVerified: Boolean!) { adminSetUserEmailVerified(userId: $userId, emailVerified: $emailVerified) { success message } }'

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

verify_user_id() {
  local uid="$1"
  local uname="$2"
  local payload resp ok msg
  payload=$(jq -n \
    --arg q "$VERIFY_MUT" \
    --argjson uid "$uid" \
    '{query: $q, variables: {userId: $uid, emailVerified: true}}')
  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    "${AUTH_HEADER[@]}" \
    --data-binary "$payload")
  ok=$(echo "$resp" | jq -r '.data.adminSetUserEmailVerified.success // false')
  msg=$(echo "$resp" | jq -r '.data.adminSetUserEmailVerified.message // empty')
  if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
    echo "FAIL $uname GraphQL: $(echo "$resp" | jq -c '.errors')" | tee -a "$VERIFY_LOG"
    return 1
  fi
  if [[ "$ok" == "true" ]]; then
    echo "OK   $uname (id=$uid)" | tee -a "$VERIFY_LOG"
    return 0
  fi
  echo "FAIL $uname success=$ok msg=$msg" | tee -a "$VERIFY_LOG"
  return 1
}

ok=0
fail=0

while IFS= read -r uname; do
  [[ -z "$uname" ]] && continue

  uid_raw=$(lookup_user_id "$uname")
  if [[ -z "$uid_raw" || "$uid_raw" == "null" ]]; then
    echo "SKIP $uname (user not found in admin search)" | tee -a "$VERIFY_LOG"
    fail=$((fail + 1))
    sleep 0.1
    continue
  fi
  # id may be float from jq for large ints — coerce to int string
  uid=$(printf '%.0f' "$uid_raw" 2>/dev/null || echo "$uid_raw")

  if verify_user_id "$uid" "$uname"; then
    ok=$((ok + 1))
  else
    fail=$((fail + 1))
  fi
  sleep 0.12
done < <(awk -F',' 'NR>2 && $1!="" && $1 !~ /^#/ {print $1}' "$SEED_CSV")

echo "---" | tee -a "$VERIFY_LOG"
echo "Done. verified_ok=$ok failed_or_skip=$fail" | tee -a "$VERIFY_LOG"
exit $(( fail > 0 ? 1 : 0 ))
