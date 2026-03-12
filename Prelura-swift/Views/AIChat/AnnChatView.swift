import SwiftUI

/// Support chat with Ann: customer support and order issues. Uses same OpenAI key as Lenny with a different system prompt. Can show user's orders in a slider.
struct AnnChatView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = HomeViewModel()

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isBotThinking: Bool = false

    private let openAI = OpenAIService.shared

    private static let conversationStarters: [String] = [
        "I need help with an order.",
        "When will I get my refund?",
        "How do I cancel my order?",
        "My item says delivered but I don't have it.",
        "I'd like to check my order status."
    ]

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .background(Theme.Colors.background)
        .navigationTitle("Ann")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var messageList: some View {
        Group {
            if messages.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.primaryColor.opacity(0.6))
                        Text("Welcome to support — I'm Ann. Ask about orders, refunds, or anything else. How can I help?")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                ChatBubbleView(
                                    message: message,
                                    isLastMessage: index == messages.count - 1,
                                    viewModel: viewModel
                                )
                            }
                            if isBotThinking {
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    TypingIndicatorView()
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .id("typing")
                            }
                        }
                        .padding(.vertical, Theme.Spacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if isBotThinking {
                                proxy.scrollTo("typing", anchor: .bottom)
                            } else if let last = messages.last?.id {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isBotThinking) { _, thinking in
                        if thinking {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .leading) {
                TextField(placeholderForInputBar, text: $inputText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .focused($isInputFocused)
                    .lineLimit(1...6)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(isInputFocused ? Theme.primaryColor : Color.clear, lineWidth: 2)
                    )
                if messages.isEmpty && inputText.isEmpty {
                    ConversationStarterOverlay(
                        starters: Self.conversationStarters,
                        onTap: { isInputFocused = true }
                    )
                }
            }
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Theme.primaryColor : Theme.Colors.secondaryText)
            }
            .disabled(!canSend || isBotThinking)
            .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.primaryAction() }))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .top
        )
    }

    private var placeholderForInputBar: String {
        (messages.isEmpty && inputText.isEmpty) ? "" : L10n.string("Type a message...")
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isBotThinking else { return }

        let userMessage = ChatMessage(isFromUser: true, text: raw)
        messages.append(userMessage)
        inputText = ""
        isBotThinking = true

        Task {
            await respondToUserMessage(raw)
            await MainActor.run { isBotThinking = false }
        }
    }

    private func respondToUserMessage(_ raw: String) async {
        let thinkingStart = Date()
        let minThinkingSeconds = Double.random(in: 1.0...2.5)
        let conversationHistory = buildConversationHistory()

        let openAIReply = openAI.isConfigured
            ? await openAI.reply(userMessage: raw, conversationHistory: conversationHistory, assistant: .ann)
            : nil
        let replyText = openAIReply ?? "I'm Ann, here to help with orders and support. What would you like to know?"

        await ensureMinThinkingTime(since: thinkingStart, minSeconds: minThinkingSeconds)
        await MainActor.run {
            // Ann chat is text-only: no product or order cards in the conversation.
            messages.append(ChatMessage(isFromUser: false, text: replyText, items: nil, orders: nil))
        }
    }

    private func ensureMinThinkingTime(since: Date, minSeconds: Double) async {
        let elapsed = Date().timeIntervalSince(since)
        if elapsed < minSeconds {
            try? await Task.sleep(nanoseconds: UInt64((minSeconds - elapsed) * 1_000_000_000))
        }
    }

    private func buildConversationHistory() -> [(user: String, assistant: String)] {
        var pairs: [(user: String, assistant: String)] = []
        var i = 0
        while i < messages.count {
            guard messages[i].isFromUser else { i += 1; continue }
            let userText = messages[i].text
            i += 1
            if i < messages.count, !messages[i].isFromUser {
                pairs.append((userText, messages[i].text))
                i += 1
            }
        }
        let maxPairs = 5
        if pairs.count <= maxPairs { return pairs }
        return Array(pairs.suffix(maxPairs))
    }
}
