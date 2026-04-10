import SwiftUI

/// Currency setting screen (Flutter CurrencySettingRoute).
struct CurrencySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCurrency: String = CurrencyOption.gbp
    @State private var saved = false

    private enum CurrencyOption {
        static let gbp = "British Pound (GBP)"
        static let euro = "Euro (EUR)"
    }

    private let currencies = [CurrencyOption.gbp, CurrencyOption.euro]

    var body: some View {
        List {
            ForEach(currencies, id: \.self) { currency in
                let isEuro = currency == CurrencyOption.euro
                Button {
                    guard !isEuro else { return }
                    selectedCurrency = currency
                } label: {
                    HStack {
                        Text(currency)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Spacer()
                        if selectedCurrency == currency, !isEuro {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .blur(radius: isEuro ? 5 : 0)
                }
                .disabled(isEuro)
                .buttonStyle(PlainTappableButtonStyle())
            }
            if saved {
                Text(L10n.string("Saved"))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.primaryColor)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .onAppear {
            if selectedCurrency == CurrencyOption.euro {
                selectedCurrency = CurrencyOption.gbp
            }
        }
        .navigationTitle(L10n.string("Currency"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // TODO: Persist currency preference
                    saved = true
                }
                .foregroundColor(Theme.primaryColor)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
}
