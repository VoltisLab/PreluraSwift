import SwiftUI

/// Three-screen intro for Try Cart (multi-seller bag): gradients, benefits, CTA.
struct TryCartOnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0
    @State private var glowPulse = false

    private struct TryCartPage: Identifiable {
        let id = UUID()
        let titleKey: String
        let bodyKey: String
        let icon: String
        let gradient: [Color]
        let start: UnitPoint
        let end: UnitPoint
    }

    private var pages: [TryCartPage] {
        [
            TryCartPage(
                titleKey: "One bag, many sellers",
                bodyKey: "Try Cart lets you add pieces from different shops into a single bag. Keep browsing—your picks stay with you everywhere on Prelura.",
                icon: "bag.fill",
                gradient: [
                    Color(hex: "1A0520"),
                    Theme.primaryColor.opacity(0.92),
                    Color(hex: "0D0612")
                ],
                start: .topLeading,
                end: .bottomTrailing
            ),
            TryCartPage(
                titleKey: "Save time on every haul",
                bodyKey: "No more jumping seller by seller. Search, tap the bag, and build your haul in one flow—with a running total so you always know where you stand.",
                icon: "bolt.fill",
                gradient: [
                    Color(hex: "12082A"),
                    Color(hex: "4B1D6E"),
                    Theme.primaryColor.opacity(0.55)
                ],
                start: .top,
                end: .bottom
            ),
            TryCartPage(
                titleKey: "Shop smarter, checkout clearer",
                bodyKey: "Use Try Cart from Shop All and favourites. Mix brands freely, review your bag anytime, then check out when you are ready—on your terms.",
                icon: "sparkles",
                gradient: [
                    Color(hex: "280018"),
                    Color(hex: "6B1E5C"),
                    Color(hex: "0A040E")
                ],
                start: .leading,
                end: .bottomTrailing
            )
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                    pageContent(p, pageIndex: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.white : Color.white.opacity(0.35))
                            .frame(width: i == page ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                    }
                }

                PrimaryButtonBar {
                    if page < pages.count - 1 {
                        PrimaryGlassButton(L10n.string("Next"), icon: "arrow.right") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                page += 1
                            }
                        }
                    } else {
                        PrimaryGlassButton(L10n.string("Start shopping"), icon: "hand.wave.fill", action: onComplete)
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.sm)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    @ViewBuilder
    private func pageContent(_ p: TryCartPage, pageIndex: Int) -> some View {
        ZStack {
            LinearGradient(colors: p.gradient, startPoint: p.start, endPoint: p.end)
                .ignoresSafeArea()

            // Soft light orbs
            Circle()
                .fill(Color.white.opacity(glowPulse ? 0.14 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: pageIndex == 1 ? -140 : 130, y: -220)

            Circle()
                .fill(Theme.primaryColor.opacity(glowPulse ? 0.35 : 0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: pageIndex == 0 ? -100 : 90, y: 280)

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)

                    Image(systemName: p.icon)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.bottom, Theme.Spacing.xl)

                Text(L10n.string("Try Cart"))
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.bottom, Theme.Spacing.sm)

                Text(L10n.string(p.titleKey))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .minimumScaleFactor(0.85)

                Text(L10n.string(p.bodyKey))
                    .font(Theme.Typography.body)
                    .foregroundColor(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)

                Spacer(minLength: 120)
            }
        }
    }
}

#Preview {
    TryCartOnboardingView(onComplete: {})
}
