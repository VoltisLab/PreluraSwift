import SwiftUI

/// Network / API error card: same inner surface as chat offer cards (`chatInlineCardBackground`), red accent on icon and border, `PrimaryGlassButton` for retry when `onTryAgain` is set.
struct FeedNetworkBannerView: View {
    let message: String
    /// Optional short headline (e.g. “Secure connection”) for TLS / branded transport errors.
    var title: String? = nil
    /// When set, shows a primary “Try again” action; otherwise shows a pull-to-refresh hint.
    var onTryAgain: (() -> Void)? = nil

    private let iconColumnSize: CGFloat = 56
    private let iconGlyphSize: CGFloat = 22

    private var bannerIconName: String {
        if title != nil { return "lock.trianglebadge.exclamationmark" }
        return "wifi.exclamationmark"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md + 2) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.error.opacity(0.2))
                    Image(systemName: bannerIconName)
                        .font(.system(size: iconGlyphSize, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.Colors.error)
                }
                .frame(width: iconColumnSize, height: iconColumnSize)

                VStack(alignment: .leading, spacing: 8) {
                    if let title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.error.opacity(0.9))
                            .textCase(.uppercase)
                            .tracking(0.55)
                    }
                    Text(message)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let onTryAgain {
                PrimaryGlassButton(L10n.string("Try again"), icon: "arrow.clockwise", action: onTryAgain)
            } else {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Text(L10n.string("Pull down to refresh"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.lg + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous)
                .fill(Theme.Colors.chatInlineCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous)
                .strokeBorder(Theme.Colors.error.opacity(0.88), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
        /// Insets the card from screen edges; without this, `frame(maxWidth: .infinity)` paints edge-to-edge.
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

#Preview("With retry") {
    FeedNetworkBannerView(
        message: L10n.string("Connection timed out. Please try again."),
        onTryAgain: {}
    )
    .padding(.vertical)
    .frame(maxWidth: .infinity)
    .background(Theme.Colors.background)
    .preferredColorScheme(.dark)
}

#Preview("Hint only") {
    FeedNetworkBannerView(
        message: L10n.string("Unable to connect. Please check your internet connection.")
    )
    .padding(.vertical)
    .frame(maxWidth: .infinity)
    .background(Theme.Colors.background)
    .preferredColorScheme(.dark)
}
