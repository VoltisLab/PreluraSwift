#!/usr/bin/env bash
# Prove whether GraphQL accepts login (same mutation as the app).
# Tries handle first, then username@mywearhouse.co.uk (same as seed script emails).
# Does not print the password.
#
#   export STAGING_SEED_PASSWORD='…'
#   bash scripts/test-seed-login.sh emartin
#
set -euo pipefail
GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
SEED_EMAIL_DOMAIN="${SEED_EMAIL_DOMAIN:-mywearhouse.co.uk}"
USER="${1:-}"
if [[ -z "${STAGING_SEED_PASSWORD:-}" || -z "$USER" ]]; then
  echo "Usage: STAGING_SEED_PASSWORD='…' $0 <username_or_email>"
  exit 1
fi

LOGIN_Q='mutation Login($username: String!, $password: String!) { login(username: $username, password: $password) { token refreshToken user { id username email } } }'

try_login() {
  local ident="$1"
  local payload resp tok
  payload=$(jq -n \
    --arg q "$LOGIN_Q" \
    --arg u "$ident" \
    --arg p "$STAGING_SEED_PASSWORD" \
    '{query: $q, variables: {username: $u, password: $p}}')
  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    --data-binary "$payload")
  if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
    echo "$resp" | jq -c '.errors'
    return 1
  fi
  tok=$(echo "$resp" | jq -r '.data.login.token // empty')
  if [[ -z "$tok" || "$tok" == "null" ]]; then
    echo "unexpected: $(echo "$resp" | jq -c .)"
    return 1
  fi
  echo "OK: login succeeded for identifier=$ident (token length=${#tok})"
  echo "    user: $(echo "$resp" | jq -c '.data.login.user')"
  return 0
}

if try_login "$USER"; then
  exit 0
fi

if [[ "$USER" != *"@"* ]]; then
  echo "--- retry with email form @${SEED_EMAIL_DOMAIN} ---"
  if try_login "${USER}@${SEED_EMAIL_DOMAIN}"; then
    exit 0
  fi
fi

echo "FAIL: both attempts failed (wrong password, wrong user, or different GRAPHQL_URL)."
exit 1
