import SwiftUI

/// Order details: status, seller/buyer, items, summary. Matches reference design with section labels and rounded cards.
struct OrderDetailView: View {
    let order: Order
    /// When viewing from My Orders: true = sold (so other party is Buyer), false = bought (so other party is Seller). When nil (e.g. from chat), section shows "Other party".
    var isSeller: Bool? = nil

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    /// Section label for the other party: "Seller", "Buyer", or "Other party".
    private var otherPartySectionTitle: String {
        guard let isSeller = isSeller else { return L10n.string("Other party") }
        return isSeller ? L10n.string("Buyer") : L10n.string("Seller")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Status: label above, then single card with status text in purple
                sectionLabel(L10n.string("Status"))
                statusCard

                if order.otherParty != nil {
                    sectionLabel(otherPartySectionTitle)
                    otherPartyCard
                }

                sectionLabel(L10n.string("Items"))
                itemsSection

                sectionLabel(L10n.string("Summary"))
                summaryCard

                if let addr = order.shippingAddress, !formatShippingAddress(addr).isEmpty {
                    sectionLabel(L10n.string("Shipping Address"))
                    shippingAddressCard(addr)
                }

                Text("Ordered \(dateFormatter.string(from: order.createdAt))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Order #\(order.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
    }

    private var statusCard: some View {
        Text(order.statusDisplay)
            .font(Theme.Typography.body)
            .fontWeight(.medium)
            .foregroundColor(Theme.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private var otherPartyCard: some View {
        Group {
            if let other = order.otherParty {
                HStack(spacing: Theme.Spacing.md) {
                    avatarView(url: other.avatarURL, username: other.username)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(other.displayName.isEmpty ? other.username : other.displayName)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("@\(other.username)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
            }
        }
    }

    private func avatarView(url: String?, username: String) -> some View {
        Group {
            if let u = url, !u.isEmpty, let parsed = URL(string: u) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholderAvatar(username: username)
                    }
                }
            } else {
                placeholderAvatar(username: username)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func placeholderAvatar(username: String) -> some View {
        Circle()
            .fill(Theme.Colors.tertiaryBackground)
            .overlay(
                Text(String((username.isEmpty ? "?" : username).prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            )
    }

    private var itemsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(order.products) { product in
                HStack(spacing: Theme.Spacing.md) {
                    productThumb(url: product.imageUrl)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        if let price = product.price, !price.isEmpty {
                            Text("£\(price)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
            }
        }
    }

    private var summaryCard: some View {
        HStack {
            Text(L10n.string("Total"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Text("£\(order.priceTotal)")
                .font(Theme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.primaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private func shippingAddressCard(_ addr: ShippingAddress) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if !addr.address.isEmpty {
                Text(addr.address)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                if !addr.city.isEmpty {
                    Text(addr.city)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                if let state = addr.state, !state.isEmpty {
                    Text(state)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                if !addr.postcode.isEmpty {
                    Text(addr.postcode)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            if !addr.country.isEmpty {
                Text(addr.country)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private func formatShippingAddress(_ addr: ShippingAddress) -> String {
        var parts: [String] = []
        if !addr.address.isEmpty { parts.append(addr.address) }
        if !addr.city.isEmpty { parts.append(addr.city) }
        if let state = addr.state, !state.isEmpty { parts.append(state) }
        if !addr.postcode.isEmpty { parts.append(addr.postcode) }
        if !addr.country.isEmpty { parts.append(addr.country) }
        return parts.joined(separator: ", ")
    }

    private func productThumb(url: String?) -> some View {
        Group {
            if let u = url, !u.isEmpty, let parsed = URL(string: u) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Rectangle().fill(Theme.Colors.tertiaryBackground)
                    }
                }
            } else {
                Rectangle()
                    .fill(Theme.Colors.tertiaryBackground)
                    .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .cornerRadius(8)
    }
}
