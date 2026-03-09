import SwiftUI

/// Postage settings (from Flutter postage_settings). Royal Mail, DPD sections with toggles and price fields.
struct PostageSettingsView: View {
    @State private var royalMailEnabled: Bool = false
    @State private var royalMailPrice: String = ""
    @State private var dpdEnabled: Bool = false
    @State private var dpdPrice: String = ""

    var body: some View {
        List {
            Section(header: Text("Royal Mail")) {
                Toggle("Enable Royal Mail", isOn: $royalMailEnabled)
                    .tint(Theme.primaryColor)
                TextField("Price (£)", text: $royalMailPrice)
                    .keyboardType(.decimalPad)
                    .disabled(!royalMailEnabled)
            }
            Section(header: Text("DPD")) {
                Toggle("Enable DPD", isOn: $dpdEnabled)
                    .tint(Theme.primaryColor)
                TextField("Price (£)", text: $dpdPrice)
                    .keyboardType(.decimalPad)
                    .disabled(!dpdEnabled)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Postage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
