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

private let botOutOfScopeMessage = "I don't understand that. I can help you find items by colour, category, or style—try something like “red dress” or “blue shoes”."

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
                .cornerRadius(30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(isInputFocused ? Theme.primaryColor : Color.clear, lineWidth: 2)
                )

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
        if aiSearch.isGreetingOnly(raw) {
            await MainActor.run {
                messages.append(ChatMessage(isFromUser: false, text: "Hi! What are you looking for? Try something like a dress, jacket, or shoes.", items: []))
            }
            return
        }
        let parsed = aiSearch.parse(query: raw)
        let inScope = isParsedInScope(parsed)

        if inScope {
            let categoryFilter = (parsed.categoryOverride == nil || parsed.categoryOverride == "All") ? nil : parsed.categoryOverride
            do {
                // When user specified colour(s), fetch more candidates then filter by colour client-side so we show all matches (backend search often returns too few).
                let colourSet = Set(parsed.appliedColourNames.map { $0.lowercased() })
                let searchWithoutColour = parsed.searchText
                    .split(separator: " ")
                    .map(String.init)
                    .filter { !colourSet.contains($0.lowercased()) }
                    .joined(separator: " ")
                let useBroadSearch = !parsed.appliedColourNames.isEmpty
                let searchForApi = useBroadSearch ? (searchWithoutColour.isEmpty ? nil : String(searchWithoutColour)) : (parsed.searchText.isEmpty ? nil : parsed.searchText)
                let fetchCount = useBroadSearch ? 50 : pageSize

                var products = try await productService.getAllProducts(
                    pageNumber: 1,
                    pageCount: fetchCount,
                    search: searchForApi,
                    parentCategory: categoryFilter,
                    maxPrice: parsed.priceMax
                )
                var visible = products.excludingVacationModeSellers()
                if useBroadSearch && !parsed.appliedColourNames.isEmpty {
                    visible = visible.filter { item in
                        item.colors.contains { c in
                            parsed.appliedColourNames.contains { $0.caseInsensitiveCompare(c) == .orderedSame }
                        }
                    }
                    // If no items match the colour, use backend search with full query (e.g. "black shirt") instead of showing unfiltered results
                    if visible.isEmpty {
                        let fullQueryProducts = try await productService.getAllProducts(
                            pageNumber: 1,
                            pageCount: pageSize,
                            search: parsed.searchText.isEmpty ? nil : parsed.searchText,
                            parentCategory: categoryFilter,
                            maxPrice: parsed.priceMax
                        )
                        visible = fullQueryProducts.excludingVacationModeSellers()
                    }
                }
                var replyText: String

                if visible.isEmpty, !parsed.searchText.isEmpty, parsed.searchText.contains(" ") {
                    let colourSet = Set(parsed.appliedColourNames.map { $0.lowercased() })
                    let words = parsed.searchText.split(separator: " ").map(String.init)
                    let fallbackTerm = words.last(where: { !colourSet.contains($0.lowercased()) })
                        ?? words.last
                        ?? parsed.searchText
                    if aiSearch.isFallbackTermValid(fallbackTerm) {
                        let fallbackProducts = try await productService.getAllProducts(
                            pageNumber: 1,
                            pageCount: pageSize,
                            search: fallbackTerm,
                            parentCategory: categoryFilter,
                            maxPrice: parsed.priceMax
                        )
                        let fallbackVisible = fallbackProducts.excludingVacationModeSellers()
                        if !fallbackVisible.isEmpty {
                            visible = fallbackVisible
                            replyText = aiSearch.replyForFallbackResults(fallbackTerm: fallbackTerm)
                        } else {
                            replyText = aiSearch.replyForNoResults()
                        }
                    } else {
                        replyText = aiSearch.replyForNoResults()
                    }
                } else {
                    replyText = aiSearch.replyForResults(parsed: parsed, hasItems: !visible.isEmpty, query: raw)
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
        if parsed.priceMax != nil { return true }
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
                    .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)

                if let items = message.items, !items.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(Array(items.prefix(20))) { item in
                                    NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                                        HomeItemCard(item: item, onLikeTap: { viewModel.toggleLike(productId: item.productId ?? "") })
                                            .frame(width: 140, alignment: .topLeading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                        .frame(maxWidth: .infinity)
                        if items.count >= 3 {
                            NavigationLink(destination: AIResultsView(items: items, viewModel: viewModel)) {
                                Text(L10n.string("See All"))
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.primaryColor)
                            }
                            .buttonStyle(HapticTapButtonStyle())
                            .padding(.top, Theme.Spacing.xs)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .id(message.id)
    }
}

// MARK: - AI Results (full-page results from AI, no search)

struct AIResultsView: View {
    let items: [Item]
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var authService: AuthService

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(items) { item in
                    NavigationLink(destination: ItemDetailView(item: item, authService: authService)) {
                        HomeItemCard(item: item, onLikeTap: { viewModel.toggleLike(productId: item.productId ?? "") })
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Results"))
        .navigationBarTitleDisplayMode(.inline)
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