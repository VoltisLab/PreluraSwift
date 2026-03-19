# Diagnosis: New offer card shows previous offer’s price until refresh

## What you see

- You send a new offer for £140 from a card that showed £70.
- The new card appears immediately but shows **£70**.
- After refreshing the page, the same card shows **£140**.

## Root cause (code path)

**Where the new card gets its data**

In `ChatDetailView.handleCreateNewOffer(offerPrice:)` (around 594–621):

1. We call `productService.createOffer(offerPrice: offerPrice, ...)` with 140.
   - The **createOffer mutation response** includes the new conversation and the **new offer** (the one just created, so £140).  
   - That is returned as `newConv` and `newConv.offer` has the correct price.

2. We then call `chatService.getConversations()`.
   - This is a **separate API** (conversations list query).
   - It returns a list of conversations, each with an `offer` field that comes from the **list/query** path, not from the createOffer mutation.

3. We choose which conversation/offer to use:
   - **First branch (used when the conversation is in the list):**  
     `if let updated = convs.first(where: { $0.id == displayedConversation.id })`  
     We use `updated` from **getConversations()**, then:
     - `serverOffer = updated.offer`
     - We build the new card from `serverOffer` (price, status, etc.).
   - **Second branch (only when the conversation is not in the list):**  
     `else if let newConv = newConv, ... let serverOffer = newConv.offer`  
     We use the offer from the **createOffer** response.

So whenever the conversation **is** found in the list (normal case when you’re already in that chat), we build the new card from **getConversations()** (`updated.offer`), **not** from the createOffer response (`newConv.offer`).

**Why the new card shows £70**

- The new card’s content comes from `updated.offer`, i.e. the offer attached to that conversation in the **conversations list** response.
- That list can still hold the **previous** offer (£70) when:
  - The list is cached, or
  - The backend’s list/query path returns the conversation before it’s updated with the new offer, or
  - A different code path builds the list and hasn’t been updated yet.
- So we display a card built from stale list data (£70).
- The **createOffer** response already has the correct offer (£140) in `newConv.offer`, but we only use it in the `else if` branch when the conversation is **not** in the list, which doesn’t happen when you’re in that chat.

**Why refresh fixes it**

- On refresh we call the same (or similar) conversation/list API again.
- By then the backend has updated the conversation’s offer to the new one.
- So we get £140 and the card shows the correct price.

## Summary

| Source              | When it’s used                         | Contains        |
|---------------------|----------------------------------------|-----------------|
| createOffer response (`newConv.offer`) | Only when conversation not in list     | New offer (£140) |
| getConversations() (`updated.offer`)   | Whenever conversation is in list (usual case) | Can be stale (£70) |

The bug is **not** the optimistic card or the backend createOffer mutation. It is that we **prefer** the conversations-list offer for building the new card and only fall back to the createOffer response when the conversation is missing from the list. So we often show list data that is still the old offer until a later refresh returns the updated list.

## Fix direction (for when you want to implement)

Use the **createOffer** response as the source of truth for the new card when it’s available: e.g. prefer `newConv.offer` (and `newConv` for that conversation) for the offer we just created, and only use `updated.offer` from getConversations() when we don’t have a createOffer result for this conversation (e.g. after a refresh or when we didn’t just call createOffer).
