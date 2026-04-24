import SwiftUI

// MARK: - Palette (Gold introduced alongside brand purple)

enum PlanPalette {
    static let goldA = Color(red: 0.98, green: 0.88, blue: 0.42)
    static let goldB = Color(red: 0.78, green: 0.55, blue: 0.12)
    static let goldC = Color(red: 0.42, green: 0.28, blue: 0.06)
    static let silverA = Color(red: 0.92, green: 0.94, blue: 0.98)
    static let silverB = Color(red: 0.55, green: 0.62, blue: 0.72)
    static let silverC = Color(red: 0.22, green: 0.26, blue: 0.34)
    static let mysticA = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let mysticB = Color(red: 0.25, green: 0.85, blue: 0.92)
}

// MARK: - Animated mesh backdrop

struct PlanScreenAnimatedBackground: View {
    /// Slightly lifted from app chrome so purple / gold / cyan reads without going pitch-black.
    private static let planScreenBase = Color(red: 0.09, green: 0.085, blue: 0.11)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wobble = sin(t * 0.7) * 14.0
            ZStack {
                Self.planScreenBase
                Theme.Colors.background.opacity(0.45)
                // Soft purple wash
                EllipticalGradient(
                    colors: [
                        Theme.primaryColor.opacity(0.32),
                        Theme.primaryColor.opacity(0.08),
                        .clear,
                    ],
                    center: .init(x: 0.15 + sin(t * 0.35) * 0.08, y: 0.12),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.95
                )
                .blur(radius: 28)
                .offset(x: wobble * 3, y: cos(t * 0.5) * 20)

                // Gold warmth (bottom-right)
                EllipticalGradient(
                    colors: [
                        PlanPalette.goldA.opacity(0.44),
                        PlanPalette.goldB.opacity(0.18),
                        .clear,
                    ],
                    center: .init(x: 0.88 - sin(t * 0.28) * 0.05, y: 0.78),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.75
                )
                .blur(radius: 36)
                .offset(x: -wobble * 2, y: sin(t * 0.4) * 16)

                // Cyan spark for “mystery” energy
                RadialGradient(
                    colors: [PlanPalette.mysticB.opacity(0.26), .clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: 220
                )
                .scaleEffect(1.0 + sin(t * 1.1) * 0.06)
                .offset(x: CGFloat(sin(t * 0.9)) * 40, y: CGFloat(cos(t * 0.85)) * 50)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Plan tier cards (Silver and Gold are separate views)

private struct PlanMeasuredGoldCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PlanMeasuredSilverCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PlanSettingsTierCurrentPill: View {
    @Binding var sparklePhase: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PlanPalette.goldA)
                .symbolEffect(.bounce, value: sparklePhase)
            Text(L10n.string("Current"))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [PlanPalette.goldA, PlanPalette.goldB], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.2
                )
        )
    }
}

private struct PlanTierCardEqualHeightModifier: ViewModifier {
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        if let h = minHeight, h > 0 {
            content.frame(maxWidth: .infinity, minHeight: h, alignment: .topLeading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// Silver tier: separate view; optional `cardMinHeight` keeps Silver and Gold cards the same height in the carousel.
private struct PlanSilverTierCard: View {
    let isCurrent: Bool
    let features: [String]
    /// When set, expands the card to this height (matches Gold); `nil` for intrinsic sizing (measurement probes).
    let cardMinHeight: CGFloat?
    let priceLine: String
    let primaryTitle: String?
    let primaryEnabled: Bool
    let primaryAction: (() -> Void)?

    @State private var sparklePhase: CGFloat = 0

    private var hasFooterActions: Bool {
        primaryTitle != nil && primaryAction != nil
    }

    /// When the card is given a carousel `minHeight`, expand vertically so a `Spacer` can pin the footer to the bottom edge.
    private var stretchesToCarouselSlot: Bool { (cardMinHeight ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            AnyShapeStyle(LinearGradient(colors: [PlanPalette.silverA.opacity(0.5), PlanPalette.silverB.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Silver"))
                        .font(Theme.Typography.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(L10n.string("Essential seller tools"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(priceLine)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(PlanPalette.silverA.opacity(0.95))
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, Theme.Spacing.md)

            Text(L10n.string("The standard for most sellers"))
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.bottom, Theme.Spacing.md)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, line in
                    PlanFeatureRow(text: line, accent: PlanPalette.silverA)
                }
            }

            if hasFooterActions {
                Spacer(minLength: Theme.Spacing.sm)
                if let pt = primaryTitle, let pa = primaryAction {
                    Button(action: {
                        HapticManager.tap()
                        pa()
                    }) {
                        Text(pt)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [PlanPalette.silverB, PlanPalette.silverA.opacity(0.92), PlanPalette.silverB],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!primaryEnabled)
                    .opacity(primaryEnabled ? 1 : 0.45)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: stretchesToCarouselSlot ? .infinity : nil, alignment: .topLeading)
        .padding(Theme.Spacing.lg)
        .modifier(PlanTierCardEqualHeightModifier(minHeight: cardMinHeight))
        .background { silverCardBackground }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: Color.black.opacity(isCurrent ? 0.45 : 0.32), radius: isCurrent ? 16 : 10, y: 6)
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                PlanSettingsTierCurrentPill(sparklePhase: $sparklePhase)
                    .padding(12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                sparklePhase = 1
            }
        }
    }

    private var silverCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.14))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.22, blue: 0.28).opacity(0.55),
                            Color.clear,
                            Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.9),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            AnimatedSilverTravelingBorder(outerCornerRadius: 28)
        }
    }
}

/// Gold tier: separate view; optional `cardMinHeight` matches Silver so both cards align in the carousel.
private struct PlanGoldTierCard: View {
    let isCurrent: Bool
    let features: [String]
    /// When set, expands the card to this height (matches Silver); `nil` for intrinsic sizing (measurement probes).
    let cardMinHeight: CGFloat?
    let priceLine: String
    let primaryTitle: String?
    let primaryEnabled: Bool
    let primaryAction: (() -> Void)?
    let destructiveTitle: String?
    let destructiveAction: (() -> Void)?

    @State private var sparklePhase: CGFloat = 0

    private var hasFooterActions: Bool {
        let primary = primaryTitle != nil && primaryAction != nil
        let destructive = destructiveTitle != nil && destructiveAction != nil
        return primary || destructive
    }

    private var stretchesToCarouselSlot: Bool { (cardMinHeight ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            AnyShapeStyle(AngularGradient(colors: [PlanPalette.goldA, PlanPalette.goldB, PlanPalette.goldC, PlanPalette.goldA], center: .center))
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating, isActive: isCurrent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Gold"))
                        .font(Theme.Typography.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(L10n.string("Grow faster on Wearhouse"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(priceLine)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(PlanPalette.goldA.opacity(0.95))
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, Theme.Spacing.md)

            Text(L10n.string("More reach, more mystery boxes"))
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.bottom, Theme.Spacing.md)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, line in
                    PlanFeatureRow(text: line, accent: index % 2 == 0 ? PlanPalette.goldA : PlanPalette.goldB)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.04), value: features.count)

            if hasFooterActions {
                Spacer(minLength: Theme.Spacing.sm)
                VStack(alignment: .leading, spacing: 0) {
                    if let pt = primaryTitle, let pa = primaryAction {
                        Button(action: {
                            HapticManager.tap()
                            pa()
                        }) {
                            Text(pt)
                                .font(Theme.Typography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [PlanPalette.goldB, PlanPalette.goldA.opacity(0.95), PlanPalette.goldB], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!primaryEnabled)
                        .opacity(primaryEnabled ? 1 : 0.45)
                    }

                    if let dt = destructiveTitle, let da = destructiveAction {
                        Button(role: .destructive, action: {
                            HapticManager.tap()
                            da()
                        }) {
                            Text(dt)
                                .font(Theme.Typography.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: stretchesToCarouselSlot ? .infinity : nil, alignment: .topLeading)
        .padding(Theme.Spacing.lg)
        .modifier(PlanTierCardEqualHeightModifier(minHeight: cardMinHeight))
        .background { goldCardBackground }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: Color.black.opacity(isCurrent ? 0.45 : 0.32), radius: isCurrent ? 16 : 10, y: 6)
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                PlanSettingsTierCurrentPill(sparklePhase: $sparklePhase)
                    .padding(12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                sparklePhase = 1
            }
        }
    }

    private var goldCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.05))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.5),
                            Color.clear,
                            Color(red: 0.08, green: 0.05, blue: 0.04).opacity(0.95),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
                let angle = ctx.date.timeIntervalSinceReferenceDate * 42
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                PlanPalette.goldA, PlanPalette.goldB, Theme.primaryColor.opacity(0.85), PlanPalette.goldC, PlanPalette.goldA,
                            ]),
                            center: .center,
                            angle: .degrees(angle.truncatingRemainder(dividingBy: 360))
                        ),
                        lineWidth: 2
                    )
                    .padding(2)
            }
        }
    }
}

private struct PlanFeatureRow: View {
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [accent, accent.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: accent.opacity(0.22), radius: 2, y: 0)
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Settings → Plan

/// Settings → Plan: Silver & Gold tier carousel.
/// Layout is a vertical `ScrollView` so tall tier cards scroll instead of pinning hero text or page dots under the navigation bar or home indicator.
struct PlanSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    private let userService = UserService()

    @State private var profileTier: String = ""
    @State private var showGoldPaywall = false
    @State private var showServerGoldDowngradeInfo = false
    /// Starts from local preview tier so Gold users do not paint Silver on the first frame; server tier is applied after fetch without animation.
    @State private var selectedPage: Int = PlanSettingsView.initialCarouselPageIndex()
    @State private var measuredGoldCardHeight: CGFloat = 0
    @State private var measuredSilverCardHeight: CGFloat = 0
    /// When false and the user is not on local Gold preview, the TabView stays hidden until `loadProfileTier` finishes so the pager does not flash Silver then Gold.
    @State private var hasCompletedInitialPlanFetch = false
    /// From `viewMe.meta.sellerGoldRenewsAt` after `loadProfileTier` / subscribe refresh.
    @State private var serverGoldRenewsAt: Date?

    private var serverGold: Bool { SellerMysteryQuota.apiProfileIndicatesGoldTier(profileTier) }
    private var localGold: Bool { SellerPlanUserDefaults.localPlan == .gold }
    private var isGoldEffective: Bool { serverGold || localGold }

    private var currentPlanTitle: String {
        if isGoldEffective { return L10n.string("Gold") }
        return L10n.string("Silver")
    }

    private var silverIsCurrent: Bool { !isGoldEffective }
    private var goldIsCurrent: Bool { isGoldEffective }

    /// Local Gold preview can show the carousel immediately on the correct page; everyone else waits one network round-trip to avoid a wrong first page.
    private var shouldShowPlanCarousel: Bool {
        SellerPlanUserDefaults.localPlan == .gold || hasCompletedInitialPlanFetch
    }

    /// Horizontal inset from the scroll edge to the tier card chrome (smaller = wider cards).
    private static let planCarouselCardHorizontalInset: CGFloat = 8

    private static func initialCarouselPageIndex() -> Int {
        SellerPlanUserDefaults.localPlan == .gold ? 1 : 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                planHeroTitleSection
                    .padding(.horizontal, Theme.Spacing.md)

                carousel
                    .padding(.horizontal, Theme.Spacing.sm)

                pageDots
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                footnote
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl * 2 + Theme.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background {
            PlanScreenAnimatedBackground()
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticTapButtonStyle())
                .accessibilityLabel(L10n.string("Back"))
            }
            ToolbarItem(placement: .principal) {
                planToolbarPrincipalChrome
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .task { await loadProfileTier() }
        .onChange(of: selectedPage) { _, _ in
            HapticManager.selection()
        }
        .onPreferenceChange(PlanMeasuredGoldCardHeightKey.self) { h in
            guard h > 1 else { return }
            if abs(measuredGoldCardHeight - h) > 0.5 {
                measuredGoldCardHeight = h
            }
        }
        .onPreferenceChange(PlanMeasuredSilverCardHeightKey.self) { h in
            guard h > 1 else { return }
            if abs(measuredSilverCardHeight - h) > 0.5 {
                measuredSilverCardHeight = h
            }
        }
        .onChange(of: isGoldEffective) { _, _ in
            measuredGoldCardHeight = 0
            measuredSilverCardHeight = 0
            syncCarouselPage(animated: true)
        }
        .alert(L10n.string("Gold plan"), isPresented: $showServerGoldDowngradeInfo) {
            Button(L10n.string("OK"), role: .cancel) {}
        } message: {
            Text(L10n.string("Your Wearhouse account is on Gold. In-app downgrades will be available when App Store billing goes live."))
        }
        .sheet(isPresented: $showGoldPaywall) {
            PlanGoldSubscribeSheet(
                authToken: authService.authToken,
                onSubscribed: {
                    Task { await subscribedGoldRefresh() }
                },
                onDismiss: { showGoldPaywall = false }
            )
            .wearhouseSheetContentColumnIfWide()
        }
    }

    private var planToolbarPrincipalChrome: some View {
        HStack(spacing: 8) {
            Image(systemName: "hands.sparkles.fill")
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text(L10n.string("Your plan"))
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.primaryText.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var planHeroTitleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(currentPlanTitle)
                .font(Theme.Typography.largeTitle.weight(.bold))
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, PlanPalette.goldA.opacity(isGoldEffective ? 0.95 : 0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            if let billing = formattedNextBillingLine() {
                Text(billing)
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryColor.opacity(0.92))
            }
            Text(L10n.string("Swipe to compare tiers"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.primaryColor.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedNextBillingLine() -> String? {
        guard isGoldEffective else { return nil }
        guard let d = serverGoldRenewsAt else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return "\(L10n.string("Next billing")): \(df.string(from: d))"
    }

    private let planCarouselFallbackSlotHeight: CGFloat = 480

    private var planCarouselSlotHeight: CGFloat {
        let g = measuredGoldCardHeight
        let s = measuredSilverCardHeight
        let m = max(g, s)
        if m > 1 { return m }
        return planCarouselFallbackSlotHeight
    }

    @ViewBuilder
    private func planGoldTierCard(cardMinHeight: CGFloat?) -> some View {
        PlanGoldTierCard(
            isCurrent: goldIsCurrent,
            features: [
                L10n.string("Everything in Silver"),
                L10n.string("15 scheduled posts"),
                L10n.string("30 Lookbook products per month"),
                L10n.string("Up to 5 active mystery box listings"),
                L10n.string("0% selling fees"),
                L10n.string("Priority placement in search & category browsing"),
                L10n.string("Priority seller support"),
            ],
            cardMinHeight: cardMinHeight,
            priceLine: L10n.string("£10.99/month"),
            primaryTitle: isGoldEffective ? nil : L10n.string("Upgrade to Gold"),
            primaryEnabled: true,
            primaryAction: isGoldEffective ? nil : { showGoldPaywall = true },
            destructiveTitle: (isGoldEffective && !serverGold) ? L10n.string("Remove local Gold preview") : nil,
            destructiveAction: (isGoldEffective && !serverGold) ? { SellerPlanUserDefaults.localPlan = .silver } : nil
        )
    }

    @ViewBuilder
    private func planSilverTierCard(cardMinHeight: CGFloat?) -> some View {
        PlanSilverTierCard(
            isCurrent: silverIsCurrent,
            features: [
                L10n.string("Unlimited product uploads"),
                L10n.string("Up to 1 active mystery box listing"),
                L10n.string("5 scheduled posts"),
                L10n.string("10 Lookbook products per month"),
                L10n.string("0% selling fees"),
            ],
            cardMinHeight: cardMinHeight,
            priceLine: L10n.string("Free"),
            primaryTitle: isGoldEffective ? L10n.string("Downgrade to Silver") : nil,
            primaryEnabled: true,
            primaryAction: isGoldEffective ? { downgradeFromSilverCardTapped() } : nil
        )
    }

    private var carousel: some View {
        let slotH = planCarouselSlotHeight
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                planGoldTierCard(cardMinHeight: nil)
                    .padding(.horizontal, Self.planCarouselCardHorizontalInset)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: PlanMeasuredGoldCardHeightKey.self, value: geo.size.height)
                        }
                    )
                planSilverTierCard(cardMinHeight: nil)
                    .padding(.horizontal, Self.planCarouselCardHorizontalInset)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: PlanMeasuredSilverCardHeightKey.self, value: geo.size.height)
                        }
                    )
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(0)

            if shouldShowPlanCarousel {
                TabView(selection: $selectedPage) {
                    silverPage(slotHeight: slotH)
                        .tag(0)
                        .padding(.horizontal, Self.planCarouselCardHorizontalInset)
                    goldPage(slotHeight: slotH)
                        .tag(1)
                        .padding(.horizontal, Self.planCarouselCardHorizontalInset)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: slotH)
                .zIndex(1)
            } else {
                ProgressView()
                    .tint(Theme.primaryColor)
                    .frame(maxWidth: .infinity, minHeight: max(slotH, planCarouselFallbackSlotHeight))
                    .zIndex(1)
            }
        }
    }

    private func silverPage(slotHeight: CGFloat) -> some View {
        planSilverTierCard(cardMinHeight: slotHeight)
    }

    private func downgradeFromSilverCardTapped() {
        if serverGold {
            showServerGoldDowngradeInfo = true
        } else {
            SellerPlanUserDefaults.localPlan = .silver
        }
    }

    private func goldPage(slotHeight: CGFloat) -> some View {
        planGoldTierCard(cardMinHeight: slotHeight)
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i == selectedPage ? AnyShapeStyle(LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(0.25)))
                    .frame(width: i == selectedPage ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedPage)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var footnote: some View {
        Text(L10n.string("Gold is billed through Apple. Your Wearhouse profile stores a receipt summary in account settings after each successful purchase."))
            .font(Theme.Typography.caption)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.sm)
    }

    private func subscribedGoldRefresh() async {
        let svc = UserService()
        svc.updateAuthToken(authService.authToken)
        if let me = try? await svc.getUser(username: nil) {
            let key = SellerScheduledListingQuota.stableUserKey(from: me)
            SellerScheduledListingQuota.ensureBillingAnchorIfUnset(userKey: key)
        }
        await loadProfileTier()
        await MainActor.run {
            showGoldPaywall = false
        }
    }

    private func loadProfileTier() async {
        userService.updateAuthToken(authService.authToken)
        do {
            let user = try await userService.getUser(username: nil)
            await MainActor.run {
                profileTier = user.profileTier
                serverGoldRenewsAt = user.sellerGoldRenewsAt
                syncCarouselPage(animated: false)
                hasCompletedInitialPlanFetch = true
            }
        } catch {
            await MainActor.run {
                profileTier = ""
                serverGoldRenewsAt = nil
                syncCarouselPage(animated: false)
                hasCompletedInitialPlanFetch = true
            }
        }
    }

    private func syncCarouselPage(animated: Bool) {
        let next = isGoldEffective ? 1 : 0
        guard selectedPage != next else { return }
        if animated {
            selectedPage = next
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                selectedPage = next
            }
        }
    }
}

