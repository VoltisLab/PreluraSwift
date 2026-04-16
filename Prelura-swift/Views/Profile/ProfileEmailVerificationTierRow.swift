import SwiftUI

/// Email verification line plus optional Pro / Elite badge (staff-set `profileTier` from the API).
struct ProfileEmailVerificationTierRow: View {
    let isVerified: Bool
    let profileTier: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: isVerified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isVerified ? Color.green : Theme.Colors.secondaryText)
                Text(isVerified ? L10n.string("Email verified") : L10n.string("Email not verified"))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            Spacer(minLength: 8)
            tierBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var tierBadge: some View {
        let t = profileTier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t == "PRO" {
            Text("Pro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.primaryColor, in: Capsule())
                .accessibilityLabel("Pro")
        } else if t == "ELITE" {
            Text("Elite")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.4),
                            Color(red: 0.93, green: 0.72, blue: 0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .accessibilityLabel("Elite")
        }
    }
}
