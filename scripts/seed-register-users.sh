#!/usr/bin/env bash
# Register seed users via the same GraphQL `register` mutation as the iOS app (AuthService.register).
# Password for every user comes from STAGING_SEED_PASSWORD (never printed).
#
# Env:
#   STAGING_SEED_PASSWORD (required)
#   GRAPHQL_URL (default: https://prelura.voltislabs.uk/graphql/)
#   SEED_USER_COUNT (default: 10, max: 1000)
#   SEED_USERNAME_PREFIX (default: sxu) — usernames are ${prefix}${zero_padded_index} e.g. sxu0000001
#   SEED_EMAIL_DOMAIN (default: seed.voltislabs.local) — must be accepted by your backend
#   SEED_BATCH_ID (default: GITHUB_RUN_ID or unix time) — keeps emails unique per run
#   SEED_OUTPUT_CSV (default: seed-users-report.csv) — username,email,status (no password column)
#
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
SEED_USER_COUNT="${SEED_USER_COUNT:-10}"
SEED_USERNAME_PREFIX="${SEED_USERNAME_PREFIX:-sxu}"
SEED_EMAIL_DOMAIN="${SEED_EMAIL_DOMAIN:-seed.voltislabs.local}"
SEED_BATCH_ID="${SEED_BATCH_ID:-${GITHUB_RUN_ID:-$(date +%s)}}"
SEED_OUTPUT_CSV="${SEED_OUTPUT_CSV:-seed-users-report.csv}"

if [[ -z "${STAGING_SEED_PASSWORD:-}" ]]; then
  echo "Missing STAGING_SEED_PASSWORD."
  exit 1
fi

if ! [[ "$SEED_USER_COUNT" =~ ^[0-9]+$ ]] || [[ "$SEED_USER_COUNT" -lt 1 ]]; then
  echo "SEED_USER_COUNT must be a positive integer."
  exit 1
fi

if [[ "$SEED_USER_COUNT" -gt 1000 ]]; then
  echo "Refusing SEED_USER_COUNT > 1000."
  exit 1
fi

QUERY='mutation Register($email: String!, $firstName: String!, $lastName: String!, $username: String!, $password1: String!, $password2: String!) { register( email: $email firstName: $firstName lastName: $lastName username: $username password1: $password1 password2: $password2 ) { success errors } }'

echo "GraphQL: $GRAPHQL_URL"
echo "Users to create: $SEED_USER_COUNT (prefix=$SEED_USERNAME_PREFIX, batch=$SEED_BATCH_ID)"
echo "Report (no passwords): $SEED_OUTPUT_CSV"
echo "# password for all accounts = value of STAGING_SEED_PASSWORD (set in CI secret; not logged here)" > "$SEED_OUTPUT_CSV"
echo "username,email,status" >> "$SEED_OUTPUT_CSV"

ok=0
fail=0

for ((i = 1; i <= SEED_USER_COUNT; i++)); do
  num=$(printf '%07d' "$i")
  username="${SEED_USERNAME_PREFIX}${num}"
  email="u${num}.${SEED_BATCH_ID}@${SEED_EMAIL_DOMAIN}"

  payload=$(jq -n \
    --arg query "$QUERY" \
    --arg email "$email" \
    --arg firstName "Seed" \
    --arg lastName "User" \
    --arg username "$username" \
    --arg password1 "$STAGING_SEED_PASSWORD" \
    --arg password2 "$STAGING_SEED_PASSWORD" \
    '{query: $query, variables: {
      email: $email,
      firstName: $firstName,
      lastName: $lastName,
      username: $username,
      password1: $password1,
      password2: $password2
    }}')

  resp=$(curl -sS -X POST "$GRAPHQL_URL" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    --data-binary "$payload" || true)

  if echo "$resp" | jq -e '.errors' >/dev/null 2>&1; then
    err=$(echo "$resp" | jq -c '.errors')
    echo "FAIL $username GraphQL top-level: $err"
    echo "$username,$email,graphql_error" >> "$SEED_OUTPUT_CSV"
    fail=$((fail + 1))
    sleep 0.2
    continue
  fi

  success=$(echo "$resp" | jq -r '.data.register.success // empty')
  reg_err=$(echo "$resp" | jq -c '.data.register.errors // null')

  if [[ "$success" == "true" ]]; then
    echo "OK   $username"
    echo "$username,$email,ok" >> "$SEED_OUTPUT_CSV"
    ok=$((ok + 1))
  else
    echo "FAIL $username success=$success errors=$reg_err"
    echo "$username,$email,failed" >> "$SEED_OUTPUT_CSV"
    fail=$((fail + 1))
  fi

  sleep 0.15
done

echo "---"
echo "Done. ok=$ok fail=$fail (password for all is STAGING_SEED_PASSWORD; see CSV for usernames/emails)."
exit $(( fail > 0 ? 1 : 0 ))
