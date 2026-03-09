import SwiftUI

/// Appearance: theme (System / Light / Dark) and language. Drives light mode for all screens, components, and elements via `appearance_mode` → Theme.effectiveColorScheme + .preferredColorScheme.
struct AppearanceMenuView: View {
    @AppStorage(kAppearanceMode) private var appearanceMode: String = "system"

    private let options: [(id: String, title: String)] = [
        ("system", "Use System Settings"),
        ("light", "Light"),
        ("dark", "Dark")
    ]

    var body: some View {
        List {
            Section {
                ForEach(options, id: \.id) { option in
                    Button(action: { appearanceMode = option.id }) {
                        HStack {
                            Text(option.title)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if appearanceMode == option.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Light and Dark apply to all screens, components, and elements. System follows your device setting.")
            }

            Section(header: Text("Your app's language")) {
                HStack {
                    Text("Language")
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    Text("English (EN)")
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
