import SwiftUI

// MARK: - Catalog

/// One row in the haptics debug screen: maps to `HapticManager` API.
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

    /// Short line for the menu row (under the title).
    var summaryLine: String {
        switch self {
        case .tabTap: return "Tab bar, pull-to-refresh"
        case .primaryAction: return "Primary CTAs, send, submit"
        case .secondaryAction: return "Outline / border buttons"
        case .selection: return "Lists, filters, sort, segments"
        case .toggle: return "Profile switches"
        case .like: return "Heart / Discover like"
        case .success: return "Upload, onboarding, sell"
        case .error: return "Reserved — not wired in app yet"
        case .refresh: return "TabCoordinator refresh"
        case .tap: return "Menus, lookbook, icons"
        case .destructive: return "Logout, delete confirms"
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
            return [
                "Lookbook upload success",
                "Onboarding completion",
                "Sell flow success"
            ]
        case .error:
            return [
                "API exists as `HapticManager.error()`",
                "No call sites yet — same generator as `.warning`"
            ]
        case .refresh:
            return ["TabCoordinator when refresh runs"]
        case .tap:
            return [
                "Menu items and alerts",
                "Lookbook feed (share, delete, comments preview, …)",
                "My favourites actions"
            ]
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

// MARK: - Rows (Help Centre–style)

private struct HapticDebugMenuRow: View {
    let kind: HapticDebugKind

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.primaryColor)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.displayTitle)
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                Text(kind.summaryLine)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
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

// MARK: - Detail

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
        .onAppear {
            kind.play()
        }
    }
}

// MARK: - Screen

/// Debug: every `HapticManager` style, UIKit mapping, and in-app usage (Help Centre–style list).
struct HapticsDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.string("Tap a row for details. Opening a type plays it once."))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.bottom, Theme.Spacing.md)

                sectionTitle(L10n.string("Impact & selection"))
                menuSection(kinds: HapticDebugKind.impactKinds)

                sectionTitle(L10n.string("Notification feedback"))
                menuSection(kinds: HapticDebugKind.notificationKinds)
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
    private func menuSection(kinds: [HapticDebugKind]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                NavigationLink {
                    HapticTypeDetailView(kind: kind)
                } label: {
                    HapticDebugMenuRow(kind: kind)
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
