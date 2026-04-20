import SwiftUI
import Shimmer

/// Full-screen discover shimmer using SwiftUI-Shimmer. Covers title and nav bar area; extends under safe area.
struct DiscoverShimmerView: View {
    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 0) {
                    // Nav bar + title (member search uses the real navigation bar searchable)
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(height: topInset + 44)
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: Theme.Spacing.lg) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(0..<10, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                                        .fill(Theme.Colors.secondaryBackground)
                                        .frame(width: 80, height: 36)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        .padding(.bottom, Theme.Spacing.sm)

                        // Category circles
                        HStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { index in
                                VStack(spacing: Theme.Spacing.xs) {
                                    Circle()
                                        .fill(Theme.Colors.secondaryBackground)
                                        .frame(width: 70, height: 70)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.Colors.secondaryBackground)
                                        .frame(width: 50, height: 12)
                                }
                                .frame(width: 80)
                                if index != 3 { Spacer() }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)

                        // Section placeholder
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 120, height: 20)
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 60, height: 16)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        DiscoverItemShimmer()
                                            .frame(width: 160)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .shimmering()
            }
            .scrollDisabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .all))
    }
}

/// Horizontal product strip (Recently viewed, Brands, Bargains, On Sale) while that section’s data loads.
struct DiscoverSectionProductStripShimmer: View {
    var showSeeAllPlaceholder: Bool = true
    var subtitlePlaceholderHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 160, height: 20)
                    if subtitlePlaceholderHeight > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(width: 220, height: subtitlePlaceholderHeight)
                    }
                }
                Spacer(minLength: 0)
                if showSeeAllPlaceholder {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 52, height: 16)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(0..<5, id: \.self) { _ in
                        DiscoverItemShimmer()
                            .frame(width: 160)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmering()
    }
}

/// Top Shops row placeholder (avatars + usernames).
struct DiscoverTopShopsSectionShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 100, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 240, height: 12)
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<5, id: \.self) { _ in
                        VStack(spacing: Theme.Spacing.xs) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 100, height: 100)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 72, height: 12)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmering()
    }
}

private struct DiscoverItemShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 60, height: 12)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs * 1.5)
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.Colors.secondaryBackground)
                .aspectRatio(1.0/1.3, contentMode: .fit)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 50, height: 14)
                    .padding(.top, Theme.Spacing.sm)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 80, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 40, height: 14)
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
    }
}
