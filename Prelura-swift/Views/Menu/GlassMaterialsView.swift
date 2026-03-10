import SwiftUI

/// Debug screen: Liquid Glass buttons per [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).
/// Shows glass-effect buttons over a vibrant background so the frosted effect is visible, plus a solid button for comparison.
struct GlassMaterialsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Rich background strip so glass shows through (like Apple's reference image)
                glassButtonsSection
                // Labels for reference
                labelsSection
            }
            .padding(Theme.Spacing.lg)
        }
        .background(glassDemoBackground)
        .navigationTitle("Glass materials")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    /// Horizontal strip of three buttons: two with Liquid Glass, one solid (per Apple's doc image).
    private var glassButtonsSection: some View {
        GlassEffectContainer(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                // Left: Liquid Glass (regular)
                Button(action: {}) {
                    Text("Hello, World!")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))

                // Middle: Liquid Glass (clear / more transparent)
                Button(action: {}) {
                    Text("Hello, World!")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear, in: .rect(cornerRadius: 12))

                // Right: Solid (no glass) for comparison
                Button(action: {}) {
                    Text("Hello, World!")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Glass (regular)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Text("Glass (clear)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Text("Solid (no glass)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Gradient background so the liquid glass effect is visible (pink → green → blue, like Apple's reference).
    private var glassDemoBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.4, blue: 0.5),
                Color(red: 0.3, green: 0.7, blue: 0.35),
                Color(red: 0.25, green: 0.5, blue: 0.95)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            LinearGradient(
                colors: [.black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}
