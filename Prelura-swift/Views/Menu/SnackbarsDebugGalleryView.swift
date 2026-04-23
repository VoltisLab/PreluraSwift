import SwiftUI

/// Debug: compact snackbar–style surfaces (bottom / floating), not full-width discover marketing strips.
/// Sources: `FeedErrorSnackbarView`, inbox archive undo (`ChatListView`), Lookbook save feedback, order/chat toasts, share sheet capsules.
struct SnackbarsDebugGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Compact bars and toasts used across the app (not Discover hero strips).")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)

                group(
                    title: "FeedErrorSnackbarView",
                    subtitle: "Home (TLS) & Profile when `errorBannerTitle` is set — text + purple Try again."
                ) {
                    FeedErrorSnackbarView(onTryAgain: {})
                }

                group(
                    title: "FeedErrorSnackbarView (no action)",
                    subtitle: "Same component when `onTryAgain` is nil."
                ) {
                    FeedErrorSnackbarView(onTryAgain: nil)
                }

                group(
                    title: "Inbox — archive undo",
                    subtitle: "After swipe archive on `ChatListView` (Archived + Undo)."
                ) {
                    SnackbarsDebugArchiveUndoRowPreview()
                }

                group(
                    title: "Lookbook — save feedback",
                    subtitle: "Capsule on post row when saving to a folder (`LookbookView`)."
                ) {
                    Text(String(format: L10n.string("Saved to %@"), "Favourites"))
                        .font(Theme.Typography.subheadline.weight(.medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .center)

                group(
                    title: "Order help — Copied",
                    subtitle: "`OrderHelpView` bottom overlay when copying tracking link."
                ) {
                    Text("Copied")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.black.opacity(0.82))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .center)

                group(
                    title: "Order detail — tracking copied",
                    subtitle: "Small capsule on shipping card when tracking is copied."
                ) {
                    Text("Tracking copied")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                group(
                    title: "Share profile sheet — link copied / export",
                    subtitle: "`ShareProfileLinkSheet` top inline capsules."
                ) {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(L10n.string("Link copied"))
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.primaryColor)
                            .clipShape(Capsule())
                        Text(L10n.string("Image saved to Photos"))
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.9))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                group(
                    title: "Inbox — load error (bottom bar)",
                    subtitle: "Empty state uses `PrimaryButtonBar` + Retry (`ChatListView`)."
                ) {
                    VStack(spacing: 0) {
                        Text("Couldn’t load conversations")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        PrimaryButtonBar {
                            PrimaryGlassButton("Retry", action: {})
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Snackbars gallery")
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

// MARK: - Inbox archive undo (same layout as `ChatListView.ArchiveUndoToast`)

private struct SnackbarsDebugArchiveUndoRowPreview: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(L10n.string("Archived"))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer(minLength: 8)
            Button(L10n.string("Undo"), action: {})
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundColor(Theme.primaryColor)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .frame(minHeight: Theme.AppBar.buttonSize - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .shadow(color: Color.black.opacity(0.28), radius: 14, y: 5)
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SnackbarsDebugGalleryView()
    }
    .preferredColorScheme(.dark)
}
#endif
