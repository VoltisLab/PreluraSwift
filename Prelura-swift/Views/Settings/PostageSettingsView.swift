import SwiftUI

/// Postage settings (from Flutter postage_settings). Royal Mail, DPD sections with toggles and price fields.
struct PostageSettingsView: View {
    @State private var royalMailEnabled: Bool = false
    @State private var royalMailPrice: String = ""
    @State private var dpdEnabled: Bool = false
    @State private var dpdPrice: String = ""

    var body: some View {
        List {
            Section(header: Text(L10n.string("Royal Mail"))) {
                Toggle("Enable Royal Mail", isOn: $royalMailEnabled)
                    .tint(Theme.primaryColor)
                SettingsTextField(placeholder: "Price (£)", text: $royalMailPrice)
                    .keyboardType(.decimalPad)
                    .disabled(!royalMailEnabled)
            }
            .listRowBackground(Theme.Colors.background)
            Section(header: Text(L10n.string("DPD"))) {
                Toggle("Enable DPD", isOn: $dpdEnabled)
                    .tint(Theme.primaryColor)
                SettingsTextField(placeholder: "Price (£)", text: $dpdPrice)
                    .keyboardType(.decimalPad)
                    .disabled(!dpdEnabled)
            }
            .listRowBackground(Theme.Colors.background)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Postage"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
