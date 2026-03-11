import SwiftUI

/// Debug: menu of dark background hex codes. Tapping one opens a profile-style preview with that background.
struct BlackScreensMenuView: View {
    /// De-duplicated list (user had 1B1B1B twice).
    private static let colorCodes: [String] = [
        "1B1B1B",
        "0C0C0C",
        "191919",
        "252525",
        "313638",
        "002147"
    ]

    var body: some View {
        List {
            Section {
                Text("Tap a code to see the profile layout on that dark background.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            } header: {
                Text("Preview")
            }
            Section {
                ForEach(Self.colorCodes, id: \.self) { hex in
                    NavigationLink(destination: BlackScreenProfileView(hex: hex)) {
                        HStack(spacing: Theme.Spacing.md) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: hex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                                )
                            Text(hex)
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                }
            } header: {
                Text("Colour codes")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Black screens")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
