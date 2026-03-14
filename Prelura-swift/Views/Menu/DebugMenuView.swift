import SwiftUI

/// Debug menu screen – submenu for debug tools and component showcase.
struct DebugMenuView: View {
    var body: some View {
        List {
            Section {
                Text("Build: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            } header: {
                Text("Info")
            }
            Section {
                NavigationLink(destination: ProfileCardsComponentsView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Profile cards, and components")
                    }
                }
                NavigationLink(destination: GlassMaterialsView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "drop.fill")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Glass materials")
                    }
                }
                NavigationLink(destination: GlassEffectTransitionView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Glass effect transition")
                    }
                }
                NavigationLink(destination: BlackScreensMenuView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "square.fill")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Black screens")
                    }
                }
                NavigationLink(destination: DashboardView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Dashboard")
                    }
                }
                NavigationLink(destination: OrderScreenDebugView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Order screen")
                    }
                }
                NavigationLink(destination: LookbooksUploadView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "photo.stack")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text("Lookbooks Upload")
                    }
                }
                NavigationLink(destination: ShopToolsView()) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Text(L10n.string("Shop tools"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
