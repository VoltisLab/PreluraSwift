#!/usr/bin/env bash
# After seed + optional verify: prove GraphQL login works with STAGING_SEED_PASSWORD
# for the first N usernames in seed-users-report.csv (same behaviour as app + test-seed-login.sh).
#
# Usage: bash scripts/gha-smoke-test-seed-logins.sh <N>
# Env: STAGING_SEED_PASSWORD, GRAPHQL_URL (optional)
#
set -euo pipefail
N="${1:-}"
CSV="${SEED_CSV:-seed-users-report.csv}"
GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
SEED_EMAIL_DOMAIN="${SEED_EMAIL_DOMAIN:-mywearhouse.co.uk}"

if [[ -z "${STAGING_SEED_PASSWORD:-}" ]]; then
  echo "Missing STAGING_SEED_PASSWORD"
  exit 1
fi
if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]]; then
  echo "Usage: $0 <positive N>"
  exit 1
fi
if [[ ! -f "$CSV" ]]; then
  echo "CSV not found: $CSV"
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
    echo "FAIL login as $ident: $(echo "$resp" | jq -c '.errors')"
    return 1
  fi
  tok=$(echo "$resp" | jq -r '.data.login.token // empty')
  if [[ -z "$tok" || "$tok" == "null" ]]; then
    echo "FAIL login as $ident: unexpected $(echo "$resp" | jq -c .)"
    return 1
  fi
  echo "OK   login as $ident (user=$(echo "$resp" | jq -r '.data.login.user.username // empty'))"
  return 0
}

try_user() {
  local u="$1"
  if try_login "$u"; then return 0; fi
  if [[ "$u" != *"@"* ]]; then
    echo "--- retry as ${u}@${SEED_EMAIL_DOMAIN} ---"
    try_login "${u}@${SEED_EMAIL_DOMAIN}" && return 0
  fi
  return 1
}

failed=0
count=0
while IFS= read -r u; do
  [[ -z "$u" ]] && continue
  count=$((count + 1))
  if ! try_user "$u"; then
    failed=$((failed + 1))
  fi
  [[ "$count" -ge "$N" ]] && break
done < <(awk -F',' 'NR>2 && $1!="" && $1 !~ /^#/ {print $1}' "$CSV")

if [[ "$count" -lt 1 ]]; then
  echo "No usernames found in $CSV"
  exit 1
fi

echo "Smoke test: $count login(s) against $GRAPHQL_URL"
if [[ "$failed" -gt 0 ]]; then
  echo "Smoke test FAILED ($failed of $count)"
  exit 1
fi
echo "Smoke test PASSED ($count accounts)"
