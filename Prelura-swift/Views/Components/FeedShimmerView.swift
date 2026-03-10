import SwiftUI

struct FeedShimmerView: View {
    var body: some View {
        GeometryReader { geometry in
            let minHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            VStack(spacing: 0) {
                // Header shimmer
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 100, height: 28)
                    Spacer()
                    Circle()
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                
                // Search bar shimmer
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 44)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xs)
                
                // Category filters shimmer
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 60, height: 36)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)
                
                // Product grid shimmer
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                        GridItem(.flexible(), spacing: Theme.Spacing.sm)
                    ],
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(0..<6) { _ in
                        FeedItemShimmer()
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: minHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shimmer()
        }
        .frame(minHeight: UIScreen.main.bounds.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .all))
    }
}

struct FeedItemShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Seller info shimmer
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
            
            // Image shimmer
            GeometryReader { geometry in
                let imageWidth = geometry.size.width
                let imageHeight = imageWidth * 1.3
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: imageWidth, height: imageHeight)
            }
            .aspectRatio(1.0/1.3, contentMode: .fit)
            
            // Product details shimmer
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
