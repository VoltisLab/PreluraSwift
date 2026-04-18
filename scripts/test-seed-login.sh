#!/usr/bin/env bash
# Prove whether GraphQL accepts a username + password (same mutation as the app).
# Does not print the password.
#
#   export STAGING_SEED_PASSWORD='…'   # exact value from GitHub secret used when seeding
#   bash scripts/test-seed-login.sh emartin
#
set -euo pipefail
GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
USER="${1:-}"
if [[ -z "${STAGING_SEED_PASSWORD:-}" || -z "$USER" ]]; then
  echo "Usage: STAGING_SEED_PASSWORD='…' $0 <username>"
  echo "Example: STAGING_SEED_PASSWORD=\"\$STAGING_SEED_PASSWORD\" $0 emartin"
  exit 1
fi

LOGIN_Q='mutation Login($username: String!, $password: String!) { login(username: $username, password: $password) { token refreshToken user { id username email } } }'
payload=$(jq -n \
  --arg q "$LOGIN_Q" \
  --arg u "$USER" \
  --arg p "$STAGING_SEED_PASSWORD" \
  '{query: $q, variables: {username: $u, password: $p}}')

resp=$(curl -sS -X POST "$GRAPHQL_URL" \
  -H 'Content-Type: application/json' \
  --data-binary "$payload")

if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
  echo "FAIL: $(echo "$resp" | jq -c '.errors')"
  exit 1
fi

tok=$(echo "$resp" | jq -r '.data.login.token // empty')
if [[ -z "$tok" || "$tok" == "null" ]]; then
  echo "FAIL: unexpected response"
  echo "$resp" | jq .
  exit 1
fi

echo "OK: login succeeded for username=$USER (token length=${#tok})"
echo "    user: $(echo "$resp" | jq -c '.data.login.user')"
