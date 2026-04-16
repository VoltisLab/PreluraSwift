import SwiftUI
import UIKit

/// Username plus `VerifiedUserBadge`, vertically centered to the text’s **line box** (not just cap height).
struct UsernameWithVerifiedBadge: View {
    let username: String
    let verified: Bool
    var font: Font = .headline
    /// UIFont whose `lineHeight` matches `font` (used to size the badge container so the asset centers with the text).
    var referenceUIFont: UIFont = UIFont.preferredFont(forTextStyle: .headline)
    var textColor: Color = Theme.Colors.primaryText
    var spacing: CGFloat = 5

    var body: some View {
        let lineH = referenceUIFont.lineHeight
        let badgeAspect: CGFloat = 16.0 / 15.0
        HStack(alignment: .center, spacing: spacing) {
            Text(username)
                .font(font)
                .foregroundStyle(textColor)
                .lineLimit(1)
            if verified {
                Image("VerifiedUserBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: lineH * badgeAspect, height: lineH)
                    .accessibilityLabel("Verified")
            }
        }
    }
}
