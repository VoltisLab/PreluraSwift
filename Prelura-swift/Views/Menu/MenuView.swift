import SwiftUI

/// Full-screen Menu page (matches Flutter MenuPage). Pushed from Profile. Uses system navigation bar.
struct MenuView: View {
    @EnvironmentObject var authService: AuthService

    var listingCount: Int = 0
    var isMultiBuyEnabled: Bool = false
    var isVacationMode: Bool = false
    var isStaff: Bool = false

    @State private var showLogoutConfirm = false

    var body: some View {
        List {
            if listingCount > 0 {
                NavigationLink(destination: ShopValueView(listingCount: listingCount)) {
                    menuRow("Shop Value", icon: "chart.bar")
                }
            }
            NavigationLink(destination: MyOrdersView()) {
                menuRow("Orders", icon: "bag")
            }
            NavigationLink(destination: MyFavouritesView()) {
                menuRow("Favourites", icon: "heart")
            }
            NavigationLink(destination: MultiBuyDiscountView()) {
                HStack {
                    menuRow("Multi-buy discounts", icon: "tag")
                    Spacer()
                    Text(isMultiBuyEnabled ? "on" : "off")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            NavigationLink(destination: VacationModeView(initialIsOn: isVacationMode)) {
                HStack {
                    menuRow("Vacation Mode", icon: "umbrella")
                    Spacer()
                    Text(isVacationMode ? "on" : "off")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            NavigationLink(destination: InviteFriendView()) {
                menuRow("Invite Friend", icon: "person.badge.plus")
            }
            NavigationLink(destination: HelpCentreView()) {
                menuRow("Help Centre", icon: "questionmark.circle")
            }
            NavigationLink(destination: AboutPreluraMenuView()) {
                menuRow("About Prelura", icon: "info.circle")
            }
            Button(role: .destructive, action: { showLogoutConfirm = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.body)
                    Text("Logout")
                    Spacer()
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("© Prelura 2026")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsMenuView(isStaff: isStaff)) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .alert("Logout", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                Task {
                    try? await authService.logout()
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
    }
    
    private func menuRow(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text(title)
        }
    }
}
