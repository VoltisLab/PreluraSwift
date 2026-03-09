import SwiftUI

/// Identity verification — reimagined: hero, benefits, clear CTA.
struct VerifyIdentityView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero: icon + short headline
                VStack(spacing: Theme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.primaryColor.opacity(0.35),
                                        Theme.primaryColor.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.primaryColor)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    Text("Unlock your account")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Verify your identity to access all features and build trust with buyers.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.bottom, Theme.Spacing.xl)

                // Trust bullets
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    benefitRow(icon: "lock.open.fill", text: "Access selling and messaging")
                    benefitRow(icon: "heart.fill", text: "Build trust with buyers")
                    benefitRow(icon: "hand.raised.fill", text: "Keep your account secure")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.secondaryBackground.opacity(0.6))
                .cornerRadius(Theme.Glass.cornerRadius)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.lg)

                // CTA
                Button(action: {}) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Verify identity")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Identity verification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.primaryColor)
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
