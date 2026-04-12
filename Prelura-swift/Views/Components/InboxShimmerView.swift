import SwiftUI
import Shimmer

/// Full-screen Messages shimmer: matches ChatListView layout (nav + conversation rows; search is in the nav bar).
struct InboxShimmerView: View {
    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            VStack(spacing: 0) {
                // Nav bar + title (search field is part of the real navigation bar)
                RoundedRectangle(cornerRadius: 0)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: topInset + 44)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)

                // Conversation list (matches ChatRowView: avatar 50, name+time, message preview)
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        InboxRowShimmer()
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background.ignoresSafeArea(edges: .all))
            .shimmering()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One row matching ChatRowView: 50pt avatar, name + time on one line, message preview below.
private struct InboxRowShimmer: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 100, height: 16)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 48, height: 12)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}
