import SwiftUI
import Shimmer

/// Minimal Home feed skeleton: a few large blocks + simple cards — avoids noisy micro-placeholders (`HomeView` hides the real nav while this shows).
struct FeedShimmerView: View {
    private let scrollBottomClearance: CGFloat = 112
    private let chipRowBottomSpacing: CGFloat = Theme.Spacing.md
    private let featuredCardWidth: CGFloat = 148

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topChromeShimmer
                searchFieldShimmer
                categoryFiltersShimmer
                featuredSectionShimmer
                productGridShimmer
                Color.clear.frame(height: scrollBottomClearance)
            }
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .background(Theme.Colors.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmering()
    }

    /// Toolbar-shaped strip: centred title + trailing notification slot (matches feed like-pill chrome, not the old AI + touching circle pair).
    private var topChromeShimmer: some View {
        ZStack {
            HStack {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 150, height: 22)
                Spacer(minLength: 0)
            }
            HStack(alignment: .center) {
                Spacer(minLength: 0)
                toolbarNotificationShimmerPill
                    .frame(height: Theme.SearchField.trailingActionSlotHeight, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// Same capsule treatment as `LikeButtonView` on product cards (dark translucent pill + inner glyph stub).
    private var toolbarNotificationShimmerPill: some View {
        HStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: 11, height: 13)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.6))
        )
        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
    }

    /// Solid search pill (no magnifier / text stubs).
    private var searchFieldShimmer: some View {
        Capsule(style: .continuous)
            .fill(Theme.Colors.secondaryBackground)
            .frame(height: Theme.SearchField.singleLineHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.xs)
    }

    private var categoryFiltersShimmer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Glass.tagCornerRadius, style: .continuous)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 64, height: 34)
                }
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xl)
        }
        .frame(maxHeight: 40, alignment: .top)
        .padding(.bottom, chipRowBottomSpacing)
    }

    private var featuredSectionShimmer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: 110, height: 18)
                .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        FeedHomeSimpleCardShimmer(fixedWidth: featuredCardWidth)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var productGridShimmer: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.sm),
                GridItem(.flexible(), spacing: Theme.Spacing.sm)
            ],
            alignment: .leading,
            spacing: Theme.Spacing.md,
            pinnedViews: []
        ) {
            ForEach(0..<8, id: \.self) { _ in
                FeedHomeSimpleCardShimmer(fixedWidth: nil)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: - Simple card (image + two lines only)

private struct FeedHomeSimpleCardShimmer: View {
    var fixedWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .aspectRatio(1.0 / 1.3, contentMode: .fit)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }
        }
        .frame(width: fixedWidth, alignment: .topLeading)
        .frame(maxWidth: fixedWidth == nil ? .infinity : nil, alignment: .topLeading)
    }
}
