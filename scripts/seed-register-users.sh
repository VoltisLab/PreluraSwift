#!/usr/bin/env bash
# Register seed users via GraphQL `register` (same as iOS AuthService.register).
# Usernames look human: jfoster, janefoster, jfoster43, mbt395, mark.james, m.james (rotating patterns).
# Password: STAGING_SEED_PASSWORD only (never printed).
#
# Env:
#   STAGING_SEED_PASSWORD (required)
#   GRAPHQL_URL (default: https://prelura.voltislabs.uk/graphql/)
#   SEED_USER_COUNT (default: 10, max: 1000)
#   SEED_EMAIL_DOMAIN (default: wearhouse.co.uk) — email is always ${username}@${SEED_EMAIL_DOMAIN}
#     (override if your mail uses another spelling, e.g. warehouse.co.uk)
#   SEED_BATCH_ID (unused for email; usernames stay unique per run)
#   SEED_OUTPUT_CSV (default: seed-users-report.csv)
#   SEED_LEGACY_NUMERIC_USERNAMES=1 — if set, use old sxu0000001 style instead
#
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
SEED_USER_COUNT="${SEED_USER_COUNT:-10}"
SEED_EMAIL_DOMAIN="${SEED_EMAIL_DOMAIN:-wearhouse.co.uk}"
SEED_BATCH_ID="${SEED_BATCH_ID:-${GITHUB_RUN_ID:-$(date +%s)}}"
SEED_OUTPUT_CSV="${SEED_OUTPUT_CSV:-seed-users-report.csv}"
SEED_USERNAME_PREFIX="${SEED_USERNAME_PREFIX:-sxu}"

# Lowercase a-z strings (names are ASCII in arrays below).
FIRSTS=(
  jane mark sarah james michael emma olivia liam noah oliver sophia isabella
  charlotte amelia mia harper evelyn luna camila aria elizabeth henry lucas
  ethan daniel jack logan alexander owen sebastian jackson aiden samuel david
  matthew joseph john robert thomas chris ryan kevin brian george edward
  laura rachel nicole stephanie jennifer ashley amanda melissa deborah
)

LASTS=(
  foster james smith johnson williams brown jones garcia miller davis rodriguez
  martinez wilson anderson taylor moore martin lee thompson white harris sanchez
  clark ramirez lewis robinson walker young king wright scott nguyen hill flores
  green adams nelson baker hall rivera campbell mitchell carter roberts phillips
  evans turner diaz parker collins edwards stewart morris murphy cook bailey
  cooper richardson cox howard peterson gray jameson west jordan owens powell
  patterson hughes washington butler simmons bennett wood barnes ross perry
  grant brooks kelly sanders long ward bell murphy reed watson brooks harrison
)

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

lc() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

cap_word() {
  local w="$1"
  echo "$(lc "$w" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
}

# Patterns (examples): jfoster | janefoster | jfoster43 | mbt395 | mark.james | m.james
human_username_for_index() {
  local i="$1"
  local nf=${#FIRSTS[@]}
  local nl=${#LASTS[@]}
  local fi li f l u pat digits
  fi=$(( (i * 17 + 3) % nf ))
  li=$(( (i * 11 + 5) % nl ))
  f="${FIRSTS[$fi]}"
  l="${LASTS[$li]}"
  f_lc=$(lc "$f")
  l_lc=$(lc "$l")

  pat=$(( (i - 1) % 6 ))
  case $pat in
    0) u="${f_lc:0:1}${l_lc}" ;;                         # jfoster
    1) u="${f_lc}${l_lc}" ;;                             # janefoster
    2)
      digits=$(( 10 + (i * 23) % 90 ))                 # 10–99
      u="${f_lc:0:1}${l_lc}${digits}"                    # jfoster43
      ;;
    3)
      digits=$(( 100 + (i * 37) % 900 ))                 # 100–999
      # three letters (initials-style) + 3 digits e.g. mbt395
      u="${f_lc:0:1}${f_lc:1:1}${l_lc:0:1}${digits}"
      ;;
    4) u="${f_lc}.${l_lc}" ;;                            # mark.james
    5) u="${f_lc:0:1}.${l_lc}" ;;                        # m.james
  esac
  echo "$u"
}

# Portable across macOS bash 3.2 (no associative arrays): track used names in a temp file.
TAKEN_NAMES_FILE=""
init_taken_names() {
  TAKEN_NAMES_FILE=$(mktemp "${TMPDIR:-/tmp}/seed-usernames.XXXXXX")
}
release_taken_names() {
  [[ -n "${TAKEN_NAMES_FILE:-}" && -f "$TAKEN_NAMES_FILE" ]] && rm -f "$TAKEN_NAMES_FILE"
}

ensure_unique_username() {
  local base="$1"
  local u="$base"
  local n=0
  while grep -Fxq "$u" "$TAKEN_NAMES_FILE" 2>/dev/null; do
    n=$((n + 1))
    u="${base}${n}"
  done
  echo "$u" >> "$TAKEN_NAMES_FILE"
  echo "$u"
}

legacy_username_for_index() {
  local i="$1"
  local num
  num=$(printf '%07d' "$i")
  echo "${SEED_USERNAME_PREFIX}${num}"
}

echo "GraphQL: $GRAPHQL_URL"
if [[ "${SEED_LEGACY_NUMERIC_USERNAMES:-}" == "1" ]]; then
  echo "Usernames: legacy ${SEED_USERNAME_PREFIX}#######"
else
  echo "Usernames: human-style (jfoster, janefoster, … mark.james, …) with uniqueness suffix if needed"
fi
echo "Users to create: $SEED_USER_COUNT (batch=$SEED_BATCH_ID); emails: <username>@${SEED_EMAIL_DOMAIN}"
echo "Report (no passwords): $SEED_OUTPUT_CSV"
echo "# password for all accounts = STAGING_SEED_PASSWORD (CI secret; not in this file)" > "$SEED_OUTPUT_CSV"
echo "username,email,status" >> "$SEED_OUTPUT_CSV"

init_taken_names
trap 'release_taken_names' EXIT

ok=0
fail=0

for ((i = 1; i <= SEED_USER_COUNT; i++)); do
  if [[ "${SEED_LEGACY_NUMERIC_USERNAMES:-}" == "1" ]]; then
    username=$(legacy_username_for_index "$i")
    firstName="Seed"
    lastName="User"
  else
    base=$(human_username_for_index "$i")
    username=$(ensure_unique_username "$base")
    nf=${#FIRSTS[@]}
    nl=${#LASTS[@]}
    fi=$(( (i * 17 + 3) % nf ))
    li=$(( (i * 11 + 5) % nl ))
    f="${FIRSTS[$fi]}"
    l="${LASTS[$li]}"
    firstName=$(cap_word "$f")
    lastName=$(cap_word "$l")
  fi

  # Same handle as local part so email matches the login identity (e.g. jfoster@ / mark.james@).
  email="${username}@${SEED_EMAIL_DOMAIN}"

  payload=$(jq -n \
    --arg query "$QUERY" \
    --arg email "$email" \
    --arg firstName "$firstName" \
    --arg lastName "$lastName" \
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
