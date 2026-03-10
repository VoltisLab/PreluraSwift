import SwiftUI

/// Seller-side order issue details (Flutter SellerOrderIssueDetailsRoute). Shows issue and actions for seller.
struct SellerOrderIssueDetailsView: View {
    var issueId: Int
    var orderId: Int
    var publicId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Order issue #\(issueId)")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.primaryText)
                Text("A buyer has raised an issue for this order. Review the details and respond.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                NavigationLink(destination: HelpChatView()) {
                    Text("Contact support")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Order Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        SellerOrderIssueDetailsView(issueId: 1, orderId: 100, publicId: nil)
    }
}
