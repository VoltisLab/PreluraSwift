import SwiftUI

/// Shipping Address (from Flutter shipping_address_view). Loads from ViewMe, saves via updateProfile(shippingAddress:).
struct ShippingAddressView: View {
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var country: String = "United Kingdom"
    @State private var postcode: String = ""

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private let userService = UserService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Address")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Address line 1")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(placeholder: "Street address", text: $addressLine1, textContentType: .streetAddressLine1)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Address line 2")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(placeholder: "Apartment, suite, etc. (optional)", text: $addressLine2, textContentType: .streetAddressLine2)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("City")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(placeholder: "City", text: $city, textContentType: .addressCity)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("State / County")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(placeholder: "State or county", text: $state, textContentType: .addressState)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Country")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(country)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(30)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Postcode")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(placeholder: "Postcode", text: $postcode, textContentType: .postalCode)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.red)
                }

                Button(action: save) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Save")
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(canSave ? Theme.primaryColor : Theme.primaryColor.opacity(0.5))
                    .cornerRadius(30)
                }
                .disabled(!canSave || isSaving)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Shipping Address")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: loadUser)
        .alert("Saved", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your shipping address has been updated.")
        }
    }

    private var canSave: Bool {
        !addressLine1.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && !postcode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadUser() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let user = try await userService.getUser()
                await MainActor.run {
                    if let addr = user.shippingAddress {
                        addressLine1 = addr.address
                        addressLine2 = addr.state ?? ""
                        city = addr.city
                        state = addr.state ?? ""
                        country = addr.country == "GB" ? "United Kingdom" : addr.country
                        postcode = addr.postcode
                    } else {
                        country = "United Kingdom"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        errorMessage = nil
        isSaving = true
        let address = addressLine1.trimmingCharacters(in: .whitespaces)
        let cityVal = city.trimmingCharacters(in: .whitespaces)
        let postcodeVal = postcode.trimmingCharacters(in: .whitespaces)
        let shipping = ShippingAddress(
            address: address,
            city: cityVal,
            state: state.isEmpty ? nil : state,
            country: "GB",
            postcode: postcodeVal
        )
        Task {
            do {
                try await userService.updateProfile(shippingAddress: shipping)
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
