import SwiftUI

/// Shared like button: heart + count. Use on cards and detail for consistent design.
struct LikeButtonView: View {
    let isLiked: Bool
    let likeCount: Int
    let action: () -> Void
    /// When true, show on dark overlay (white icon when unliked). When false, use for light backgrounds (red when liked, primaryText when not).
    var onDarkOverlay: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .medium))
                Text("\(likeCount)")
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(isLiked ? .red : (onDarkOverlay ? .white : Theme.Colors.primaryText))
            .shadow(color: onDarkOverlay ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 1)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
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
        .buttonStyle(PlainButtonStyle())
        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.like() }))
    }
}
