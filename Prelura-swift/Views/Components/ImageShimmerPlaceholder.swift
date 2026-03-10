import SwiftUI

/// Shimmer placeholder for image thumbnails while loading. Use in AsyncImage empty/loading state across the app.
struct ImageShimmerPlaceholder: View {
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.Colors.secondaryBackground)
            .shimmer()
    }
}

/// Shimmer placeholder that fills the given size (for use in GeometryReader or fixed frame).
struct ImageShimmerPlaceholderFilled: View {
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.Colors.secondaryBackground)
            .shimmer()
    }
}
