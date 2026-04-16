import SwiftUI

/// Three-page Lookbooks intro (same interaction model as Try Cart onboarding).
struct LookbooksOnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0
    @State private var breathe = false
    @State private var contentAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct LookbooksPage: Identifiable {
        let id = UUID()
        let titleKey: String
        let bodyKey: String
        let systemImage: String
        let accent: Color
        let halo: Color
    }

    private let tabPageHeight: CGFloat = 408

    private var pages: [LookbooksPage] {
        [
            LookbooksPage(
                titleKey: "Share your fits",
                bodyKey: "Lookbook posts are outfit photos with tags and style. Show how you wear pieces and inspire the community.",
                systemImage: "photo.on.rectangle.angled",
                accent: Theme.primaryColor,
                halo: Color(hex: "E8B4FF")
            ),
            LookbooksPage(
                titleKey: "Tag what you wear",
                bodyKey: "Link products on your photos so others can shop the look. Your tagged items appear for viewers in one tap.",
                systemImage: "tag",
                accent: Color(hex: "C77DFF"),
                halo: Color(hex: "7C5CFF")
            ),
            LookbooksPage(
                titleKey: "Browse Feed and Explore",
                bodyKey: "Catch the latest looks in Feed, dive into styles and themes in Explore, and revisit your uploads in My items.",
                systemImage: "square.grid.2x2",
                accent: Color(hex: "FF6B9D"),
                halo: Theme.primaryColor
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                    pageContent(p)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: tabPageHeight)
            .onChange(of: page) { _, _ in
                HapticManager.selection()
                if !reduceMotion {
                    contentAppeared = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        contentAppeared = true
                    }
                }
            }

            bottomChrome
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)
        }
        .background { cardBackground }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                breathe = true
            }
            contentAppeared = true
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "07040C"),
                    Color(hex: "12081C"),
                    Color(hex: "0A0610")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Theme.primaryColor.opacity(breathe ? 0.32 : 0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 200
            )

            RadialGradient(
                colors: [
                    Color(hex: "4B1D6E").opacity(breathe ? 0.28 : 0.16),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 8,
                endRadius: 180
            )

            Rectangle()
                .fill(Color.white.opacity(0.025))
                .blendMode(.overlay)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WEARHOUSE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.42))
                Text(L10n.string("Lookbook"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            Text("\(page + 1) / \(pages.count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            Spacer(minLength: 8)
            Button {
                HapticManager.tap()
                onComplete()
            } label: {
                Text(L10n.string("Skip"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Skip"))
        }
    }

    @ViewBuilder
    private func pageContent(_ p: LookbooksPage) -> some View {
        let scale: CGFloat = contentAppeared ? 1 : (reduceMotion ? 1 : 0.96)
        let opacity: Double = contentAppeared ? 1 : (reduceMotion ? 1 : 0)

        VStack(spacing: 0) {
            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [p.halo.opacity(0.5), p.accent.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 22)

                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                        .frame(width: 112, height: 112)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 106, height: 106)
                        .shadow(color: p.accent.opacity(0.32), radius: 20, y: 10)

                    Image(systemName: p.systemImage)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, p.accent.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .symbolRenderingMode(.monochrome)
                }
            }
            .padding(.bottom, Theme.Spacing.md)

            Text(L10n.string(p.titleKey))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, Theme.Spacing.sm)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.string(p.bodyKey))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.lg)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, minHeight: tabPageHeight, maxHeight: tabPageHeight, alignment: .top)
        .padding(.horizontal, Theme.Spacing.sm)
        .scaleEffect(scale)
        .opacity(opacity)
    }

    private var bottomChrome: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 7) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(
                            i == page
                                ? LinearGradient(
                                    colors: [.white, Color.white.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.28)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .frame(width: i == page ? 26 : 6, height: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: page)
                }
            }
            .padding(.top, Theme.Spacing.md)

            Group {
                if page < pages.count - 1 {
                    PrimaryGlassButton(L10n.string("Next")) {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            page += 1
                        }
                    }
                } else {
                    PrimaryGlassButton(L10n.string("Get started")) {
                        HapticManager.success()
                        onComplete()
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }
}

/// Dimmed backdrop + centred card for Lookbooks intro.
struct LookbooksOnboardingPopupOverlay: View {
    var onComplete: () -> Void
    @State private var presented = false

    var body: some View {
        GeometryReader { geo in
            let horizontalPad: CGFloat = 18
            let maxCardW = min(geo.size.width - horizontalPad * 2, 420)
            let maxCardH = min(geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom - 24, 720)

            ZStack {
                Color.black
                    .opacity(presented ? 0.5 : 0)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.2), value: presented)

                LookbooksOnboardingView(onComplete: onComplete)
                    .frame(width: maxCardW)
                    .frame(maxHeight: maxCardH)
                    .scaleEffect(presented ? 1 : 0.94, anchor: .center)
                    .opacity(presented ? 1 : 0)
                    .shadow(color: .black.opacity(0.5), radius: 32, y: 18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                presented = true
            }
        }
    }
}
