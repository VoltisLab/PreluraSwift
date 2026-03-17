#!/usr/bin/env bash
# Fetch all orders from the Prelura backend (bought + sold) to verify orders exist.
# Usage:
#   AUTH_TOKEN="your-jwt-token" ./scripts/fetch-orders.sh
#   # or put token in a file (do not commit):
#   echo "your-jwt-token" > scripts/auth-token && chmod 600 scripts/auth-token
#   ./scripts/fetch-orders.sh
#
# To get your token from the iOS simulator (after logging in), run this then paste into auth-token:
#   plist=$(find ~/Library/Developer/CoreSimulator/Devices -name "com.prelura.preloved.plist" -path "*Library/Preferences*" 2>/dev/null | head -1)
#   [ -n "$plist" ] && /usr/libexec/PlistBuddy -c "Print :AUTH_TOKEN" "$plist" 2>/dev/null

set -e
SCRIPT_DIR="$(dirname "$0")"
URL="${PRELURA_GRAPHQL_URL:-https://prelura.voltislabs.uk/graphql/}"

if [ -n "$AUTH_TOKEN" ]; then
  TOKEN="$AUTH_TOKEN"
elif [ -f "$SCRIPT_DIR/auth-token" ]; then
  TOKEN=$(cat "$SCRIPT_DIR/auth-token" | tr -d '\n\r')
else
  echo "Error: No auth token. Set AUTH_TOKEN or create scripts/auth-token with your JWT."
  echo "Example: AUTH_TOKEN=\$(pbpaste) ./scripts/fetch-orders.sh"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

QUERY='query UserOrders($filters: OrderFiltersInput, $pageCount: Int, $pageNumber: Int) {
  userOrders(filters: $filters, pageCount: $pageCount, pageNumber: $pageNumber) {
    id
    priceTotal
    status
    createdAt
    user { id username displayName }
    products { id name }
  }
  userOrdersTotalNumber
}'

run_query() {
  local is_seller=$1
  jq -n --arg q "$QUERY" --arg is_seller "$is_seller" \
    '{query: $q, operationName: "UserOrders", variables: {filters: {isSeller: ($is_seller == "true")}, pageCount: 100, pageNumber: 1}}' | \
  curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d @-
}

echo "=== Orders (BOUGHT – as buyer) ==="
BOUGHT=$(run_query "false")

if echo "$BOUGHT" | jq -e '.errors' >/dev/null 2>&1; then
    echo "GraphQL errors:"
    echo "$BOUGHT" | jq '.errors'
    exit 1
fi
# Backend may return camelCase (userOrders) or snake_case (user_orders)
BOUGHT_COUNT=$(echo "$BOUGHT" | jq -r '.data.userOrdersTotalNumber // .data.user_orders_total_number // 0')
BOUGHT_LIST=$(echo "$BOUGHT" | jq -r '.data.userOrders // .data.user_orders // []')
echo "Total count: $BOUGHT_COUNT"
echo "Returned: $(echo "$BOUGHT_LIST" | jq 'length')"
if [ "$(echo "$BOUGHT_LIST" | jq 'length')" -gt 0 ]; then
  echo "$BOUGHT_LIST" | jq -r '.[] | "  id: \(.id)  status: \(.status)  priceTotal: \(.priceTotal)  user: \(.user.username // .user // "n/a")"'
else
  echo "(none)"
fi

echo ""
echo "=== Orders (SOLD – as seller) ==="
SOLD=$(run_query "true")

if echo "$SOLD" | jq -e '.errors' >/dev/null 2>&1; then
  echo "GraphQL errors:"
  echo "$SOLD" | jq '.errors'
  exit 1
fi
SOLD_COUNT=$(echo "$SOLD" | jq -r '.data.userOrdersTotalNumber // .data.user_orders_total_number // 0')
SOLD_LIST=$(echo "$SOLD" | jq -r '.data.userOrders // .data.user_orders // []')
echo "Total count: $SOLD_COUNT"
echo "Returned: $(echo "$SOLD_LIST" | jq 'length')"
if [ "$(echo "$SOLD_LIST" | jq 'length')" -gt 0 ]; then
  echo "$SOLD_LIST" | jq -r '.[] | "  id: \(.id)  status: \(.status)  priceTotal: \(.priceTotal)  user: \(.user.username // .user // "n/a")"'
else
  echo "(none)"
fi

echo ""
echo "=== Summary ==="
echo "Bought: ${BOUGHT_COUNT:-0}  |  Sold: ${SOLD_COUNT:-0}"
if [ "${BOUGHT_COUNT:-0}" -eq 0 ] && [ "${SOLD_COUNT:-0}" -eq 0 ]; then
  echo ""
  echo "No orders found. If you just placed an order, use the same account token and check backend persistence."
fi
