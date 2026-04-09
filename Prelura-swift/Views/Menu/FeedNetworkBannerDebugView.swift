import SwiftUI

/// Debug: same `FeedNetworkBannerView` as Home feed (timeout + offline + hint-only).
struct FeedNetworkBannerDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("These use the same component as the Home feed error card (centered on Home when shown).")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Connection timed out (with Try again)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    FeedNetworkBannerView(
                        message: L10n.string("Connection timed out. Please try again."),
                        onTryAgain: {}
                    )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Offline message (with Try again)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    FeedNetworkBannerView(
                        message: L10n.string("Unable to connect. Please check your internet connection."),
                        onTryAgain: {}
                    )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Pull-to-refresh hint only (no button)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    FeedNetworkBannerView(
                        message: L10n.string("Connection timed out. Please try again."),
                        onTryAgain: nil
                    )
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Feed network banner")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FeedNetworkBannerDebugView()
    }
    .preferredColorScheme(.dark)
}
