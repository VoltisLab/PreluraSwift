import SwiftUI

/// Cart-like list of items selected for multi-buy, with checkout button at the bottom.
/// Uses binding so removing an item updates the parent's selection and this view re-renders.
struct MultiBuyCartView: View {
    @Binding var selectedIds: Set<String>
    let allItems: [Item]

    private var items: [Item] {
        allItems.filter { selectedIds.contains($0.id.uuidString) }
    }

    private var totalPrice: Double {
        items.reduce(0) { $0 + $1.price }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        cartRow(item: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.background)

            // Checkout bar at bottom
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text(L10n.string("Price"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                    Text(String(format: "£%.2f", totalPrice))
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)

                PrimaryGlassButton(L10n.string("Checkout"), icon: "creditcard", action: {})
                    .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.background)
        }
        .navigationTitle(L10n.string("View bag"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cartRow(item: Item) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Thumbnail
            Group {
                if let first = item.imageURLs.first, let url = URL(string: first) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.primaryColor.opacity(0.2))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(Theme.primaryColor.opacity(0.5))
                                )
                        @unknown default:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.primaryColor.opacity(0.2))
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.primaryColor.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.primaryColor.opacity(0.5))
                        )
                }
            }
            .frame(width: 72, height: 72 * 1.3)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let brand = item.brand {
                    Text(brand)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.primaryColor)
                }
                Text(item.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(2)
                Text(item.formattedPrice)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                HapticManager.selection()
                selectedIds.remove(item.id.uuidString)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                .fill(Theme.Colors.secondaryBackground)
        )
        .padding(.vertical, Theme.Spacing.xs)
    }
}
