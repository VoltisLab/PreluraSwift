import SwiftUI

/// In-conversation order help menu (Flutter OrderHelpScreen). Options: Item not as described, Order status, Tracking, Payment issues, Item not received.
struct OrderHelpView: View {
    var orderId: String?
    var conversationId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Need help with your order?")
                    .font(Theme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)

                helpRow(
                    title: "Item Not as Described",
                    content: "If the item you received doesn't match the description, you can raise an issue within 3 days of delivery.",
                    destination: ItemNotAsDescribedHelpView(orderId: orderId, conversationId: conversationId)
                )
                helpRow(
                    title: "Order Status",
                    content: "Track your order status and see where your item is in the delivery process.",
                    destination: HelpChatView()
                )
                helpRow(
                    title: "Tracking Information",
                    content: "If your item has been shipped, you can track it using the tracking number provided by the seller.",
                    destination: HelpChatView()
                )
                helpRow(
                    title: "Payment Issues",
                    content: "If you're experiencing payment issues, please contact our support team.",
                    destination: HelpChatView()
                )
                helpRow(
                    title: "Item Not Received",
                    content: "If you haven't received your item within the expected delivery window, we can help.",
                    destination: HelpChatView()
                )
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Help with Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func helpRow<D: View>(title: String, content: String, destination: D) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(content)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.Glass.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        OrderHelpView(orderId: nil, conversationId: nil)
    }
}
