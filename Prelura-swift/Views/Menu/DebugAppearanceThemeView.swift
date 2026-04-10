import SwiftUI

/// Debug menu copy of **Settings → Appearance → Theme** (system / light / dark) to compare behaviour outside the normal settings stack.
struct DebugAppearanceThemeView: View {
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
                    Button {
                        appearanceMode = option.id
                    } label: {
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
                    .buttonStyle(PlainTappableButtonStyle())
                }
            } header: {
                Text("Theme (debug copy)")
            } footer: {
                Text("Same keys as Settings → Appearance. Use this to compare behaviour outside the normal settings stack.")
                    .font(Theme.Typography.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Debug: Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
