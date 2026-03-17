# Empty chat / missing sale confirmation – A–E check results

We ran the conversations API and compared with the codebase and backend. Here’s what is **true** and what is **not**.

---

## Summary

| Check | Result | Evidence |
|-------|--------|----------|
| **A** (timing: backend links order after we fetch) | **Unclear** | Backend code links order in `handle_payment_success` when `confirmPayment` runs. We never see any conversation with `order` in the API, so timing alone doesn’t explain it. |
| **B** (we open the wrong conversation) | **Plausible** | We pick `withOrder ?? withAnyOrder ?? withSeller.first`. Since **no** conversation has `order` in the response, we always fall back to “first with seller” or new chat – so we can easily open a conversation that has no order. |
| **C** (backend never returns order) | **TRUE** | **Conversations API returns 0 conversations with `order != null`** (25 total, all with `order: null`). So either the backend never links order→conversation, or the link exists but isn’t returned. |
| **D** (decoding drops order) | **Not the main cause** | We didn’t see any conversation with non-null `order` in the raw JSON. So the problem is upstream of decoding. Decoding could still drop `order` if the backend sent a different shape. |
| **E** (getConversationById or getMessages fails) | **TRUE for getConversationById** | **Live GraphQL schema expects `conversationById` (camelCase).** The app sends **`conversation_by_id`** in the query, so the server returns: *“Cannot query field 'conversation_by_id' on type 'Query'. Did you mean 'conversationById'?”* So `getConversationById` fails. The app uses `try?`, so it gets `nil` and never updates `displayedConversation` from the API. |

---

## 1. How we checked

- **Script:** `scripts/fetch-conversations.sh` (same token as simulator).
- **Calls:** `conversations` and `conversationById(id: "<first_conv_id>")`.

Result:

- **conversations:** 25 conversations, **0 with `order != null`**.
- **conversation_by_id** in the query → GraphQL error (field doesn’t exist; use `conversationById`).
- **conversationById** in the query → request succeeds, response has `order: null` for that conversation.

So:

- The backend is **not** returning `order` on any conversation we see.
- The app’s **getConversationById** call fails on the live API because of the wrong field name.

---

## 2. C – Backend never returns order

- **Observed:** Every conversation in the API has `order: null`.
- **Backend code:**  
  - `handle_payment_success` (from `confirmPayment` or webhook) calls `ChatUtils.conversation_exists(..., is_order=True, order=order)`.  
  - That calls `get_or_create_order_conversation`, which either links `order` to an existing conversation or creates a new one with `order` set.  
  - `resolve_conversations` and `resolve_conversation_by_id` use `.select_related('order')` and `resolve_order` returns `self.order`.
- So if the link were saved in the DB, we’d expect to see some conversation with non-null `order`. We don’t.

**Conclusion:** Either the order→conversation link is never written (e.g. `handle_payment_success` not run for these orders, or it throws before/inside `conversation_exists`), or it’s written in a way that doesn’t show up in this query (e.g. different user, or bug in link). So **C is TRUE** from the client’s perspective: we never get `order` on any conversation.

---

## 3. E – getConversationById fails (wrong field name)

- **Observed:** Query with `conversation_by_id(id: $id)` → GraphQL error: *“Cannot query field 'conversation_by_id' on type 'Query'. Did you mean 'conversationById'?”*
- **App code:** `ChatService.getConversationById` sends a query with **`conversation_by_id(id: $id)`** and decodes using `CodingKeys.conversationById = "conversation_by_id"`.
- **Live API:** Expects **`conversationById`** (camelCase). So the app’s query is invalid and the request fails.

So every time the chat screen calls `getConversationById`:

- The request fails with a GraphQL error.
- The app uses `try?`, so it gets `nil` and never updates `displayedConversation` from the API.
- The banner depends on `displayedConversation.order`; that only gets set from this response, so it never appears.

**Conclusion:** **E is TRUE** for `getConversationById`: the call fails because of the wrong field name, so we never load conversation (or order) by id.

---

## 4. What to fix (for sure)

1. **E – getConversationById**
   - In the Swift app, change the GraphQL query from **`conversation_by_id(id: $id)`** to **`conversationById(id: $id)`**.
   - Ensure the response is decoded with the key the API actually returns (e.g. **`conversationById`** in JSON). If the server returns camelCase, use `CodingKeys.conversationById = "conversationById"` (or no custom key if the property name already matches).

2. **C – order never in response**
   - On the backend, confirm that when payment succeeds (`confirmPayment` and/or webhook), `handle_payment_success` runs and that `ChatUtils.conversation_exists(..., is_order=True, order=order)` runs without throwing.
   - Confirm that the conversation that gets `order` set is the same one the client will fetch (same participant pair, no extra filters that would hide it).
   - Optionally add logging or a small script that, right after a test payment, fetches `conversations` / `conversationById` and checks that at least one conversation has non-null `order`.

After fixing E, the chat screen will at least load the conversation by id. If C is also fixed (backend really links and returns `order`), the sale confirmation banner should appear.
