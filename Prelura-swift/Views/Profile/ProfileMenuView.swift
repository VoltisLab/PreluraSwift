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
                    MenuItemRow(title: L10n.string("Shop Value"), icon: "chart.bar.fill", action: { onDismiss(); onSelect(.shopValue) })
                    menuDivider
                }
                
                MenuItemRow(title: L10n.string("Orders"), icon: "bag.fill", action: { onDismiss(); onSelect(.orders) })
                menuDivider
                MenuItemRow(title: L10n.string("Favourites"), icon: "heart.fill", action: { onDismiss(); onSelect(.favourites) })
                menuDivider
                MenuItemRow(title: L10n.string("Multi-buy discounts"), subtitle: isMultiBuyEnabled ? L10n.string("On") : L10n.string("Off"), icon: "tag.fill", action: { onDismiss(); onSelect(.multiBuyDiscounts) })
                menuDivider
                MenuItemRow(title: L10n.string("Vacation Mode"), subtitle: isVacationMode ? L10n.string("On") : L10n.string("Off"), icon: "umbrella.fill", action: { onDismiss(); onSelect(.vacationMode) })
                menuDivider
                MenuItemRow(title: L10n.string("Invite Friend"), icon: "person.badge.plus.fill", action: { onDismiss(); onSelect(.inviteFriend) })
                menuDivider
                MenuItemRow(title: L10n.string("Help Centre"), icon: "questionmark.circle.fill", action: { onDismiss(); onSelect(.helpCentre) })
                menuDivider
                MenuItemRow(title: L10n.string("About Prelura"), icon: "info.circle.fill", action: { onDismiss(); onSelect(.aboutPrelura) })
                menuDivider
                MenuItemRow(title: L10n.string("Settings"), icon: "gearshape.fill", action: { onDismiss(); onSelect(.settings) })
                menuDivider
                MenuItemRow(title: L10n.string("Logout"), icon: "rectangle.portrait.and.arrow.right", action: { onDismiss(); onSelect(.logout) }, isDestructive: true)
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
                        .font(.system(size: 14))
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
    var isStaff: Bool = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: AccountSettingsView()) {
                    settingsRow(L10n.string("Account Settings"), icon: "person.crop.circle")
                }
                NavigationLink(destination: CurrencySettingsView()) {
                    settingsRow(L10n.string("Currency"), icon: "dollarsign.circle")
                }
                NavigationLink(destination: PrivacySettingsView()) {
                    settingsRow(L10n.string("Privacy"), icon: "hand.raised")
                }
                NavigationLink(destination: ShippingAddressView()) {
                    settingsRow(L10n.string("Shipping Address"), icon: "location")
                }
                NavigationLink(destination: AppearanceMenuView()) {
                    settingsRow(L10n.string("Appearance"), icon: "paintbrush")
                }
                NavigationLink(destination: LanguageMenuView()) {
                    settingsRow(L10n.string("Language"), icon: "globe")
                }
                NavigationLink(destination: ProfileSettingsView()) {
                    settingsRow(L10n.string("Profile details"), icon: "person.text.rectangle")
                }
                NavigationLink(destination: PaymentSettingsView()) {
                    settingsRow(L10n.string("Payments"), icon: "creditcard")
                }
                NavigationLink(destination: PostageSettingsView()) {
                    settingsRow(L10n.string("Postage"), icon: "shippingbox")
                }
                NavigationLink(destination: SecurityMenuView()) {
                    settingsRow(L10n.string("Security & Privacy"), icon: "lock.shield")
                }
                NavigationLink(destination: VerifyIdentityView()) {
                    settingsRow(L10n.string("Identity verification"), icon: "checkmark.shield")
                }
                if isStaff {
                    NavigationLink(destination: AdminMenuView()) {
                        settingsRow(L10n.string("Admin Actions"), icon: "shield")
                    }
                }
            }
            Section(L10n.string("Notifications")) {
                NavigationLink(destination: NotificationSettingsView(title: L10n.string("Push notifications"))) {
                    settingsRow(L10n.string("Push notifications"), icon: "bell")
                }
                NavigationLink(destination: NotificationSettingsView(title: L10n.string("Email notifications"))) {
                    settingsRow(L10n.string("Email notifications"), icon: "envelope")
                }
            }
            Section {
                NavigationLink(destination: InviteFriendView()) {
                    settingsRow(L10n.string("Invite Friend"), icon: "person.badge.plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
                aboutRow(L10n.string("How to use Prelura"), icon: "book")
            }
            NavigationLink(destination: LegalInformationView()) {
                aboutRow(L10n.string("Legal Information"), icon: "doc.text")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("About Prelura"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func aboutRow(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(width: 24)
            Text(title)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

// MARK: - Help Centre (Flutter HelpCentre). Search, FAQ cards, topics, Start conversation → HelpChatView.
struct HelpCentreView: View {
    @State private var searchText: String = ""

    private var moreTopicsLocalized: [String] {
        [
            L10n.string("What's a collection point?"),
            L10n.string("Item says \"Delivered\" but I don't have it"),
            L10n.string("What's Vacation mode?"),
            L10n.string("How do I earn a trusted seller badge?")
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    DiscoverSearchField(
                        text: $searchText,
                        placeholder: L10n.string("e.g. How do I change my profile photo?"),
                        outerPadding: false,
                        topPadding: Theme.Spacing.xs
                    )
                    .padding(.trailing, Theme.Spacing.sm)

                    Text(L10n.string("Got a burning question?"))
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(L10n.string("Frequently asked"))
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            faqCard(L10n.string("How can I cancel an existing order"))
                            faqCard(L10n.string("How long does a refund normally take?"))
                            faqCard(L10n.string("When will I receive my item?"))
                            faqCard(L10n.string("How will I know if my order has been shipped?"))
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    Text(L10n.string("More topics"))
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)

                    VStack(spacing: 0) {
                        ForEach(Array(moreTopicsLocalized.enumerated()), id: \.offset) { index, title in
                            helpTopicRow(title)
                                .overlay(alignment: .bottom) {
                                    if index < moreTopicsLocalized.count - 1 {
                                        ContentDivider()
                                    }
                                }
                        }
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Glass.cornerRadius)

                    Color.clear.frame(height: 100)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                NavigationLink(destination: HelpChatView()) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L10n.string("Start a conversation"))
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
        }
        .navigationTitle(L10n.string("Help Centre"))
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
