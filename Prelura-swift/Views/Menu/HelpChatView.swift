import SwiftUI

struct SupportIssueDraft {
    let selectedOptions: [String]
    let description: String
    let imageDatas: [Data]
    let issueTypeCode: String?
    let issueId: Int?
    let issuePublicId: String?
}

private struct SupportChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let createdAt: Date
}

private struct SupportOrderProductHeader: View {
    let item: Item
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Group {
                    if let firstUrl = item.imageURLs.first, let url = URL(string: firstUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                Rectangle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Theme.Colors.secondaryBackground)
                            .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.formattedPrice)
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.primaryColor)
                    Text("Related order item")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

/// Help Chat View (from Flutter help_chat_view). Chat-like support conversation with order issue context.
struct HelpChatView: View {
    var orderId: String? = nil
    var conversationId: String? = nil
    var issueDraft: SupportIssueDraft? = nil

    @EnvironmentObject var authService: AuthService
    @State private var newMessage = ""
    @State private var chatMessages: [SupportChatMessage] = []
    @State private var relatedItem: Item?
    @State private var relatedProductId: Int?
    @State private var isLoadingHeaderProduct = false
    @State private var productHeaderError: String?
    private let userService = UserService()
    private let productService = ProductService()

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let item = relatedItem {
                NavigationLink(destination: ItemDetailView(item: item)) {
                    SupportOrderProductHeader(item: item) { }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
            } else if isLoadingHeaderProduct {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
            } else if let err = productHeaderError, !err.isEmpty {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.sm) {
                        issueSummaryCard

                        ForEach(chatMessages) { message in
                            HStack {
                                if message.isFromUser { Spacer(minLength: Theme.Spacing.lg) }
                                Text(message.text)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(message.isFromUser ? .white : Theme.Colors.primaryText)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .background(message.isFromUser ? Theme.primaryColor : Theme.Colors.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                if !message.isFromUser { Spacer(minLength: Theme.Spacing.lg) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.sm)
                }
                .onChange(of: chatMessages.count) { _, _ in
                    if let lastId = chatMessages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            messageComposer
        }
        .background(Theme.Colors.background)
        .navigationTitle("Help Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await bootstrapSupportChat()
            await loadRelatedOrderProduct()
        }
    }

    @ViewBuilder
    private var issueSummaryCard: some View {
        if issueDraft != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Issue details shared with support")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)

                if let issueDraft, !issueDraft.selectedOptions.isEmpty {
                    Text(issueDraft.selectedOptions.joined(separator: ", "))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }

                if let issueDraft, !issueDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(issueDraft.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primaryText)
                }

                if let issueDraft, !issueDraft.imageDatas.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(Array(issueDraft.imageDatas.enumerated()), id: \.offset) { _, data in
                                if let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
        }
    }

    private var messageComposer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Type a message...", text: $newMessage)
                .textFieldStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 12)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(Capsule())

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Theme.primaryColor)
                    .clipShape(Circle())
            }
            .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func bootstrapSupportChat() async {
        if chatMessages.isEmpty {
            let starter = issueDraft?.selectedOptions.first ?? "Order support request"
            await MainActor.run {
                chatMessages = [
                    SupportChatMessage(
                        text: "Support: Thanks for reaching out. We received your \(starter.lowercased()) details. We'll respond within 24-72 hrs.",
                        isFromUser: false,
                        createdAt: Date()
                    )
                ]
            }
        }
    }

    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatMessages.append(SupportChatMessage(text: text, isFromUser: true, createdAt: Date()))
        newMessage = ""
    }

    private func loadRelatedOrderProduct() async {
        guard let orderId, !orderId.isEmpty else { return }
        await MainActor.run {
            isLoadingHeaderProduct = true
            productHeaderError = nil
        }

        userService.updateAuthToken(authService.authToken)
        productService.updateAuthToken(authService.authToken)

        do {
            async let sellerOrdersTask = userService.getUserOrders(isSeller: true)
            async let buyerOrdersTask = userService.getUserOrders(isSeller: false)
            let (sellerOrders, buyerOrders) = try await (sellerOrdersTask, buyerOrdersTask)
            let allOrders = sellerOrders.orders + buyerOrders.orders
            guard let matchedOrder = allOrders.first(where: { $0.id == orderId }),
                  let firstOrderProduct = matchedOrder.products.first else {
                await MainActor.run {
                    isLoadingHeaderProduct = false
                    productHeaderError = "Related product unavailable"
                }
                return
            }
            guard let pid = Int(firstOrderProduct.id) else {
                await MainActor.run {
                    isLoadingHeaderProduct = false
                    productHeaderError = "Related product unavailable"
                }
                return
            }
            let product = try await productService.getProduct(id: pid)
            await MainActor.run {
                relatedProductId = pid
                relatedItem = product
                isLoadingHeaderProduct = false
                if relatedItem == nil {
                    productHeaderError = "Related product unavailable"
                }
            }
        } catch {
            await MainActor.run {
                isLoadingHeaderProduct = false
                productHeaderError = "Could not load related product"
            }
        }
    }
}
