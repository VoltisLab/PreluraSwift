import SwiftUI

/// Short labels for like/comment counts on lookbook feed rows so wide numbers do not clip the action bar.
enum LookbookFeedEngagementCountFormatting {
    /// Full phrase for comment count labels (e.g. feed preview line, accessibility).
    static func fullCommentCountPhrase(_ n: Int) -> String {
        if n == 1 { return L10n.string("1 Comment") }
        return String(format: L10n.string("%d comments"), n)
    }

    static func short(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        if n >= 1_000_000 {
            let m = Double(n) / 1_000_000.0
            let s = m >= 10 ? String(format: "%.0fM", m) : String(format: "%.1fM", m)
            return s.replacingOccurrences(of: ".0M", with: "M")
        }
        let k = Double(n) / 1000.0
        let s = k >= 100 ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
        return s.replacingOccurrences(of: ".0k", with: "k")
    }
}

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
    /// When set, replaces `\(likeCount)` so wide counts do not blow out feed toolbars (e.g. "12.4k").
    var likeCountFormatting: ((Int) -> String)? = nil
    /// When false, only the heart is shown (e.g. poster chose “Hide likes” on their lookbook post).
    var showLikeCount: Bool = true

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

    private var displayedLikeCount: String {
        if let format = likeCountFormatting { return format(likeCount) }
        return "\(likeCount)"
    }

    private var likePillContent: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: heartPointSize, weight: .medium))
            if showLikeCount {
                Text(displayedLikeCount)
                    .font(.system(size: likeCountPointSize, weight: .medium))
            }
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
