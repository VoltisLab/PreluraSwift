import SwiftUI

/// Shared like button: heart + count. Use on product cards and detail for consistent design.
/// Hit target is at least 56×56 pt and expands with the pill so the count remains tappable.
struct LikeButtonView: View {
    let isLiked: Bool
    let likeCount: Int
    let action: () -> Void
    /// When true, show on dark overlay (white icon when unliked). When false, use for light backgrounds (red when liked, primaryText when not).
    var onDarkOverlay: Bool = true
    /// Heart glyph size; match adjacent toolbar/row icons on feeds (e.g. 20).
    var heartPointSize: CGFloat = 14

    private static let minTapSize: CGFloat = 56

    private var likeCountPointSize: CGFloat {
        heartPointSize <= 14 ? 14 : 15
    }

    var body: some View {
        Button {
            HapticManager.like()
            action()
        } label: {
            likePillContent
        }
        // Match icon rows in ScrollViews (e.g. Lookbook): plain style + full label hit area.
        // Default/HapticTap styles have been unreliable next to TabView + LazyVStack.
        .buttonStyle(PlainTappableButtonStyle())
        .frame(minWidth: Self.minTapSize, minHeight: Self.minTapSize, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var likePillContent: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: heartPointSize, weight: .medium))
            Text("\(likeCount)")
                .font(.system(size: likeCountPointSize, weight: .medium))
        }
        .foregroundColor(isLiked ? .red : (onDarkOverlay ? .white : Theme.Colors.primaryText))
        .shadow(color: onDarkOverlay ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Group {
                if onDarkOverlay {
                    Capsule().fill(Color.black.opacity(0.6))
                } else {
                    Color.clear
                }
            }
        )
    }
}
