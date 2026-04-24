import SwiftUI
import UIKit

/// Username plus `VerifiedUserBadge`, cap-height sized; light vertical nudge from `HStack` centre using UIKit line metrics (tuned between baseline drift and over-offset).
struct UsernameWithVerifiedBadge: View {
    let username: String
    let verified: Bool
    var font: Font = .headline
    /// UIFont matching `font` (used for cap-height–based badge sizing and Dynamic Type).
    var referenceUIFont: UIFont = UIFont.preferredFont(forTextStyle: .headline)
    var textColor: Color = Theme.Colors.primaryText
    var spacing: CGFloat = 5

    /// Centre-aligned stacks read slightly high for this asset; a full `(line − cap) × 0.52` offset read low - use a smaller blend.
    private var verifiedBadgeOpticalDownshift: CGFloat {
        let lh = referenceUIFont.lineHeight
        let cap = referenceUIFont.capHeight
        return max(0, (lh - cap) * 0.22)
    }

    var body: some View {
        let badgeAspect: CGFloat = 16.0 / 15.0
        // Slightly above cap height - readable but not as tall as lineHeight (which looked oversized in the nav bar).
        let badgeH = referenceUIFont.capHeight * 1.14
        let badgeW = badgeH * badgeAspect
        HStack(alignment: .center, spacing: spacing) {
            Text(username)
                .font(font)
                .foregroundStyle(textColor)
                .lineLimit(1)
            if verified {
                Image("VerifiedUserBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: badgeW, height: badgeH)
                    .offset(y: verifiedBadgeOpticalDownshift)
                    .accessibilityLabel("Verified")
            }
        }
    }
}
