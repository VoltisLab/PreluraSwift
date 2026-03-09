import SwiftUI

/// Order details: products, other party, total, status. Wired from My Orders list.
struct OrderDetailView: View {
    let order: Order

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                statusSection
                if let other = order.otherParty {
                    sectionHeader("Other party")
                    HStack(spacing: Theme.Spacing.sm) {
                        if let url = other.avatarURL, !url.isEmpty {
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: Rectangle().fill(Theme.Colors.tertiaryBackground)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(other.displayName)
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
                    .cornerRadius(Theme.Glass.cornerRadius)
                }
                sectionHeader("Items")
                ForEach(order.products) { p in
                    HStack(spacing: Theme.Spacing.md) {
                        productThumb(url: p.imageUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            if let price = p.price, !price.isEmpty {
                                Text("£\(price)")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Glass.cornerRadius)
                }
                sectionHeader("Summary")
                HStack {
                    Text("Total")
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
                .cornerRadius(Theme.Glass.cornerRadius)
                Text("Ordered \(dateFormatter.string(from: order.createdAt))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Order #\(order.id)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusSection: some View {
        HStack {
            Text("Status")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Spacer()
            Text(order.statusDisplay)
                .font(Theme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryColor)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.Glass.cornerRadius)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
            .padding(.top, Theme.Spacing.xs)
    }

    private func productThumb(url: String?) -> some View {
        Group {
            if let u = url, !u.isEmpty {
                AsyncImage(url: URL(string: u)) { phase in
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
