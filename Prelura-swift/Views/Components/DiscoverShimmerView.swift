import SwiftUI

struct DiscoverShimmerView: View {
    var body: some View {
        GeometryReader { geometry in
            let minHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            ScrollView {
                VStack(spacing: 0) {
                    // Header shimmer
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.Colors.secondaryBackground)
                            .frame(width: 100, height: 28)
                        Spacer()
                        HStack(spacing: Theme.Spacing.md) {
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    
                    // Search bar shimmer
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(height: 44)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, 0)
                    
                    VStack(spacing: Theme.Spacing.lg) {
                        // Brand filters shimmer (single row)
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
                        .padding(.top, 0)
                        .padding(.bottom, Theme.Spacing.sm)
                        
                        // Category circles shimmer
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
                                
                                if index != 3 {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        
                        // Section shimmer (Recently viewed)
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
                                    ForEach(0..<5) { _ in
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
                .frame(minHeight: minHeight)
                .frame(maxWidth: .infinity)
            }
            .shimmer()
        }
        .frame(minHeight: UIScreen.main.bounds.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea(edges: .all))
    }
}

struct DiscoverItemShimmer: View {
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
        }
    }
}
