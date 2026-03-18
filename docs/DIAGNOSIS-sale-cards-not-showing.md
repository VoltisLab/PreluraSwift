# Diagnosis: Why sale confirmation cards are not showing (no fixes, diagnosis only)

## Summary

**Root cause (high confidence):** The sale card depends on (1) `displayedConversation.order` (for the order summary at top) and/or (2) a message with `item_type: sold_confirmation` (for the banner in the timeline). Both come from the backend only after **handle_payment_success** runs. That runs in two places: **inside the ConfirmPayment mutation** (when Stripe status is already "succeeded") and in the **Stripe webhook** (payment_intent.succeeded). If **handle_payment_success returns early** (e.g. `order.user_id` or `order.seller_id` is null) or **throws** before calling `link_order_to_conversation` / `add_sold_confirmation_message`, then no conversation gets `order` set and no sold_confirmation message is created, so the API never has data to show and the sale card never appears.

**Secondary possibility:** The conversation we open after payment is not the same conversation the backend links the order to (e.g. multiple conversations with the same seller; we pick one, backend links another), so we see an empty chat.

---

## Data flow (no polling/refresh)

1. User taps Pay → app calls **confirmPayment(paymentRef)**.
2. Backend **ConfirmPayment** mutation: if `payment_intent.status == "succeeded"`, it calls **handle_payment_success({"payment_ref": payment_ref})** synchronously.
3. **handle_payment_success** (payments/views.py):
   - Marks payment successful.
   - If `not order or not order.user_id or not order.seller_id` → **logs and returns without linking** (no order on conversation, no sold_confirmation message).
   - Otherwise: `link_order_to_conversation(order.user, order.seller, order)` then `add_sold_confirmation_message(conv, order)`.
4. Mutation returns; app then calls **getConversations()**, picks conversation (withSeller.first or new), opens chat with that **Conversation**.
5. Chat **loadConversationAndMessagesFromBackend** runs: **getConversationById(convId)** and **getMessages(convId)**.
6. Sale card at top: **displayedConversation.order** (from list when we opened, or from getConversationById).
7. Sale banner in timeline: a **Message** with **isSoldConfirmation** (from **getMessages**), rendered as **SoldConfirmationBannerView**.

So for the card to show **without** polling/refresh we need:

- handle_payment_success to run and **not** return early, and to run **link_order_to_conversation** and **add_sold_confirmation_message**.
- The conversation we open to be the **same** one that was linked (so it has `order` and the new message).
- **getConversations()** to return that conversation with **order** in the response (so the app can show the top card from the list), and/or **getConversationById** to succeed and return **order**.
- **getMessages()** to return the **sold_confirmation** message so the timeline shows the banner.

---

## Why sale cards might not show (diagnosis only)

### A. handle_payment_success returns early or throws

- **Code:** `if not order or not order.user_id or not order.seller_id: logger.warning(...); return`
- If the **Order** row has null **user_id** or **seller_id** (e.g. bug in order creation, or legacy data), we never link the order to a conversation and never create the sold_confirmation message. No conversation will have `order` in the API, and no message with `item_type: sold_confirmation` will exist.
- If **handle_payment_success** throws (e.g. in **link_order_to_conversation** or **add_sold_confirmation_message**), same result: no link, no message. ConfirmPayment catches and logs but the order is not linked.

**How to confirm:** Server logs for `"Payment … has no order or missing buyer/seller; skipping chat link"` or any exception in handle_payment_success / order_offer_chat.

---

### B. Wrong conversation opened

- After payment we pick **withSeller.first** from **getConversations()** (first conversation with that seller). Backend **resolve_conversations** orders by **-last_modified**. The conversation we link in handle_payment_success gets its **last_modified** updated, so it should be first.
- If there are multiple conversations with the same seller and the backend returns them in an order that doesn’t put the linked one first (e.g. different ordering, or list not refreshed), we might open a different conversation. That one would have no **order** and no sold_confirmation message → empty chat.

**How to confirm:** Compare the **conversation id** the app opens with the **conversation id** that has the order in the DB (e.g. `Conversation.objects.filter(order_id=order.id)`).

---

### C. getConversationById fails (nil) so we never refresh order from API

- **Code:** `let updatedConv: Conversation? = try? await chatService.getConversationById(conversationId: convId)` — errors are swallowed.
- If the **conversationById** request fails (network, or GraphQL error, e.g. wrong field name), **updatedConv** is nil. We then **do not** update **displayedConversation** from the API. We might still have **order** from the **conversations list** (if the list returned it when we opened the chat). So the **top** order card could still show from the list; the **timeline** sold_confirmation banner depends on **getMessages** returning the message, not on getConversationById.
- **Graphene** default is **auto_camelcase=True**, so the schema exposes **conversationById**, not **conversation_by_id**. The app queries **conversationById**, so a schema field name mismatch is unlikely unless the deployed server disables auto_camelcase.

**How to confirm:** Inspect network/response for the **ConversationById** request: success vs error; if error, check exact GraphQL error message (e.g. unknown field).

---

### D. getMessages fails or doesn’t return the sold_confirmation message

- The timeline banner comes from **messages** with **isSoldConfirmation** (message with **item_type: sold_confirmation** or content type sold_confirmation). Those messages come only from **getMessages(conversationId)**.
- If **getMessages** fails (e.g. GraphQL error, wrong field name, or decoding error), we set **msgs = []** and the timeline stays empty.
- If **getMessages** succeeds but the backend never created the message (because handle_payment_success returned early or threw), the list won’t contain a sold_confirmation message.

**How to confirm:** Inspect **getMessages** response for that conversation: does it include a message with **item_type** (or content) **sold_confirmation**? And check server logs to see if **add_sold_confirmation_message** ran (e.g. "order_offer_chat: created sold_confirmation message …").

---

### E. conversations list doesn’t return order

- When we open the chat right after payment, **displayedConversation** is the one we got from **getConversations()**. If that payload doesn’t include **order** (e.g. **ConversationType** had **order** excluded or **resolve_order** missing, or response key different from what the app decodes), then **displayedConversation.order** is nil even if the backend linked the order. We’d rely on **getConversationById** to refresh it; if that also fails, the top card never appears.
- Current backend code includes **order** on **ConversationType** and **select_related('order', 'offer')** in chat queries, so this is only a concern if the deployed build differs or decoding is wrong.

**How to confirm:** Inspect raw **conversations** response: does any conversation have a non-null **order** after a successful payment?

---

## Most likely single cause

**handle_payment_success is exiting early or throwing before it links the order and creates the sold_confirmation message.** That would explain:

- Empty chat (no order on conversation, no sold_confirmation message in the API).
- “It was working yesterday” if a recent change (e.g. the early-return guard, or order creation) started leaving **order.user_id** / **order.seller_id** null for some flows, or if an exception was introduced in **link_order_to_conversation** / **add_sold_confirmation_message** (e.g. in **add_sold_confirmation_message** when building payload from **order.items** / product).

To be **100% sure**, server-side checks are needed:

1. After a test payment, check server logs for **handle_payment_success** and **order_offer_chat** (link + sold_confirmation message).
2. Check for the warning: **"Payment … has no order or missing buyer/seller; skipping chat link"**.
3. In the DB, confirm that the **Order** has non-null **user_id** and **seller_id**, and that a **Conversation** has that **order_id** and a **Message** with **item_type = 'sold_confirmation'** for that conversation.

**Run the diagnostic command (backend repo):** From **prelura-app** with venv activated and env/DB configured, run:
```bash
python manage.py check_sale_card_linking --limit 20
python manage.py check_sale_card_linking --order-id 123   # single order
```
This prints for each order: `user_id`, `seller_id`, whether a conversation is linked, and whether a `sold_confirmation` message exists. Orders with user+seller but no linked conversation are listed at the end.

---

## Reverts applied (as requested)

- Removed **.refreshable** from the chat ScrollView.
- Restored polling to **15** iterations (from 25).
- Restored **ConversationByIdResponse** to decode only **conversationById** (no dual snake_case key).

No other fixes were applied; this document is diagnosis only.
