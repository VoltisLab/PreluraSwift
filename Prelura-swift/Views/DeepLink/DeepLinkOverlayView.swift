import SwiftUI

/// Presents a single deep-link destination (product, user profile, or chat) in a full-screen cover. Resolves product by ID or user by username.
struct DeepLinkOverlayView: View {
    let item: DeepLinkDestinationItem
    let onDismiss: () -> Void
    private var destination: DeepLinkDestination { item.destination }
    @EnvironmentObject var authService: AuthService
    @State private var resolvedItem: Item?
    @State private var resolvedUser: User?
    @State private var resolvedConversation: Conversation?
    @State private var isLoading = true
    @State private var loadError: String?

    private let productService = ProductService()
    private let userService = UserService()
    private let chatService = ChatService()

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                    if let err = loadError {
                        Text(err)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
            } else {
                destinationView
            }
        }
        .onAppear {
            if let token = authService.authToken {
                productService.updateAuthToken(token)
                userService.updateAuthToken(token)
                chatService.updateAuthToken(token)
            }
            Task { await resolve() }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .product(let productId):
            if let item = resolvedItem {
                ItemDetailView(item: item, authService: authService)
                    .overlay(alignment: .topLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
            } else {
                deepLinkErrorView(message: "Product not found")
            }
        case .user:
            if let user = resolvedUser {
                UserProfileView(seller: user, authService: authService)
                    .overlay(alignment: .topLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
            } else {
                deepLinkErrorView(message: "User not found")
            }
        case .conversation(let conversationId, let username, _, _):
            if let conv = resolvedConversation {
                ChatDetailView(conversation: conv)
                    .overlay(alignment: .topLeading) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
            } else {
                deepLinkErrorView(message: "Conversation not found")
            }
        }
    }

    private func deepLinkErrorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            Button("Close", action: onDismiss)
                .foregroundColor(Theme.primaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }

    private func resolve() async {
        switch destination {
        case .product(let productId):
            do {
                let item = try await productService.getProduct(id: productId)
                await MainActor.run {
                    resolvedItem = item
                    loadError = item == nil ? "Product not found" : nil
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        case .user(let username):
            do {
                let user = try await userService.getUser(username: username)
                await MainActor.run {
                    resolvedUser = user
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                }
            }
        case .conversation(let conversationId, let username, _, _):
            do {
                let convs = try await chatService.getConversations()
                let existing = convs.first { $0.id == conversationId }
                if let conv = existing {
                    await MainActor.run {
                        resolvedConversation = conv
                        isLoading = false
                    }
                } else {
                    let placeholderUser = User(
                        id: UUID(),
                        username: username,
                        displayName: username,
                        avatarURL: nil
                    )
                    let conv = Conversation(
                        id: conversationId,
                        recipient: placeholderUser,
                        lastMessage: nil,
                        lastMessageTime: nil,
                        unreadCount: 0
                    )
                    await MainActor.run {
                        resolvedConversation = conv
                        isLoading = false
                    }
                }
            } catch {
                let placeholderUser = User(
                    id: UUID(),
                    username: username,
                    displayName: username,
                    avatarURL: nil
                )
                await MainActor.run {
                    resolvedConversation = Conversation(
                        id: conversationId,
                        recipient: placeholderUser,
                        lastMessage: nil,
                        lastMessageTime: nil,
                        unreadCount: 0
                    )
                    isLoading = false
                }
            }
        }
    }
}
