# Lenny: rules vs OpenAI

## Current state

**OpenAI is not integrated with Lenny.**

All of Lenny’s replies are produced in the **Swift app** by:

- **AISearchService** (rule engine): parses the query, runs search via GraphQL, picks a reply from prewritten sets (e.g. `replyForResults`, `replyForNoResults`, `randomGreetingReply`, `replyForFallbackResults`).
- **ProductService**: only used for **search** (`getAllProducts`). No LLM is called.

So today you always know: **Lenny = rules**. Every reply is from the rule engine and prewritten text.

---

## When you add OpenAI (e.g. via backend)

1. **Backend** (prelura-app) gets a new endpoint, e.g. `POST /chat/lenny` or a GraphQL mutation, that:
   - Receives the user message (and optionally search context).
   - Calls OpenAI with the system prompt in `docs/lenny-system-prompt.txt` and the user message.
   - Returns the model’s reply (and optionally a **source** flag).

2. **Swift app** then has two paths:
   - **Path A (rules):** current behaviour - parse locally, search via GraphQL, build reply with `AISearchService` (no OpenAI).
   - **Path B (OpenAI):** send the user message to the backend Lenny endpoint; backend calls OpenAI and returns the reply.

You choose when to use which (e.g. “only use OpenAI for complex/unclear queries” or “use OpenAI for all replies”).

---

## How to know whether Lenny is rules or OpenAI

**Right now:** Lenny is always rules. No OpenAI call exists.

**After integration**, you can tell who responded in one or more of these ways:

| Method | How |
|--------|-----|
| **Backend response field** | Backend returns e.g. `{ "text": "...", "source": "openai" }` or `"source": "rules"`. Swift app stores or displays it (e.g. for debugging or a “Powered by OpenAI” label). |
| **Logging** | Backend logs e.g. `Lenny reply from OpenAI` vs `Lenny reply from rules` per request. You see it in server logs. |
| **Feature flag** | e.g. `USE_OPENAI_FOR_LENNY`. When off, Swift/backend only use rules. When on, backend calls OpenAI. You know by the flag. |
| **Separate endpoint** | Swift calls “/chat/lenny” only when you want an OpenAI reply; otherwise it uses the existing rule-based flow. Which code path was called tells you who responded. |

Recommended: have the backend **return a `source`** (`"rules"` | `"openai"`) in the Lenny API response so the app (and your logs) can always tell who responded.
