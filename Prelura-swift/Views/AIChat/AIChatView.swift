import SwiftUI
import PhotosUI

// MARK: - Chat message model

struct ChatMessage: Identifiable {
    let id: UUID
    let isFromUser: Bool
    let text: String
    var items: [Item]?
    init(id: UUID = UUID(), isFromUser: Bool, text: String, items: [Item]? = nil) {
        self.id = id
        self.isFromUser = isFromUser
        self.text = text
        self.items = items
    }
}

// MARK: - Out-of-scope copy

private let botOutOfScopeMessage = "I don’t understand that. I can help you find items by colour, category, or style—try something like “red dress” or “blue shoes”."

// MARK: - AI Chat View (conversational chatbot)

/// Dedicated AI chat: conversation with a welcome message, Messages-style input, and in-scope search or out-of-scope reply.
struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @ObservedObject var viewModel: HomeViewModel
    var onDismiss: (() -> Void)?

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isBotThinking: Bool = false

    private let aiSearch = AISearchService()
    private let productService = ProductService()
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("AI Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Done")) {
                        onDismiss?()
                        dismiss()
                    }
                    .foregroundColor(Theme.primaryColor)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            productService.updateAuthToken(authService.authToken)
            if messages.isEmpty {
                messages = [
                    ChatMessage(isFromUser: false, text: L10n.string("What are you looking for?"))
                ]
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(messages) { message in
                        ChatBubbleView(message: message, viewModel: viewModel)
                    }
                    if isBotThinking {
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            TypingIndicatorView()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
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

    /// Messages-style input: single-line text field and send button.
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            TextField(L10n.string("What are you looking for?"), text: $inputText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .focused($isInputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(20)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Theme.primaryColor : Theme.Colors.secondaryText)
            }
            .disabled(!canSend || isBotThinking)
            .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.primaryAction() }))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .overlay(ContentDivider(), alignment: .top)
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
        let parsed = aiSearch.parse(query: raw)
        let inScope = isParsedInScope(parsed)

        if inScope {
            let categoryFilter = (parsed.categoryOverride == nil || parsed.categoryOverride == "All") ? nil : parsed.categoryOverride
            do {
                let products = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: pageSize,
                    search: parsed.searchText.isEmpty ? nil : parsed.searchText,
                    parentCategory: categoryFilter
                )
                let visible = products.excludingVacationModeSellers()
                let replyText: String
                if visible.isEmpty {
                    replyText = L10n.string("I couldn’t find anything matching that. Try different colours or categories.")
                } else if let hint = parsed.closestMatchHint {
                    replyText = hint
                } else {
                    replyText = L10n.string("Here are some items that might work.")
                }
                await MainActor.run {
                    messages.append(ChatMessage(isFromUser: false, text: replyText, items: visible))
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(isFromUser: false, text: L10n.string("Something went wrong. Please try again.")))
                }
            }
        } else {
            await MainActor.run {
                messages.append(ChatMessage(isFromUser: false, text: botOutOfScopeMessage))
            }
        }
    }

    private func isParsedInScope(_ parsed: ParsedSearch) -> Bool {
        if !parsed.searchText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if let cat = parsed.categoryOverride, !cat.isEmpty, cat != "All" { return true }
        if !parsed.appliedColourNames.isEmpty { return true }
        return false
    }
}

// MARK: - Chat bubble (user vs bot, optional product grid)

struct ChatBubbleView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if message.isFromUser { Spacer(minLength: 60) }
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message.text)
                    .font(Theme.Typography.body)
                    .foregroundColor(message.isFromUser ? .white : Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromUser ? Theme.primaryColor : Theme.Colors.secondaryBackground)
                    )

                if let items = message.items, !items.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Theme.Spacing.sm),
                            GridItem(.flexible(), spacing: Theme.Spacing.sm)
                        ],
                        spacing: Theme.Spacing.sm
                    ) {
                        ForEach(items) { item in
                            NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                                HomeItemCard(item: item, onLikeTap: { viewModel.toggleLike(productId: item.productId ?? "") })
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)
            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .id(message.id)
    }
}

// MARK: - Typing indicator

private struct TypingIndicatorView: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.Colors.secondaryText)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.Colors.secondaryBackground)
        )
    }
}