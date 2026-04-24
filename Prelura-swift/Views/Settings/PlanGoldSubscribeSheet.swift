import SwiftUI

/// Subscribe to Gold: tries **StoreKit** first (Apple’s sheet includes Apple Pay / cards / account balance). Falls back to local preview when the product is not configured.
struct PlanGoldSubscribeSheet: View {
    let authToken: String?
    let onSubscribed: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isLoadingProduct = true
    @State private var productAvailable = false
    @State private var errorMessage: String?
    @State private var isEnablingPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                PlanScreenAnimatedBackground()
                    .opacity(0.55)
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(colors: [PlanPalette.goldA, Theme.primaryColor, PlanPalette.mysticB], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(height: 5)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(L10n.string("£10.99/month"))
                                .font(Theme.Typography.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Text(L10n.string("Billed monthly. Cancel anytime in Settings → Apple ID → Subscriptions."))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Text(L10n.string("Gold unlocks more mystery box listings and priority visibility. Complete payment in Apple’s sheet - Apple Pay appears automatically when you have it set up."))
                            .font(Theme.Typography.body)
                            .foregroundStyle(.white.opacity(0.88))

                        if isLoadingProduct {
                            ProgressView()
                                .tint(Theme.primaryColor)
                                .frame(maxWidth: .infinity)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.red.opacity(0.95))
                        }

                        PrimaryGlassButton(L10n.string("Subscribe with App Store"), isEnabled: productAvailable && !isPurchasing, isLoading: isPurchasing) {
                            Task { await subscribeWithStoreKit() }
                        }

                        BorderGlassButton(L10n.string("Enable Gold (preview - no charge)"), isEnabled: !isEnablingPreview && !isPurchasing) {
                            Task { await enablePreviewGold() }
                        }
                        .opacity(productAvailable ? 0.55 : 1)

                        Text(L10n.string("Preview updates your profile with Gold and a renewal date on the server (no App Store charge)."))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        BorderGlassButton(L10n.string("Cancel")) {
                            onDismiss()
                            dismiss()
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle(L10n.string("Upgrade to Gold"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(Theme.effectiveColorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .task { await refreshProductAvailability() }
        }
    }

    private func refreshProductAvailability() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let p = try await SellerGoldSubscriptionService.loadGoldProduct()
            await MainActor.run {
                productAvailable = p != nil
            }
        } catch {
            await MainActor.run {
                productAvailable = false
            }
        }
    }

    private func subscribeWithStoreKit() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await SellerGoldSubscriptionService.purchaseGoldMonthly(authToken: authToken)
            onSubscribed()
            dismiss()
        } catch let e as SellerGoldSubscriptionError {
            errorMessage = e.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enablePreviewGold() async {
        await MainActor.run {
            isEnablingPreview = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isEnablingPreview = false
            }
        }
        let svc = UserService()
        svc.updateAuthToken(authToken)
        let cal = Calendar.current
        let exp = cal.date(byAdding: .month, value: 1, to: Date()) ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        do {
            try await svc.updateProfile(meta: [
                "sellerGoldRenewsAt": iso.string(from: exp),
                "sellerGoldPreview": true,
            ])
            await MainActor.run {
                SellerPlanUserDefaults.localPlan = .gold
                onSubscribed()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = L10n.userFacingError(error)
            }
        }
    }
}
