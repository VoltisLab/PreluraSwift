import SwiftUI

// MARK: - TLS / transport errors: compact snackbar (replaces large banner when `title` is non-nil)

/// Shown for secure-transport / TLS headline errors instead of ``FeedNetworkBannerView`` (fixed copy, compact bar).
struct FeedErrorSnackbarView: View {
    var onTryAgain: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Text(L10n.string("An error occurred, please try again."))
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onTryAgain {
                Button(L10n.string("Try again"), action: onTryAgain)
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryColor)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous)
                .strokeBorder(feedNetworkBannerBorderColor, lineWidth: feedNetworkBannerBorderWidth)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 8)
    }
}

/// Large card for generic network errors; for TLS / “Secure connection” use ``FeedErrorSnackbarView`` via this wrapper.
struct FeedNetworkErrorPresentation: View {
    let message: String
    let title: String?
    var onTryAgain: (() -> Void)? = nil
    /// When `true`, ``FeedNetworkBannerView`` adds extra horizontal margin outside the card (Home, Lookbook, etc.). Set `false` when the parent already supplies horizontal padding.
    var appliesOuterScreenGutter: Bool = true

    var body: some View {
        if title != nil {
            FeedErrorSnackbarView(onTryAgain: onTryAgain)
        } else {
            FeedNetworkBannerView(
                message: message,
                title: nil,
                onTryAgain: onTryAgain,
                appliesOuterScreenGutter: appliesOuterScreenGutter
            )
        }
    }
}

/// Shared border treatment for all feed network error banners/snackbars.
private let feedNetworkBannerBorderColor = Theme.Colors.secondaryText.opacity(0.22)
private let feedNetworkBannerBorderWidth: CGFloat = 1

/// Network / API error card: same inner surface as chat offer cards (`chatInlineCardBackground`), red accent on icon and border, `PrimaryGlassButton` for retry when `onTryAgain` is set.
struct FeedNetworkBannerView: View {
    let message: String
    /// Optional short headline (e.g. “Secure connection”) for TLS / branded transport errors.
    var title: String? = nil
    /// When set, shows a primary “Try again” action; otherwise shows a pull-to-refresh hint.
    var onTryAgain: (() -> Void)? = nil
    /// When `true`, adds horizontal margin **outside** the card so it does not sit flush to a padded parent. Use `false` in pre-padded debug / list rows.
    var appliesOuterScreenGutter: Bool = true

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
                .strokeBorder(feedNetworkBannerBorderColor, lineWidth: feedNetworkBannerBorderWidth)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
        /// Insets the card from screen edges when a parent is full-bleed; set `appliesOuterScreenGutter` false when the parent already has horizontal padding.
        .padding(.horizontal, appliesOuterScreenGutter ? Theme.Spacing.lg : 0)
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
