import SwiftUI

/// Settings → Plan: Silver (default) vs Gold; optional unlimited mystery add-on (paywall stub until StoreKit).
struct PlanSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    private let userService = UserService()

    @State private var profileTier: String = ""
    @State private var showGoldPaywall = false
    @State private var showUnlimitedPaywall = false

    private var serverGold: Bool { SellerMysteryQuota.apiProfileIndicatesGoldTier(profileTier) }
    private var localGold: Bool { SellerPlanUserDefaults.localPlan == .gold }
    private var isGoldEffective: Bool { serverGold || localGold }
    private var unlimitedMystery: Bool { SellerPlanUserDefaults.unlimitedMysterySubscribed }

    private var currentPlanTitle: String {
        if unlimitedMystery {
            return L10n.string("Gold + unlimited mystery")
        }
        if isGoldEffective {
            return L10n.string("Gold")
        }
        return L10n.string("Silver")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Your plan"))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(currentPlanTitle)
                        .font(Theme.Typography.title2.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                    if serverGold {
                        Text(L10n.string("Your Wearhouse profile tier includes Gold benefits."))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }

            Section(header: Text(L10n.string("Silver"))) {
                planBullet(L10n.string("Unlimited product uploads"))
                planBullet(L10n.string("Up to 2 active mystery box listings"))
                planBullet(L10n.string("0% selling fees"))
                if !isGoldEffective {
                    Label(L10n.string("Current plan"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.primaryColor)
                }
            }

            Section(header: Text(L10n.string("Gold"))) {
                planBullet(L10n.string("Everything in Silver"))
                planBullet(L10n.string("Up to 5 active mystery box listings"))
                planBullet(L10n.string("0% selling fees"))
                planBullet(L10n.string("Priority placement in search & category browsing"))
                planBullet(L10n.string("Priority seller support"))
                if isGoldEffective && !serverGold {
                    Label(L10n.string("Current plan"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.primaryColor)
                }
                if !isGoldEffective {
                    Button {
                        showGoldPaywall = true
                    } label: {
                        Text(L10n.string("Upgrade to Gold"))
                            .font(Theme.Typography.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryColor)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else if !serverGold {
                    Button(role: .destructive) {
                        SellerPlanUserDefaults.localPlan = .silver
                    } label: {
                        Text(L10n.string("Remove local Gold preview"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Section(
                header: Text(L10n.string("Unlimited mystery boxes")),
                footer: Text(L10n.string("Requires an active Gold plan. Billed monthly when in-app purchases go live."))
            ) {
                planBullet(L10n.string("No cap on active mystery box listings"))
                planBullet(L10n.string("£10.99/month after purchase"))
                if unlimitedMystery {
                    Label(L10n.string("Subscribed (preview)"), systemImage: "checkmark.circle.fill")
                        .foregroundColor(Theme.primaryColor)
                    Button(role: .destructive) {
                        SellerPlanUserDefaults.unlimitedMysterySubscribed = false
                    } label: {
                        Text(L10n.string("Turn off preview subscription"))
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button {
                        showUnlimitedPaywall = true
                    } label: {
                        Text(L10n.string("Subscribe — £10.99/month"))
                            .font(Theme.Typography.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isGoldEffective)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadProfileTier() }
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

    private func planBullet(_ text: String) -> some View {
        Label {
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
        } icon: {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.primaryColor)
        }
    }

    private func loadProfileTier() async {
        userService.updateAuthToken(authService.authToken)
        do {
            let user = try await userService.getUser(username: nil)
            await MainActor.run { profileTier = user.profileTier }
        } catch {
            await MainActor.run { profileTier = "" }
        }
    }
}

private struct PlanPaywallSheet: View {
    let title: String
    let message: String
    let primaryTitle: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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
