import SwiftUI

struct ProfileMenuView: View {
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    var onSelect: (MenuDestination) -> Void = { _ in }
    
    /// Listing count from user (show Shop Value when > 0)
    var listingCount: Int = 0
    var isMultiBuyEnabled: Bool = false
    var isVacationMode: Bool = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if listingCount > 0 {
                    MenuItemRow(title: "Shop Value", icon: "chart.bar.fill", action: { onDismiss(); onSelect(.shopValue) })
                    menuDivider
                }
                
                MenuItemRow(title: "Orders", icon: "bag.fill", action: { onDismiss(); onSelect(.orders) })
                menuDivider
                MenuItemRow(title: "Favourites", icon: "heart.fill", action: { onDismiss(); onSelect(.favourites) })
                menuDivider
                MenuItemRow(title: "Multi-buy discounts", subtitle: isMultiBuyEnabled ? "on" : "off", icon: "tag.fill", action: { onDismiss(); onSelect(.multiBuyDiscounts) })
                menuDivider
                MenuItemRow(title: "Vacation Mode", subtitle: isVacationMode ? "on" : "off", icon: "umbrella.fill", action: { onDismiss(); onSelect(.vacationMode) })
                menuDivider
                MenuItemRow(title: "Invite Friend", icon: "person.badge.plus.fill", action: { onDismiss(); onSelect(.inviteFriend) })
                menuDivider
                MenuItemRow(title: "Help Centre", icon: "questionmark.circle.fill", action: { onDismiss(); onSelect(.helpCentre) })
                menuDivider
                MenuItemRow(title: "About Prelura", icon: "info.circle.fill", action: { onDismiss(); onSelect(.aboutPrelura) })
                menuDivider
                MenuItemRow(title: "Settings", icon: "gearshape.fill", action: { onDismiss(); onSelect(.settings) })
                menuDivider
                MenuItemRow(title: "Logout", icon: "rectangle.portrait.and.arrow.right", action: { onDismiss(); onSelect(.logout) }, isDestructive: true)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(maxHeight: 400)
        .frame(width: 260)
        .glassEffect(cornerRadius: Theme.Glass.cornerRadius)
        .background(
            RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.1))
        )
    }
    
    private var menuDivider: some View {
        Divider()
            .background(Theme.Colors.glassBorder.opacity(0.3))
            .padding(.horizontal, Theme.Spacing.md)
    }
}

/// Reusable row content (icon + title + optional subtitle). Use for NavigationLink labels or inside Button.
struct MenuRowContent: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var isDestructive: Bool = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDestructive ? .red : Theme.primaryColor)
                .frame(width: 24, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(isDestructive ? .red : Theme.Colors.primaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.primaryColor)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct MenuItemRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    var body: some View {
        Button(action: action) {
            MenuRowContent(title: title, subtitle: subtitle, icon: icon, isDestructive: isDestructive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Submenu: Settings (Flutter SettingScreen). Presented as pushed destination; no own NavigationView.
struct SettingsMenuView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogoutConfirm = false
    var isStaff: Bool = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: AccountSettingsView()) {
                    settingsRow("Account Settings", icon: "person.crop.circle")
                }
                NavigationLink(destination: ShippingAddressView()) {
                    settingsRow("Shipping Address", icon: "location")
                }
                NavigationLink(destination: AppearanceMenuView()) {
                    settingsRow("Appearance", icon: "paintbrush")
                }
                NavigationLink(destination: ProfileSettingsView()) {
                    settingsRow("Profile details", icon: "person.text.rectangle")
                }
                NavigationLink(destination: PaymentSettingsView()) {
                    settingsRow("Payments", icon: "creditcard")
                }
                NavigationLink(destination: PostageSettingsView()) {
                    settingsRow("Postage", icon: "shippingbox")
                }
                NavigationLink(destination: SecurityMenuView()) {
                    settingsRow("Security & Privacy", icon: "lock.shield")
                }
                NavigationLink(destination: VerifyIdentityView()) {
                    settingsRow("Identity verification", icon: "checkmark.shield")
                }
                if isStaff {
                    NavigationLink(destination: AdminMenuView()) {
                        settingsRow("Admin Actions", icon: "shield")
                    }
                }
            }
            Section("Notifications") {
                NavigationLink(destination: NotificationSettingsView(title: "Push")) {
                    settingsRow("Push notifications", icon: "bell")
                }
                NavigationLink(destination: NotificationSettingsView(title: "Email")) {
                    settingsRow("Email notifications", icon: "envelope")
                }
            }
            Section {
                NavigationLink(destination: InviteFriendView()) {
                    settingsRow("Invite Friend", icon: "person.badge.plus")
                }
            }
            Section {
                Button(role: .destructive, action: { showLogoutConfirm = true }) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Log out")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .frame(width: 24, alignment: .leading)
            Text(title)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

// MARK: - Submenu: About Prelura (Flutter AboutPreluraMenuScreen). Presented as pushed destination.
struct AboutPreluraMenuView: View {
    var body: some View {
        List {
            NavigationLink(destination: HowToUsePreluraView()) {
                aboutRow("How to use Prelura", icon: "book.fill")
            }
            NavigationLink(destination: LegalInformationView()) {
                aboutRow("Legal Information", icon: "doc.text.fill")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("About Prelura")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func aboutRow(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(Theme.primaryColor)
                .frame(width: 24)
            Text(title)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

// MARK: - Help Centre (Flutter HelpCentre). Search, FAQ cards, topics, Start conversation → HelpChatView.
struct HelpCentreView: View {
    @State private var searchText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Got a burning question?")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.primaryText)

                DiscoverSearchField(
                    text: $searchText,
                    placeholder: "e.g. How do I change my profile photo?",
                    outerPadding: false
                )

                Text("Frequently asked")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        faqCard("How can I cancel an existing order")
                        faqCard("How long does a refund normally take?")
                        faqCard("When will I receive my item?")
                        faqCard("How will I know if my order has been shipped?")
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }

                Text("More topics")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)

                VStack(spacing: 0) {
                    helpTopicRow("What's a collection point?")
                    helpTopicRow("Item says \"Delivered\" but I don't have it")
                    helpTopicRow("What's Vacation mode?")
                    helpTopicRow("How do I earn a trusted seller badge?")
                }

                NavigationLink(destination: HelpChatView()) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Start a conversation")
                            .font(Theme.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Help Centre")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqCard(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.headline)
            .foregroundColor(.white)
            .frame(width: 140, height: 120, alignment: .bottomLeading)
            .padding(Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color(hex: "D78D8D"), Color(hex: "714A4A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func helpTopicRow(_ title: String) -> some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()
        
        ProfileMenuView(onDismiss: {}, listingCount: 5, isMultiBuyEnabled: true, isVacationMode: false)
            .padding()
    }
    .preferredColorScheme(.dark)
}
