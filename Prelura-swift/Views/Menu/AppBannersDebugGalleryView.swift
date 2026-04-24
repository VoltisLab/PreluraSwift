import SwiftUI

/// Debug: full-width and card-style **banners** (errors, info strips) - not Discover lookbook/try-cart marketing heroes.
struct AppBannersDebugGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Network / info banners and cards (excludes Discover main marketing strips: Try Cart, Vintage, shop-by-style tiles).")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                group(
                    title: "FeedNetworkBannerView - timeout + Try again",
                    subtitle: "Home, Featured, Profile (no TLS headline), Lookbook/Filtered when `title` is nil."
                ) {
                    FeedNetworkBannerView(
                        message: L10n.string("Connection timed out. Please try again."),
                        onTryAgain: {},
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "FeedNetworkBannerView - offline + Try again",
                    subtitle: "Mapped `L10n.userFacingError` for -1009 / similar."
                ) {
                    FeedNetworkBannerView(
                        message: L10n.string("Unable to connect. Please check your internet connection."),
                        onTryAgain: {},
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "FeedNetworkBannerView - pull to refresh only",
                    subtitle: "When `onTryAgain` is nil (same card, hint row)."
                ) {
                    FeedNetworkBannerView(
                        message: L10n.string("Connection timed out. Please try again."),
                        onTryAgain: nil,
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "FeedNetworkBannerView - optional TLS title on card",
                    subtitle: "Component supports `title` (lock icon); production TLS often uses snackbar instead."
                ) {
                    FeedNetworkBannerView(
                        message: L10n.string("We couldn't complete a secure connection. Please try again shortly."),
                        title: L10n.string("Secure connection"),
                        onTryAgain: {},
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "FeedNetworkErrorPresentation - card (no title)",
                    subtitle: "Lookbook feed, user profile, filtered products when no TLS headline."
                ) {
                    FeedNetworkErrorPresentation(
                        message: L10n.string("Unable to connect. Please check your internet connection."),
                        title: nil,
                        onTryAgain: {},
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "FeedNetworkErrorPresentation - compact snackbar path",
                    subtitle: "When `userFacingErrorBannerTitle` is non-nil (TLS) - same as `FeedErrorSnackbarView` in production today."
                ) {
                    FeedNetworkErrorPresentation(
                        message: L10n.string("We couldn't complete a secure connection. Please try again shortly."),
                        title: L10n.string("Secure connection"),
                        onTryAgain: {},
                        appliesOuterScreenGutter: false
                    )
                }

                group(
                    title: "Chat - support / moderation strip",
                    subtitle: "Profanity or support text banner under product header in `ChatDetailView`."
                ) {
                    AppBannersDebugChatSupportStripPreview()
                }

                group(
                    title: "Sell - postage info strip",
                    subtitle: "Info `HStack` on sell flow: primary tint on `Theme.primaryColor.opacity(0.1)`."
                ) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.primaryColor)
                        Text(L10n.string("The buyer always pays for postage."))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.primaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.primaryColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                group(
                    title: "Forum - guest banner",
                    subtitle: "`ForumTopicDetailView` when not signed in."
                ) {
                    Text(L10n.string("Sign in to vote or comment."))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(Theme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.primaryColor.opacity(0.12))
                        .cornerRadius(8)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Banners gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func group<Content: View>(title: String, subtitle: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryText)
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
            content()
        }
    }
}

// MARK: - Chat support strip (layout from ChatDetailView)

private struct AppBannersDebugChatSupportStripPreview: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "lifepreserver.fill")
                .foregroundStyle(Theme.primaryColor)
                .padding(.top, 2)
            Text("Example support or moderation message shown above the message list when returned by the server.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primaryColor.opacity(0.14))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AppBannersDebugGalleryView()
    }
    .preferredColorScheme(.dark)
}
#endif
