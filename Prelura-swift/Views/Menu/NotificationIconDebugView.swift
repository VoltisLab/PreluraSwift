import SwiftUI

/// Debug: compares **WEARHOUSE Pro** admin sidebar notification glyph (`bell.badge`) with retail toolbar bells and SF Symbol variants.
struct NotificationIconDebugView: View {
    /// Admin `AdminSidebarSection.notifications` uses `bell.badge` (same as sidebar `Label` in `AdminDesktopShell`).
    private static let adminSidebarSymbol = "bell.badge"

    /// Sidebar-style bell: white/outline bell, **red** badge dot. `bell.badge` palette index 0 = badge, 1 = bell (see `HomeToolbarNotificationBellVisual`).
    @ViewBuilder
    private func adminBellGlyph(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        Image(systemName: Self.adminSidebarSymbol)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.red, Theme.Colors.primaryText)
            .font(.system(size: size, weight: weight))
    }

    private static let symbolVariants: [(label: String, name: String)] = [
        ("Admin sidebar", "bell.badge"),
        ("Bell outline", "bell"),
        ("Bell filled", "bell.fill"),
        ("Badge outline", "bell.badge"),
        ("Badge filled", "bell.badge.fill"),
        ("Slash", "bell.slash"),
        ("Slash filled", "bell.slash.fill"),
        ("Circle badge", "bell.badge.circle"),
        ("Circle badge filled", "bell.badge.circle.fill"),
        ("Waves", "bell.and.waves.left.and.right"),
        ("Waves filled", "bell.and.waves.left.and.right.fill"),
        ("Badge waveform", "bell.badge.waveform"),
        ("Badge waveform filled", "bell.badge.waveform.fill"),
        ("Ring", "bell.circle"),
        ("Ring filled", "bell.circle.fill"),
        ("Square", "bell.square"),
        ("Square filled", "bell.square.fill"),
        ("Dot radiowaves", "dot.radiowaves.left.and.right"),
        ("App badge", "app.badge"),
        ("App badge filled", "app.badge.fill"),
        ("Megaphone", "megaphone"),
        ("Megaphone filled", "megaphone.fill"),
    ]

    private static let unreadSamples = [0, 1, 2, 9, 12, 99, 100, 250]

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.md, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                adminSection
                retailToolbarSection
                glassToolbarSection
                symbolGridSection
                sizeScaleSection
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Notification icons")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Admin app (WEARHOUSE Pro sidebar)")
            Text("Same `Label` + `systemImage` as `AdminSidebarSection.notifications` in `AdminDesktopShell`.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label {
                    Text("Notifications")
                        .foregroundStyle(Theme.Colors.primaryText)
                } icon: {
                    adminBellGlyph(size: 17, weight: .regular)
                }
                .font(.body)

                Label {
                    Text("Notifications")
                        .foregroundStyle(Theme.primaryColor)
                } icon: {
                    adminBellGlyph(size: 17, weight: .regular)
                }
                .font(.body)

                HStack(spacing: Theme.Spacing.md) {
                    adminBellGlyph(size: 22, weight: .regular)
                    adminBellGlyph(size: 22, weight: .semibold)
                    Image(systemName: Self.adminSidebarSymbol)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.primaryColor, Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.menuContainerCornerRadius, style: .continuous))
        }
    }

    private var retailToolbarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Retail app — NotificationToolbarBellVisual")
            Text("Home feed toolbar bell + red count (opaque badge).")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.lg) {
                    ForEach(Self.unreadSamples, id: \.self) { n in
                        VStack(spacing: 6) {
                            NotificationToolbarBellVisual(unreadCount: n)
                            Text("count \(n)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            HStack(spacing: Theme.Spacing.lg) {
                VStack(spacing: 6) {
                    NotificationToolbarBellVisual(emphasized: true)
                    Text("Console dot")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                VStack(spacing: 6) {
                    NotificationToolbarBellVisual(emphasized: false)
                    Text("No dot")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
    }

    private var glassToolbarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Glass circle (toolbar-style)")
            HStack(spacing: Theme.Spacing.md) {
                GlassIconButton(icon: "bell", iconColor: Theme.Colors.primaryText, action: {})
                GlassIconButton(icon: "bell.fill", iconColor: Theme.Colors.primaryText, action: {})
                GlassIconButton(icon: "bell.badge", iconColor: Theme.Colors.primaryText, action: {})
                GlassIconButton(icon: "bell.badge.fill", iconColor: Theme.primaryColor, action: {})
            }
        }
    }

    private var symbolGridSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("SF Symbol variants (grid)")
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(Self.symbolVariants, id: \.name) { item in
                    VStack(spacing: 6) {
                        Image(systemName: item.name)
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(height: 36)
                        Text(item.label)
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .lineLimit(3)
                        Text(item.name)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.secondaryBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var sizeScaleSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader("Admin symbol — size scale")
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                ForEach([14, 17, 20, 24, 28], id: \.self) { pt in
                    VStack(spacing: 4) {
                        adminBellGlyph(size: CGFloat(pt), weight: .regular)
                        Text("\(pt)pt")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primaryText)
    }
}

#Preview {
    NavigationStack {
        NotificationIconDebugView()
    }
    .preferredColorScheme(.dark)
}
