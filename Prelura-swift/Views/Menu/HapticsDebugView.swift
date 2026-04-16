import SwiftUI

// MARK: - App Haptics Catalog

private enum HapticDebugKind: String, CaseIterable, Identifiable, Hashable {
    case tabTap
    case primaryAction
    case secondaryAction
    case selection
    case toggle
    case like
    case success
    case error
    case refresh
    case tap
    case destructive

    var id: String { rawValue }
    var apiName: String { "HapticManager.\(rawValue)()" }

    var displayTitle: String {
        switch self {
        case .tabTap: return "Tab tap"
        case .primaryAction: return "Primary action"
        case .secondaryAction: return "Secondary action"
        case .selection: return "Selection"
        case .toggle: return "Toggle"
        case .like: return "Like / favourite"
        case .success: return "Success"
        case .error: return "Error"
        case .refresh: return "Refresh"
        case .tap: return "Tap"
        case .destructive: return "Destructive"
        }
    }

    var symbol: String {
        switch self {
        case .tabTap: return "square.grid.2x2"
        case .primaryAction: return "hand.tap.fill"
        case .secondaryAction: return "circle.dashed"
        case .selection: return "line.3.horizontal.decrease.circle"
        case .toggle: return "switch.2"
        case .like: return "heart.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .refresh: return "arrow.clockwise"
        case .tap: return "dot.circle"
        case .destructive: return "trash.fill"
        }
    }

    var summaryLine: String {
        switch self {
        case .tabTap: return "Tab bar, pull-to-refresh"
        case .primaryAction: return "Primary CTAs, send, submit"
        case .secondaryAction: return "Outline / border buttons"
        case .selection: return "Lists, filters, sort, segments"
        case .toggle: return "Profile switches"
        case .like: return "Heart / Discover like"
        case .success: return "Upload, onboarding, sell"
        case .error: return "Error-like warning pulse used in app"
        case .refresh: return "TabCoordinator refresh"
        case .tap: return "Menus, lookbook, icons"
        case .destructive: return "Logout, delete confirms"
        }
    }

    var uikitSummary: String {
        switch self {
        case .tabTap:
            return "UIImpactFeedbackGenerator(style: .light), intensity 0.7"
        case .primaryAction:
            return "UIImpactFeedbackGenerator(style: .medium), intensity 0.8"
        case .secondaryAction:
            return "UIImpactFeedbackGenerator(style: .light), intensity 0.6"
        case .selection:
            return "UISelectionFeedbackGenerator().selectionChanged()"
        case .toggle:
            return "UIImpactFeedbackGenerator(style: .soft), intensity 0.5"
        case .like:
            return "UIImpactFeedbackGenerator(style: .soft), intensity 0.6"
        case .success:
            return "UINotificationFeedbackGenerator().notificationOccurred(.success)"
        case .error:
            return "UINotificationFeedbackGenerator().notificationOccurred(.warning)"
        case .refresh:
            return "UIImpactFeedbackGenerator(style: .light), intensity 0.5"
        case .tap:
            return "UIImpactFeedbackGenerator(style: .light), intensity 0.5"
        case .destructive:
            return "UINotificationFeedbackGenerator().notificationOccurred(.warning)"
        }
    }

    var applications: [String] {
        switch self {
        case .tabTap:
            return ["Tab bar switches (`TabCoordinator`)", "Pull-to-refresh on tab feeds"]
        case .primaryAction:
            return [
                "Primary glass button (`PrimaryGlassButton`)",
                "AI / Ann chat send",
                "Forgot password submit",
                "Vintage shop promo CTA",
                "List of contacts actions"
            ]
        case .secondaryAction:
            return ["Border / outline glass button (`BorderGlassButton`)"]
        case .selection:
            return [
                "Discover, filters, sort sheets",
                "Profile and user profile lists",
                "Payment and bag rows",
                "Sell flow pickers",
                "Pill tags and multi-buy cart"
            ]
        case .toggle:
            return ["Profile toggles (`ProfileView`)", "Black screen profile switches"]
        case .like:
            return ["`LikeButtonView`", "Discover like button"]
        case .success:
            return ["Lookbook upload success", "Onboarding completion", "Sell flow success"]
        case .error:
            return ["Auth / validation failures that need a warning pattern", "Fallback error pulse"]
        case .refresh:
            return ["TabCoordinator when refresh runs"]
        case .tap:
            return ["Menu items and alerts", "Lookbook feed actions", "My favourites actions"]
        case .destructive:
            return ["Account menu logout / destructive confirm (`MenuView`)"]
        }
    }

    func play() {
        switch self {
        case .tabTap: HapticManager.tabTap()
        case .primaryAction: HapticManager.primaryAction()
        case .secondaryAction: HapticManager.secondaryAction()
        case .selection: HapticManager.selection()
        case .toggle: HapticManager.toggle()
        case .like: HapticManager.like()
        case .success: HapticManager.success()
        case .error: HapticManager.error()
        case .refresh: HapticManager.refresh()
        case .tap: HapticManager.tap()
        case .destructive: HapticManager.destructive()
        }
    }

    static var impactKinds: [HapticDebugKind] {
        [.tabTap, .primaryAction, .secondaryAction, .selection, .toggle, .like, .refresh, .tap]
    }

    static var notificationKinds: [HapticDebugKind] {
        [.success, .error, .destructive]
    }
}

// MARK: - Advanced / Raw UIKit Haptics

private enum AdvancedHapticDebugKind: String, CaseIterable, Identifiable, Hashable {
    case notificationWarning
    case notificationError
    case impactHeavy
    case impactRigid
    case longPressPulse
    case incorrectPassword
    case invalidCode
    case biometricFailed

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .notificationWarning: return "Notification warning"
        case .notificationError: return "Notification error"
        case .impactHeavy: return "Impact heavy"
        case .impactRigid: return "Impact rigid"
        case .longPressPulse: return "Long-hold pulse"
        case .incorrectPassword: return "Incorrect password pattern"
        case .invalidCode: return "Invalid code pattern"
        case .biometricFailed: return "Biometric failed pattern"
        }
    }

    var symbol: String {
        switch self {
        case .notificationWarning: return "exclamationmark.circle.fill"
        case .notificationError: return "xmark.circle.fill"
        case .impactHeavy: return "hammer.fill"
        case .impactRigid: return "bolt.fill"
        case .longPressPulse: return "hand.raised.fill"
        case .incorrectPassword: return "lock.slash.fill"
        case .invalidCode: return "number.circle.fill"
        case .biometricFailed: return "faceid"
        }
    }

    var summaryLine: String {
        switch self {
        case .notificationWarning: return "Direct UIKit warning pulse"
        case .notificationError: return "Direct UIKit error pulse"
        case .impactHeavy: return "Heavy impact hit"
        case .impactRigid: return "Rigid impact hit"
        case .longPressPulse: return "Hold button to repeat every 180ms"
        case .incorrectPassword: return "Warning + rigid bump (auth fail)"
        case .invalidCode: return "Error + soft bump (OTP fail)"
        case .biometricFailed: return "Error pulse for Face ID / Touch ID fail"
        }
    }

    var uikitSummary: String {
        switch self {
        case .notificationWarning:
            return "UINotificationFeedbackGenerator().notificationOccurred(.warning)"
        case .notificationError:
            return "UINotificationFeedbackGenerator().notificationOccurred(.error)"
        case .impactHeavy:
            return "UIImpactFeedbackGenerator(style: .heavy), intensity 0.9"
        case .impactRigid:
            return "UIImpactFeedbackGenerator(style: .rigid), intensity 0.85"
        case .longPressPulse:
            return "UIImpactFeedbackGenerator(style: .soft), repeating while pressed"
        case .incorrectPassword:
            return ".warning + rigid impact chain"
        case .invalidCode:
            return ".error + soft impact chain"
        case .biometricFailed:
            return ".error (single strong fail pulse)"
        }
    }

    var applications: [String] {
        switch self {
        case .notificationWarning:
            return ["Warning state previews", "Non-fatal form validation"]
        case .notificationError:
            return ["Hard auth errors", "Critical operation failures"]
        case .impactHeavy:
            return ["Destructive confirms", "Major state changes"]
        case .impactRigid:
            return ["Security / auth fail accent", "Firm acknowledgement"]
        case .longPressPulse:
            return ["Context menus", "Hold interactions", "Recording-hold previews"]
        case .incorrectPassword:
            return ["Incorrect password", "Wrong credentials"]
        case .invalidCode:
            return ["One-time code mismatch", "Verification code rejected"]
        case .biometricFailed:
            return ["Face ID failed", "Touch ID failed"]
        }
    }

    func play() {
        switch self {
        case .notificationWarning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .notificationError:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .impactHeavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        case .impactRigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
        case .longPressPulse:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        case .incorrectPassword:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        case .invalidCode:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        case .biometricFailed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Shared Views

private struct DebugChevronRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.primaryColor)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
    }
}

private struct HoldToRepeatHapticButton: View {
    let title: String
    let action: () -> Void
    @State private var timer: Timer?
    @State private var isHolding = false

    var body: some View {
        Text(title)
            .font(Theme.Typography.headline)
            .foregroundStyle(isHolding ? Theme.primaryColor : Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius)
                    .strokeBorder(Theme.primaryColor.opacity(isHolding ? 0.9 : 0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius)
                            .fill(Theme.primaryColor.opacity(isHolding ? 0.16 : 0.08))
                    )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in start() }
                    .onEnded { _ in stop() }
            )
            .onDisappear { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        isHolding = true
        action()
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in action() }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        isHolding = false
    }
}

// MARK: - Details

private struct HapticTypeDetailView: View {
    let kind: HapticDebugKind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.apiName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Text(kind.uikitSummary)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.primaryText)
                }

                Button {
                    kind.play()
                } label: {
                    Text(L10n.string("Play again"))
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(Theme.primaryColor, in: RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius))

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Where it's used"))
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    ForEach(Array(kind.applications.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Text("•")
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text(line)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle(kind.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { kind.play() }
    }
}

private struct AdvancedHapticTypeDetailView: View {
    let kind: AdvancedHapticDebugKind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.uikitSummary)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    Text("Use hold for sustained feedback checks.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Button {
                    kind.play()
                } label: {
                    Text(L10n.string("Play again"))
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(Theme.primaryColor, in: RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius))

                HoldToRepeatHapticButton(title: "Hold to repeat") {
                    kind.play()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Where it's used"))
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    ForEach(Array(kind.applications.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Text("•")
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Text(line)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle(kind.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { kind.play() }
    }
}

// MARK: - Screen

struct HapticsDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Tap a row for details. Opening a type plays it once. Long-hold repeat is available on advanced pages.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.bottom, Theme.Spacing.md)

                sectionTitle("Impact & selection")
                appKindsSection(kinds: HapticDebugKind.impactKinds)

                sectionTitle("Notification feedback")
                appKindsSection(kinds: HapticDebugKind.notificationKinds)

                sectionTitle("Advanced auth and long-hold")
                advancedKindsSection(kinds: AdvancedHapticDebugKind.allCases)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Haptics"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primaryText)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private func appKindsSection(kinds: [HapticDebugKind]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                NavigationLink {
                    HapticTypeDetailView(kind: kind)
                } label: {
                    DebugChevronRow(title: kind.displayTitle, subtitle: kind.summaryLine, symbol: kind.symbol)
                }
                .buttonStyle(.plain)
                if index < kinds.count - 1 {
                    HelpCentreInsetDivider()
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    @ViewBuilder
    private func advancedKindsSection(kinds: [AdvancedHapticDebugKind]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                NavigationLink {
                    AdvancedHapticTypeDetailView(kind: kind)
                } label: {
                    DebugChevronRow(title: kind.displayTitle, subtitle: kind.summaryLine, symbol: kind.symbol)
                }
                .buttonStyle(.plain)
                if index < kinds.count - 1 {
                    HelpCentreInsetDivider()
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    NavigationStack {
        HapticsDebugView()
    }
    .preferredColorScheme(.dark)
}
