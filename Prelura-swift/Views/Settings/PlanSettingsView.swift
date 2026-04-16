import SwiftUI

// MARK: - Palette (Gold introduced alongside brand purple)

private enum PlanPalette {
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

private struct PlanScreenAnimatedBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wobble = sin(t * 0.7) * 14.0
            ZStack {
                Theme.Colors.background
                // Soft purple wash
                EllipticalGradient(
                    colors: [
                        Theme.primaryColor.opacity(0.22),
                        Theme.primaryColor.opacity(0.04),
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
                        PlanPalette.goldA.opacity(0.35),
                        PlanPalette.goldB.opacity(0.12),
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
                    colors: [PlanPalette.mysticB.opacity(0.18), .clear],
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

// MARK: - Plan card (one carousel page)

private struct PlanCarouselCard: View {
    enum Kind { case silver, gold, unlimited }

    let kind: Kind
    let title: String
    let subtitle: String
    let features: [String]
    let isCurrent: Bool
    let secondaryCaption: String?
    /// Primary CTA (nil = no button)
    var primaryTitle: String?
    var primaryEnabled: Bool = true
    var primaryAction: (() -> Void)?
    var destructiveTitle: String?
    var destructiveAction: (() -> Void)?

    @State private var sparklePhase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, Theme.Spacing.md)

            Text(subtitle)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.bottom, Theme.Spacing.md)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, line in
                    PlanFeatureRow(text: line, accent: accentForRow(index))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.04), value: features.count)

            Spacer(minLength: Theme.Spacing.md)

            if let cap = secondaryCaption, !cap.isEmpty {
                Text(cap)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, Theme.Spacing.sm)
            }

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
                        .background(primaryButtonBackground)
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
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardFillGradient)
                // Animated rim
                animatedRim
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: rimGlowColor.opacity(isCurrent ? 0.55 : 0.22), radius: isCurrent ? 22 : 12, y: 8)
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                currentPill
                    .padding(12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                sparklePhase = 1
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconBackdrop)
                    .frame(width: 52, height: 52)
                iconView
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, isActive: kind == .gold && isCurrent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(kindTagline)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
    }

    private var kindTagline: String {
        switch kind {
        case .silver: return L10n.string("Essential seller tools")
        case .gold: return L10n.string("Grow faster on Wearhouse")
        case .unlimited: return L10n.string("For mystery power sellers")
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch kind {
        case .silver:
            Image(systemName: "circle.hexagongrid.fill")
        case .gold:
            Image(systemName: "crown.fill")
        case .unlimited:
            Image(systemName: "sparkles.rectangle.stack.fill")
        }
    }

    private var iconBackdrop: some ShapeStyle {
        switch kind {
        case .silver:
            return AnyShapeStyle(LinearGradient(colors: [PlanPalette.silverA.opacity(0.5), PlanPalette.silverB.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .gold:
            return AnyShapeStyle(AngularGradient(colors: [PlanPalette.goldA, PlanPalette.goldB, PlanPalette.goldC, PlanPalette.goldA], center: .center))
        case .unlimited:
            return AnyShapeStyle(LinearGradient(colors: [PlanPalette.mysticA.opacity(0.85), PlanPalette.mysticB.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var cardFillGradient: LinearGradient {
        switch kind {
        case .silver:
            return LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.16, blue: 0.22),
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.14, blue: 0.06),
                    Color(red: 0.10, green: 0.07, blue: 0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unlimited:
            return LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.08, blue: 0.22),
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var animatedRim: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
            let angle = ctx.date.timeIntervalSinceReferenceDate * (kind == .gold ? 42 : 22)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: rimColors),
                        center: .center,
                        angle: .degrees(angle.truncatingRemainder(dividingBy: 360))
                    ),
                    lineWidth: kind == .silver ? 1.5 : 2.5
                )
                .opacity(kind == .silver ? 0.55 : 0.95)
        }
    }

    private var rimColors: [Color] {
        switch kind {
        case .silver:
            return [PlanPalette.silverA.opacity(0.9), PlanPalette.silverB, PlanPalette.silverC.opacity(0.6), PlanPalette.silverA.opacity(0.5)]
        case .gold:
            return [PlanPalette.goldA, PlanPalette.goldB, Theme.primaryColor.opacity(0.9), PlanPalette.goldC, PlanPalette.goldA]
        case .unlimited:
            return [PlanPalette.mysticB, Theme.primaryColor, PlanPalette.mysticA, PlanPalette.mysticB]
        }
    }

    private var rimGlowColor: Color {
        switch kind {
        case .silver: return PlanPalette.silverB
        case .gold: return PlanPalette.goldA
        case .unlimited: return PlanPalette.mysticB
        }
    }

    private func accentForRow(_ index: Int) -> Color {
        switch kind {
        case .silver: return PlanPalette.silverA
        case .gold: return index % 2 == 0 ? PlanPalette.goldA : PlanPalette.goldB
        case .unlimited: return index % 2 == 0 ? PlanPalette.mysticB : Theme.primaryColor
        }
    }

    private var primaryButtonBackground: some View {
        Group {
            switch kind {
            case .silver:
                LinearGradient(colors: [Theme.primaryColor, Theme.primaryColor.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
            case .gold:
                LinearGradient(colors: [PlanPalette.goldB, PlanPalette.goldA.opacity(0.95), PlanPalette.goldB], startPoint: .leading, endPoint: .trailing)
            case .unlimited:
                LinearGradient(colors: [PlanPalette.mysticA, Theme.primaryColor], startPoint: .leading, endPoint: .trailing)
            }
        }
    }

    private var currentPill: some View {
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
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [PlanPalette.goldA, PlanPalette.goldB], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.2
                )
        )
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
                .shadow(color: accent.opacity(0.45), radius: 4, y: 0)
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Settings → Plan

/// Settings → Plan: horizontal carousel of Silver / Gold / Unlimited with motion and gold-accented visuals.
struct PlanSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    private let userService = UserService()

    @State private var profileTier: String = ""
    @State private var showGoldPaywall = false
    @State private var showUnlimitedPaywall = false
    @State private var selectedPage = 0

    private var serverGold: Bool { SellerMysteryQuota.apiProfileIndicatesGoldTier(profileTier) }
    private var localGold: Bool { SellerPlanUserDefaults.localPlan == .gold }
    private var isGoldEffective: Bool { serverGold || localGold }
    private var unlimitedMystery: Bool { SellerPlanUserDefaults.unlimitedMysterySubscribed }

    private var currentPlanTitle: String {
        if unlimitedMystery { return L10n.string("Gold + unlimited mystery") }
        if isGoldEffective { return L10n.string("Gold") }
        return L10n.string("Silver")
    }

    private var silverIsCurrent: Bool { !isGoldEffective && !unlimitedMystery }
    private var goldIsCurrent: Bool { isGoldEffective && !unlimitedMystery }
    private var unlimitedIsCurrent: Bool { unlimitedMystery }

    var body: some View {
        ZStack {
            PlanScreenAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroHeader
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)

                    carousel
                        .padding(.bottom, 8)

                    pageDots

                    footnote
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
        .navigationTitle(L10n.string("Plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Theme.Colors.background.opacity(0.2), for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadProfileTier() }
        .onAppear { syncCarouselPage() }
        .onChange(of: selectedPage) { _, _ in
            HapticManager.selection()
        }
        .sheet(isPresented: $showGoldPaywall) {
            PlanPaywallSheet(
                title: L10n.string("Upgrade to Gold"),
                message: L10n.string("Gold unlocks more mystery box listings and priority visibility. App Store billing will be available soon; you can enable a preview on this device for testing."),
                primaryTitle: L10n.string("Enable Gold (preview)"),
                onConfirm: {
                    SellerPlanUserDefaults.localPlan = .gold
                    showGoldPaywall = false
                },
                onDismiss: { showGoldPaywall = false }
            )
        }
        .sheet(isPresented: $showUnlimitedPaywall) {
            PlanPaywallSheet(
                title: L10n.string("Unlimited mystery boxes"),
                message: L10n.string("Add unlimited active mystery box listings for £10.99/month. This add-on requires Gold. In-app purchase coming soon — enable preview for testing."),
                primaryTitle: L10n.string("Enable add-on (preview)"),
                onConfirm: {
                    SellerPlanUserDefaults.unlimitedMysterySubscribed = true
                    showUnlimitedPaywall = false
                },
                onDismiss: { showUnlimitedPaywall = false }
            )
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text(L10n.string("Your plan"))
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(currentPlanTitle)
                .font(Theme.Typography.largeTitle.weight(.bold))
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, PlanPalette.goldA.opacity(isGoldEffective || unlimitedMystery ? 0.95 : 0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if serverGold {
                Text(L10n.string("Your Wearhouse profile tier includes Gold benefits."))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Text(L10n.string("Swipe to compare tiers"))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.primaryColor.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carousel: some View {
        TabView(selection: $selectedPage) {
            silverPage
                .tag(0)
                .padding(.horizontal, 18)
            goldPage
                .tag(1)
                .padding(.horizontal, 18)
            unlimitedPage
                .tag(2)
                .padding(.horizontal, 18)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 520)
    }

    private var silverPage: some View {
        PlanCarouselCard(
            kind: .silver,
            title: L10n.string("Silver"),
            subtitle: L10n.string("The standard for most sellers"),
            features: [
                L10n.string("Unlimited product uploads"),
                L10n.string("Up to 2 active mystery box listings"),
                L10n.string("0% selling fees"),
            ],
            isCurrent: silverIsCurrent,
            secondaryCaption: nil,
            primaryTitle: nil,
            primaryEnabled: true,
            primaryAction: nil,
            destructiveTitle: nil,
            destructiveAction: nil
        )
    }

    private var goldPage: some View {
        PlanCarouselCard(
            kind: .gold,
            title: L10n.string("Gold"),
            subtitle: L10n.string("More reach, more mystery boxes"),
            features: [
                L10n.string("Everything in Silver"),
                L10n.string("Up to 5 active mystery box listings"),
                L10n.string("0% selling fees"),
                L10n.string("Priority placement in search & category browsing"),
                L10n.string("Priority seller support"),
            ],
            isCurrent: goldIsCurrent,
            secondaryCaption: unlimitedMystery ? L10n.string("Unlimited mystery add-on is active on top of Gold.") : nil,
            primaryTitle: isGoldEffective ? nil : L10n.string("Upgrade to Gold"),
            primaryEnabled: true,
            primaryAction: isGoldEffective ? nil : { showGoldPaywall = true },
            destructiveTitle: (isGoldEffective && !serverGold) ? L10n.string("Remove local Gold preview") : nil,
            destructiveAction: (isGoldEffective && !serverGold) ? { SellerPlanUserDefaults.localPlan = .silver } : nil
        )
    }

    private var unlimitedPage: some View {
        PlanCarouselCard(
            kind: .unlimited,
            title: L10n.string("Unlimited mystery"),
            subtitle: L10n.string("No ceiling on mystery listings"),
            features: [
                L10n.string("No cap on active mystery box listings"),
                L10n.string("£10.99/month after purchase"),
            ],
            isCurrent: unlimitedIsCurrent,
            secondaryCaption: L10n.string("Requires Gold. Billed monthly when IAP is live."),
            primaryTitle: unlimitedMystery ? nil : L10n.string("Subscribe — £10.99/month"),
            primaryEnabled: isGoldEffective,
            primaryAction: unlimitedMystery ? nil : { showUnlimitedPaywall = true },
            destructiveTitle: unlimitedMystery ? L10n.string("Turn off preview subscription") : nil,
            destructiveAction: unlimitedMystery ? { SellerPlanUserDefaults.unlimitedMysterySubscribed = false } : nil
        )
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == selectedPage ? AnyShapeStyle(LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(0.25)))
                    .frame(width: i == selectedPage ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedPage)
            }
        }
        .padding(.vertical, 4)
    }

    private var footnote: some View {
        Text(L10n.string("Prices and entitlements will sync from your App Store subscription when billing goes live."))
            .font(Theme.Typography.caption)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
    }

    private func loadProfileTier() async {
        userService.updateAuthToken(authService.authToken)
        do {
            let user = try await userService.getUser(username: nil)
            await MainActor.run {
                profileTier = user.profileTier
                syncCarouselPage()
            }
        } catch {
            await MainActor.run {
                profileTier = ""
                syncCarouselPage()
            }
        }
    }

    private func syncCarouselPage() {
        if unlimitedMystery {
            selectedPage = 2
        } else if isGoldEffective {
            selectedPage = 1
        } else {
            selectedPage = 0
        }
    }
}

// MARK: - Paywall sheet (slightly richer chrome)

private struct PlanPaywallSheet: View {
    let title: String
    let message: String
    let primaryTitle: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PlanScreenAnimatedBackground()
                    .opacity(0.55)
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor, PlanPalette.mysticB], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 5)
                        .padding(.top, 4)

                    Text(message)
                        .font(Theme.Typography.body)
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer(minLength: 0)
                    PrimaryGlassButton(primaryTitle, isEnabled: true, isLoading: false) {
                        onConfirm()
                        dismiss()
                    }
                    BorderGlassButton(L10n.string("Cancel")) {
                        onDismiss()
                        dismiss()
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Theme.Colors.background.opacity(0.3), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}
