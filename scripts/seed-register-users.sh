#!/usr/bin/env bash
# Register seed users via GraphQL `register` (same as iOS AuthService.register).
# Usernames look human: jfoster, janefoster, jfoster43, mbt395, mark.james, m.james (rotating patterns).
# Password: STAGING_SEED_PASSWORD only (never printed).
#
# Env:
#   STAGING_SEED_PASSWORD (required)
#   GRAPHQL_URL (default: https://prelura.voltislabs.uk/graphql/)
#   SEED_USER_COUNT — how many users to create this run (default: 10, max: 1000 per run)
#   SEED_START_INDEX — loop index for name generation (default: 1). Use 51 after a batch of 50 to avoid duplicate handles.
#   SEED_APPEND_CSV=1 — append to SEED_OUTPUT_CSV and preload existing usernames so suffixes don’t collide.
#   SEED_EMAIL_DOMAIN (default: wearhouse.co.uk) — email is always ${username}@${SEED_EMAIL_DOMAIN}
#   SEED_BATCH_ID (logged only)
#   SEED_OUTPUT_CSV (default: seed-users-report.csv) — full audit trail: username,email,status
#   SEED_LEGACY_NUMERIC_USERNAMES=1 — if set, use old sxu0000001 style instead
#
set -euo pipefail

GRAPHQL_URL="${GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"
SEED_USER_COUNT="${SEED_USER_COUNT:-10}"
SEED_START_INDEX="${SEED_START_INDEX:-1}"
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

# Casual / short first names (nickname-style handles)
NICKS=(
  mike dave chris kate ben sam alex jamie tom liz matt joe meg dan rob jen amy
  nick josh leo zoe max eva ian sue tim ray kim jay val rex
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

if ! [[ "$SEED_START_INDEX" =~ ^[0-9]+$ ]] || [[ "$SEED_START_INDEX" -lt 1 ]]; then
  echo "SEED_START_INDEX must be a positive integer."
  exit 1
fi

SEED_END_INDEX=$((SEED_START_INDEX + SEED_USER_COUNT - 1))
if [[ "$SEED_END_INDEX" -gt 100000 ]]; then
  echo "Refusing SEED_START_INDEX + SEED_USER_COUNT beyond 100000."
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

# ~50 deterministic “styles” (pid 0–49) + ~5% extra-long believable handles.
# Sets SEED_USERNAME_BASE, SEED_FI, SEED_LI (primary names for register(); must not run in a subshell).
compute_seed_username_and_name_indices() {
  local i="$1"
  local nf=${#FIRSTS[@]}
  local nl=${#LASTS[@]}
  local nn=${#NICKS[@]}
  local fi li fi2 li2 ni f l f2 l2 n_lc f_lc l_lc f2_lc l2_lc u pid d d2 d3 d4 yr
  pid=$(( (i * 50331653 + i / 3 + i % 7) % 50 ))

  fi=$(( (i * 17 + pid + 3) % nf ))
  li=$(( (i * 11 + pid * 2 + 5) % nl ))
  fi2=$(( (i * 19 + pid * 3 + 7) % nf ))
  li2=$(( (i * 23 + pid + 11) % nl ))
  ni=$(( (i * 29 + pid) % nn ))

  f="${FIRSTS[$fi]}"
  l="${LASTS[$li]}"
  f2="${FIRSTS[$fi2]}"
  l2="${LASTS[$li2]}"
  n_lc=$(lc "${NICKS[$ni]}")

  f_lc=$(lc "$f")
  l_lc=$(lc "$l")
  f2_lc=$(lc "$f2")
  l2_lc=$(lc "$l2")

  d=$(( 10 + (i * 23 + pid) % 90 ))
  d2=$(( 100 + (i * 37 + pid) % 900 ))
  d3=$(( 1000 + (i * 41 + pid) % 9000 ))
  d4=$(( 10000 + (i * 43 + pid) % 90000 ))
  yr=$(( 1975 + (i * 17 + pid) % 35 ))

  case $pid in
    0) u="${f_lc:0:1}${l_lc}" ;;
    1) u="${f_lc}${l_lc}" ;;
    2) u="${f_lc:0:1}${l_lc}${d}" ;;
    3) u="${f_lc:0:1}${f_lc:1:1}${l_lc:0:1}${d2}" ;;
    4) u="${f_lc}.${l_lc}" ;;
    5) u="${f_lc:0:1}.${l_lc}" ;;
    6) u="${l_lc:0:1}${f_lc}" ;;
    7) u="${l_lc}${f_lc:0:1}" ;;
    8) u="${f_lc}_${l_lc}" ;;
    9) u="${l_lc}_${f_lc:0:1}" ;;
    10) u="${f_lc}-${l_lc}" ;;
    11) u="${n_lc}${l_lc}" ;;
    12) u="${n_lc}.${l_lc:0:1}" ;;
    13) u="${f_lc:0:2}${l_lc}" ;;
    14) u="${f_lc}${l_lc:0:3}" ;;
    15) u="${l_lc:0:4}${f_lc:0:1}" ;;
    16) u="${f_lc:0:1}x${l_lc}" ;;
    17) u="${f_lc}xo${l_lc:0:1}" ;;
    18) u="${f_lc}${l_lc}${d}" ;;
    19) u="${f_lc:0:1}${l_lc}${d2}" ;;
    20) u="${f_lc}.${l_lc:0:1}${l_lc:1:1}" ;;
    21) u="${f_lc:0:1}.${l_lc:0:3}" ;;
    22) u="${l_lc}.${f_lc:0:1}" ;;
    23) u="${l2_lc:0:1}${f_lc}" ;;
    24) u="${f_lc}${l2_lc:0:1}${l_lc:0:1}" ;;
    25) u="${f_lc:0:1}${l2_lc:0:1}${d}" ;;
    26) u="${f_lc}${l_lc}${yr}" ;;
    27) u="${f_lc:0:1}${l_lc}${yr}" ;;
    28) u="${n_lc}${d}" ;;
    29) u="${n_lc}_${l_lc:0:4}" ;;
    30) u="${f_lc}the${l_lc:0:1}" ;;
    31) u="${f_lc}and${l2_lc:0:3}" ;;
    32) u="${f_lc}${l_lc}x${d}" ;;
    33) u="${f_lc}.${l_lc}.${d}" ;;
    34) u="${f_lc:0:1}${l_lc:0:1}${l_lc:2:1}${d2}" ;;
    35) u="${l_lc}${d3}" ;;
    36) u="${f_lc:0:1}${l_lc}${d3}" ;;
    37) u="${f_lc}${l2_lc:0:2}${d}" ;;
    38) u="${f2_lc:0:1}${l_lc}${d}" ;;
    39) u="${f_lc}${l2_lc}" ;;
    40) u="${f2_lc}${l_lc:0:1}${d}" ;;
    41) u="${f_lc:0:1}.${l2_lc}" ;;
    42) u="${l_lc:0:2}.${f_lc}" ;;
    43) u="${f_lc}${l_lc}uk" ;;
    44) u="${f_lc}ie${l_lc:0:2}" ;;
    45) u="${f_lc}${l_lc}hq" ;;
    46) u="${n_lc}${l_lc}${d}" ;;
    47) u="${f_lc}_${l_lc}_${d}" ;;
    48) u="${f_lc}.${l2_lc}.${d}" ;;
    49) u="${f_lc:0:1}${l_lc}${f2_lc:0:1}${d2}" ;;
  esac

  # ~5%: stretch into a longer, still-plausible handle (extra digits / compound).
  if (( (i * 374761393) % 100 < 5 )); then
    case $(( (i * 13) % 5 )) in
      0) u="${f_lc}${l_lc}${d4}" ;;
      1) u="${f_lc}_${l_lc}_$(( (i * 31) % 90 + 10 ))" ;;
      2) u="${n_lc}.${l_lc}.${yr}" ;;
      3) u="${f_lc}${l2_lc}${d3}" ;;
      4) u="${f_lc:0:1}${l_lc:0:1}${l2_lc}${d2}" ;;
    esac
  fi

  SEED_USERNAME_BASE="$u"
  SEED_FI=$fi
  SEED_LI=$li
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
  echo "Usernames: ~50 mixed styles + ~5% longer handles; uniqueness suffix if needed"
fi
echo "Users to create: $SEED_USER_COUNT (indices $SEED_START_INDEX..$SEED_END_INDEX, batch=$SEED_BATCH_ID); emails: <username>@${SEED_EMAIL_DOMAIN}"
echo "Report (no passwords): $SEED_OUTPUT_CSV"

if [[ "${SEED_APPEND_CSV:-}" == "1" ]] && [[ -f "$SEED_OUTPUT_CSV" ]]; then
  echo "Appending to existing $SEED_OUTPUT_CSV"
elif [[ "${SEED_APPEND_CSV:-}" != "1" ]] || [[ ! -f "$SEED_OUTPUT_CSV" ]]; then
  echo "# password for all accounts = STAGING_SEED_PASSWORD (CI secret; not in this file)" > "$SEED_OUTPUT_CSV"
  echo "username,email,status" >> "$SEED_OUTPUT_CSV"
fi

init_taken_names
trap 'release_taken_names' EXIT

# Preload usernames from existing CSV so ensure_unique_username won’t reuse a handle from a prior run.
if [[ "${SEED_APPEND_CSV:-}" == "1" ]] && [[ -f "$SEED_OUTPUT_CSV" ]]; then
  awk -F',' 'NR > 2 && $1 != "" && $1 !~ /^#/ { print $1 }' "$SEED_OUTPUT_CSV" >> "$TAKEN_NAMES_FILE" 2>/dev/null || true
fi

ok=0
fail=0

for ((i = SEED_START_INDEX; i <= SEED_END_INDEX; i++)); do
  if [[ "${SEED_LEGACY_NUMERIC_USERNAMES:-}" == "1" ]]; then
    username=$(legacy_username_for_index "$i")
    firstName="Seed"
    lastName="User"
  else
    compute_seed_username_and_name_indices "$i"
    username=$(ensure_unique_username "$SEED_USERNAME_BASE")
    f="${FIRSTS[$SEED_FI]}"
    l="${LASTS[$SEED_LI]}"
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
