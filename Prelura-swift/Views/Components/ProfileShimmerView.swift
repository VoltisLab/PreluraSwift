import SwiftUI

struct ProfileShimmerView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header shimmer
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 100, height: 20)
                    Spacer()
                    Circle()
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                
                // Profile section shimmer
                VStack(spacing: Theme.Spacing.md) {
                    // Avatar shimmer
                    Circle()
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 100, height: 100)
                    
                    // Username shimmer
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 120, height: 20)
                    
                    // Bio shimmer
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(width: 200, height: 14)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.md)
                
                // Stats shimmer
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<5) { _ in
                        VStack(spacing: Theme.Spacing.xs) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 40, height: 20)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 50, height: 12)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                
                // Filters shimmer
                VStack(spacing: Theme.Spacing.sm) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(0..<5) { _ in
                                RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 80, height: 36)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
                
                // Product grid shimmer
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                        GridItem(.flexible(), spacing: Theme.Spacing.sm)
                    ],
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(0..<6) { _ in
                        ProfileItemShimmer()
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: UIScreen.main.bounds.height)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .all)
        .background(Theme.Colors.background)
        .shimmer()
    }
}

struct ProfileItemShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
        }
    }
}
