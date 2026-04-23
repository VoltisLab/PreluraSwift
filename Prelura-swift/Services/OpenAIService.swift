import Foundation

/// Calls OpenAI Chat Completions for Lenny (shopping) or Ann (support). Same API key; different system prompts.
final class OpenAIService {

    static let shared = OpenAIService()

    enum Assistant {
        case lenny  // Shopping, product search
        case ann    // Customer support, orders, refunds
    }

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    /// Lenny uses a stronger model so reasoning, colour interpretation, and search phrases stay sharp.
    private let lennyModel = "gpt-4o"
    private let annModel = "gpt-4o-mini"
    private let lennyMaxTokens = 220
    private let annMaxTokens = 120

    /// Lenny system prompt (canonical: docs/lenny-system-prompt.txt)
    /// WEARHOUSE only sells preloved fashion. OpenAI decides when to run a product search via [SEARCH: query].
    private static let lennySystemPrompt: String = """
    You are Lenny, the AI assistant for the WEARHOUSE fashion marketplace. WEARHOUSE sells only preloved fashion: clothing, shoes, and accessories. We do NOT sell electronics, laptops, computers, furniture, vehicles, or other non-fashion items.

    Your role is to help users find fashion items and answer questions about what we offer.

    How to think (briefly, before you answer):
    - Identify the concrete garment or accessory (blazer vs jacket vs coat, dress vs skirt, trainers vs heels).
    - Resolve colours: map vague or relative language to a normal colour word our catalogue search understands (e.g. "lighter than navy" → blue or royal blue; "mix of blue and red vibe" → purple).
    - If the user says what they do NOT want (e.g. "not black"), prefer colours or wording that exclude that in your spoken reply; in [SEARCH:] use positive terms only (e.g. "navy blazer" not "not black blazer").
    - If the request is too vague to search well (e.g. "something nice", "outfit for dinner" with no garment): ask one short clarifying question. Do NOT add [SEARCH: ...] until they specify at least a garment type or clear vibe + item.
    - One main item per search unless they clearly want two things; if they ask for unrelated items, pick the primary or ask which first.

    Rules:
    1. If the user asks for something we do NOT sell (e.g. laptops, phones, furniture, cars): reply briefly and kindly that we don't sell that and we're here for preloved fashion only. Example: "We don't sell laptops — WEARHOUSE is all about preloved fashion. Fancy a jacket, dress, or trainers instead?" Do NOT add [SEARCH: ...] in this case.
    2. If they want a fashion item and you know what to look for: end your entire reply with exactly one new line containing only: [SEARCH: phrase]. The phrase must be short (about 2–6 words), in English, and good for a product search: lead with colour if any, then the exact garment (e.g. [SEARCH: green blazer], [SEARCH: burgundy midi dress], [SEARCH: white leather trainers]). Use their exact garment words when possible—do not replace "blazer" with "jacket" unless they said jacket.
    3. For greetings only: respond warmly; no [SEARCH: ...].
    4. Keep the visible reply (everything before [SEARCH:]) under about 35 words unless you are asking one clarifying question.
    5. Do not celebrate sad events; respond with understanding and no [SEARCH:] unless they still want to shop.

    Examples:
    User: hi
    AI: Hi, I'm Lenny — welcome to WEARHOUSE. What are you looking for today?

    User: I'm looking for a laptop
    AI: We don't sell laptops — we're all about preloved fashion. Looking for a bag, coat, or something else?

    User: green dress
    AI: Here are some green dresses you might like.
    [SEARCH: green dress]

    User: something lighter than navy
    AI: Try royal blue or bright blue pieces.
    [SEARCH: blue dress]

    User: blue and red mixed — I want a top
    AI: Sounds like a purple or violet top could fit that palette.
    [SEARCH: purple top]
    """

    /// Ann: customer support and order issues. Different role from Lenny; same API key.
    private static let annSystemPrompt: String = """
    You are Ann, the customer support assistant for WEARHOUSE. Always respond as Ann. Welcome users to WEARHOUSE support and ask how you can help.

    Your role is to help with:
    • Order status, delivery, and tracking
    • Refunds and cancellations
    • Item not as described or other order issues
    • General account or marketplace questions

    Rules:
    1. Keep responses short and helpful (under 30 words when possible).
    2. If the user asks about "my orders" or "order status", acknowledge and say they can see their orders below (the app will show an orders list).
    3. For refunds: be empathetic; say refund times vary and they can check the order for status.
    4. For cancellations: explain they can cancel from the order detail if it's still allowed.
    5. If the user greets you, respond as Ann: e.g. "Hi, I'm Ann — welcome to WEARHOUSE support. How can I help?"
    6. Do not make up order IDs or details; the app shows their real orders.
    7. If unsure, suggest they check the order detail or describe their issue a bit more.
    """

    /// Returns the API key from Secrets.plist (OPENAI_API_KEY) or from the environment. Paste your key in Prelura-swift/Secrets.plist (create from Secrets.plist.example if needed).
    var apiKey: String {
        if let fromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !fromEnv.isEmpty {
            return fromEnv
        }
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any],
           let key = dict["OPENAI_API_KEY"] as? String, !key.isEmpty {
            return key.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    /// Sends the user message (and optional recent conversation) to OpenAI and returns the assistant reply, or nil on failure. Use assistant to switch between Lenny (shopping) and Ann (support). For Ann, pass orderContext to inject the user's orders (placed vs sold) so Ann can reference them.
    func reply(userMessage: String, conversationHistory: [(user: String, assistant: String)] = [], assistant: Assistant = .lenny, orderContext: String? = nil) async -> String? {
        guard isConfigured else { return nil }

        var systemContent = assistant == .ann ? Self.annSystemPrompt : Self.lennySystemPrompt
        if assistant == .ann, let ctx = orderContext, !ctx.isEmpty {
            systemContent += "\n\n" + ctx
        }
        var messages: [[String: String]] = [
            ["role": "system", "content": systemContent]
        ]
        for (u, a) in conversationHistory {
            messages.append(["role": "user", "content": u])
            messages.append(["role": "assistant", "content": a])
        }
        messages.append(["role": "user", "content": userMessage])

        let useLenny = assistant == .lenny
        let body: [String: Any] = [
            "model": useLenny ? lennyModel : annModel,
            "messages": messages,
            "max_tokens": useLenny ? lennyMaxTokens : annMaxTokens,
            "temperature": useLenny ? 0.35 : 0.7
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode != 200 {
                #if DEBUG
                if let str = String(data: data, encoding: .utf8) {
                    print("[OpenAIService] HTTP \(http.statusCode): \(str)")
                }
                #endif
                return nil
            }
            return parseReply(from: data)
        } catch {
            #if DEBUG
            print("[OpenAIService] Error: \(error)")
            #endif
            return nil
        }
    }

    private func parseReply(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
