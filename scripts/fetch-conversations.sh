#!/usr/bin/env bash
# Fetch conversations and optionally conversation_by_id from the backend to verify
# whether order is returned (for sale confirmation banner). Use this to check A–E.
#
# Usage:
#   AUTH_TOKEN="<jwt>" ./scripts/fetch-conversations.sh
#   AUTH_TOKEN="<jwt>" ./scripts/fetch-conversations.sh <conversation_id>
#
# Get token from simulator: see scripts/fetch-orders.sh

set -e
SCRIPT_DIR="$(dirname "$0")"
URL="${PRELURA_GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"

if [ -n "$AUTH_TOKEN" ]; then
  TOKEN="$AUTH_TOKEN"
elif [ -f "$SCRIPT_DIR/auth-token" ]; then
  TOKEN=$(cat "$SCRIPT_DIR/auth-token" | tr -d '\n\r')
else
  echo "Error: Set AUTH_TOKEN or create scripts/auth-token"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required. brew install jq"
  exit 1
fi

CONV_QUERY='query Conversations { conversations { id recipient { username } lastMessage { text createdAt } order { id status priceTotal products { id name imagesUrl } } } }'
CONV_BODY=$(jq -n --arg q "$CONV_QUERY" '{query: $q, operationName: "Conversations"}')

echo "=== 1. Conversations (raw): do any have 'order'? ==="
CONV_RESP=$(curl -s -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$CONV_BODY")

if echo "$CONV_RESP" | jq -e '.errors' >/dev/null 2>&1; then
  echo "GraphQL errors:"
  echo "$CONV_RESP" | jq '.errors'
  exit 1
fi

# Count how many conversations have non-null order
WITH_ORDER=$(echo "$CONV_RESP" | jq '[.data.conversations[]? | select(.order != null)] | length')
TOTAL=$(echo "$CONV_RESP" | jq '.data.conversations | length')
echo "Conversations total: $TOTAL"
echo "Conversations with order != null: $WITH_ORDER"

if [ "$WITH_ORDER" -gt 0 ]; then
  echo ""
  echo "First conversation that has order (shape):"
  echo "$CONV_RESP" | jq '.data.conversations[] | select(.order != null) | {id, recipient: .recipient.username, order}' | head -40
fi

echo ""
echo "First conversation (full order key - check key names: priceTotal vs price_total):"
echo "$CONV_RESP" | jq '.data.conversations[0] | {id, order}' 2>/dev/null || true

# If conversation id provided, fetch conversation_by_id
CONV_ID="${1:-}"
if [ -n "$CONV_ID" ]; then
  echo ""
  echo "=== 2. conversation_by_id(id: $CONV_ID) ==="
  BY_ID_QUERY='query ConversationById($id: ID!) { conversationById(id: $id) { id recipient { username } order { id status priceTotal products { id name imagesUrl } } } }'
  BY_ID_BODY=$(jq -n --arg q "$BY_ID_QUERY" --arg id "$CONV_ID" '{query: $q, operationName: "ConversationById", variables: {id: $id}}')
  BY_ID_RESP=$(curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$BY_ID_BODY")
  if echo "$BY_ID_RESP" | jq -e '.errors' >/dev/null 2>&1; then
    echo "GraphQL errors:"
    echo "$BY_ID_RESP" | jq '.errors'
  else
    echo "$BY_ID_RESP" | jq '.data.conversationById // .data.conversation_by_id'
  fi
else
  FIRST_ID=$(echo "$CONV_RESP" | jq -r '.data.conversations[0].id // empty')
  if [ -n "$FIRST_ID" ]; then
    echo ""
    echo "=== 2. conversationById(id: $FIRST_ID) - first conv ==="
    BY_ID_QUERY='query ConversationById($id: ID!) { conversationById(id: $id) { id recipient { username } order { id status priceTotal products { id name imagesUrl } } } }'
    BY_ID_BODY=$(jq -n --arg q "$BY_ID_QUERY" --arg id "$FIRST_ID" '{query: $q, operationName: "ConversationById", variables: {id: $id}}')
    BY_ID_RESP=$(curl -s -X POST "$URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "$BY_ID_BODY")
    if echo "$BY_ID_RESP" | jq -e '.errors' >/dev/null 2>&1; then
      echo "GraphQL errors:"
      echo "$BY_ID_RESP" | jq '.errors'
    else
      echo "$BY_ID_RESP" | jq '.data.conversationById // .data.conversation_by_id'
    fi
  fi
fi

echo ""
echo "=== Summary for A–E ==="
echo "A (timing): If with_order > 0, backend is returning order for some convs."
echo "B (wrong conv): Compare conversation ids: the one you open after payment vs one that has order."
echo "C (backend never returns order): If with_order = 0 and you have orders, backend may not be linking or exposing order."
echo "D (decoding): Check key names above - Swift expects camelCase (priceTotal); if backend sends price_total, decoder uses convertFromSnakeCase so it should match."
echo "E (API failure): If errors above, API or auth failed."
