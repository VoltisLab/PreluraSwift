import SwiftUI

/// Debug-only like control (same chrome as “Like button only”). Not `LikeButtonView`; isolated for hit-testing checks.
struct DebugSandboxLikeButton: View {
    var isLiked: Bool
    var likeCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isLiked ? Color.red : Theme.Colors.primaryText)
                Text("\(likeCount)")
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
