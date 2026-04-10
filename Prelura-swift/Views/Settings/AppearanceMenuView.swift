import SwiftUI
import UIKit

/// Appearance: theme (System / Light / Dark) and alternate Home Screen app icon. Language is in Settings > Language.
struct AppearanceMenuView: View {
    @AppStorage(kAppearanceMode) private var appearanceMode: String = "system"
    @AppStorage(kAlternateAppIcon) private var storedIconRaw: String = AlternateAppIconChoice.primary.rawValue

    private var themeOptions: [(id: String, title: String)] {
        [
            ("system", L10n.string("Use System Settings")),
            ("light", L10n.string("Light")),
            ("dark", L10n.string("Dark"))
        ]
    }

    private var iconOptions: [(choice: AlternateAppIconChoice, title: String)] {
        [
            (.primary, L10n.string("Primary Logo")),
            (.gradient, L10n.string("Gradient Logo")),
            (.gradient3D, L10n.string("Gradient 3D Logo")),
            (.black, L10n.string("Black Logo"))
        ]
    }

    private var selectedIcon: AlternateAppIconChoice {
        AlternateAppIconChoice.resolved(stored: storedIconRaw)
    }

    var body: some View {
        List {
            Section {
                ForEach(themeOptions, id: \.id) { option in
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
                Text(L10n.string("Theme"))
            } footer: {
                Text(L10n.string("Light and Dark apply to all screens, components, and elements. System follows your device setting."))
            }

            Section {
                ForEach(iconOptions, id: \.choice.id) { row in
                    Button {
                        guard selectedIcon != row.choice else { return }
                        let previous = storedIconRaw
                        storedIconRaw = row.choice.rawValue
                        row.choice.apply { error in
                            if error != nil {
                                storedIconRaw = previous
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(row.choice.previewImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(row.title)
                                .foregroundColor(Theme.Colors.primaryText)

                            Spacer()

                            if selectedIcon == row.choice {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .disabled(!UIApplication.shared.supportsAlternateIcons)
                }
            } header: {
                Text(L10n.string("App Icon"))
            } footer: {
                Text(
                    L10n.string(
                        "You may see a brief iOS confirmation when changing the icon. The new icon appears on the Home Screen and in the app switcher."
                    )
                )
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Appearance"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
