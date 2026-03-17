# Order in conversation (sale confirmation in chat)

This doc describes how the Swift app uses **order-in-conversation** so the backend (prelura-app) can ensure the feature is integrated and deployed.

## What the Swift app does

1. **Single source of truth**  
   The app uses **only the API** for order data. It does not derive or patch `conversation.order` from messages. The order confirmation card is shown when `conversation.order` is returned by `getConversationById` or `getConversations`.

2. **After payment**  
   The app refetches conversations, finds the one linked to the order (or the seller), and opens it. The card appears when the backend returns `order` on that conversation.

3. **When opening a chat**  
   The app always loads conversation and messages from the backend. If the backend returns `order` on the conversation, the card is shown. If the backend links the order shortly after (e.g. after payment), the app may refetch the conversation once when it sees a `sold_confirmation` message but no order yet.

4. **List preview**  
   For the conversation list, when there is no last message text, the app shows “Order • £x.xx” when `conversation.order` is present. When leaving a chat, the app passes the last message preview to the list so it updates immediately without waiting for a refetch.

## What the backend must provide

- **Link order to conversation**  
  On payment success, the backend must associate the order with the conversation between buyer and seller (e.g. set `Conversation.order_id` or equivalent). The Swift app never builds or stores order on the client; it only displays what the API returns.

- **Queries**  
  `conversations` and `conversation_by_id` must return `order { id status priceTotal products { id name imagesUrl } }` when the conversation has an associated order.

- **Messages**  
  The backend creates a message with `item_type: "sold_confirmation"` in that conversation so it appears in the timeline. The Swift app shows that as a banner and uses it only to trigger a refetch of the conversation when the app does not yet have `order` (e.g. right after payment).

## Summary

| Aspect | Responsibility |
|--------|----------------|
| **Linking order ↔ conversation** | Backend (on payment success) |
| **Returning `order` in `conversations` and `conversation_by_id`** | Backend |
| **Showing order card and list preview** | Swift app (from API only) |

Once the backend links orders to conversations and returns `order` in the queries, the feature works. The Swift app does not use optimistic or client-derived order data.
