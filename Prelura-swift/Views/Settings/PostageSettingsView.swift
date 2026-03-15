import SwiftUI

/// Postage settings (from Flutter postage_settings). Royal Mail (with First Class option), DPD; toggles and price fields.
/// Loads/saves via viewMe meta and updateProfile(meta:). Buyers see these options at checkout.
struct PostageSettingsView: View {
    @State private var royalMailEnabled: Bool = false
    @State private var royalMailStandardPrice: String = ""
    @State private var royalMailFirstClassPrice: String = ""
    @State private var dpdEnabled: Bool = false
    @State private var dpdPrice: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @EnvironmentObject private var authService: AuthService

    @FocusState private var focusedField: Field?
    private enum Field { case royalMailStandard, royalMailFirstClass, dpdPrice }
    private let userService = UserService()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Royal Mail
                    sectionHeader(L10n.string("Royal Mail"))
                Toggle(L10n.string("Enable Royal Mail"), isOn: $royalMailEnabled)
                    .tint(Theme.primaryColor)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Glass.menuContainerCornerRadius)

                if royalMailEnabled {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(L10n.string("Standard Shipping"))
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("£")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                TextField("0", text: $royalMailStandardPrice)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .royalMailStandard)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(30)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(L10n.string("First Class (Next day)"))
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("£")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                TextField("0", text: $royalMailFirstClassPrice)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .royalMailFirstClass)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .cornerRadius(30)
                        }
                    }
                }

                // DPD
                sectionHeader(L10n.string("DPD"))
                Toggle(L10n.string("Enable DPD"), isOn: $dpdEnabled)
                    .tint(Theme.primaryColor)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(Theme.Glass.menuContainerCornerRadius)

                if dpdEnabled {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(L10n.string("Standard Shipping"))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("£")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            TextField("0", text: $dpdPrice)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .dpdPrice)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(30)
                    }
                }

                    if let msg = errorMessage {
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                            .padding(.top, Theme.Spacing.sm)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Theme.Colors.background)

            PrimaryButtonBar {
                PrimaryGlassButton(L10n.string("Save"), isLoading: isSaving, action: savePostage)
            }
        }
        .navigationTitle(L10n.string("Postage"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadPostage() }
        .alert(L10n.string("Saved"), isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.string("Your postage settings have been saved."))
        }
    }

    private func loadPostage() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        userService.updateAuthToken(authService.authToken)
        do {
            let user = try await userService.getUser(username: nil)
            await MainActor.run {
                if let opts = user.postageOptions {
                    royalMailEnabled = opts.royalMailEnabled
                    royalMailStandardPrice = opts.royalMailStandardPrice.map { String(format: "%.2f", $0) } ?? ""
                    royalMailFirstClassPrice = opts.royalMailFirstClassPrice.map { String(format: "%.2f", $0) } ?? ""
                    dpdEnabled = opts.dpdEnabled
                    dpdPrice = opts.dpdPrice.map { String(format: "%.2f", $0) } ?? ""
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func savePostage() {
        focusedField = nil
        isSaving = true
        errorMessage = nil
        let opts = SellerPostageOptions(
            royalMailEnabled: royalMailEnabled,
            royalMailStandardPrice: Double(royalMailStandardPrice.trimmingCharacters(in: .whitespaces)),
            royalMailFirstClassPrice: Double(royalMailFirstClassPrice.trimmingCharacters(in: .whitespaces)),
            dpdEnabled: dpdEnabled,
            dpdPrice: Double(dpdPrice.trimmingCharacters(in: .whitespaces))
        )
        let fullMeta: [String: Any] = ["postage": opts.toMetaPostage()]
        Task {
            defer { Task { @MainActor in isSaving = false } }
            userService.updateAuthToken(authService.authToken)
            do {
                try await userService.updateProfile(meta: fullMeta)
                await MainActor.run {
                    errorMessage = nil
                    showSuccess = true
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.primaryText)
    }
}
