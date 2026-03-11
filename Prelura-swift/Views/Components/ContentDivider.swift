import SwiftUI

/// Thin horizontal separator between content sections (e.g. Sell form, profile, item detail).
/// Use as a standalone view or in `.overlay(ContentDivider(), alignment: .bottom)` / `.top`.
/// Do not use for menu card row dividers (those stay as `menuDivider` in ProfileMenuView).
/// Height is 0.3pt max; colour is always Theme.Colors.glassBorder for consistency.
struct ContentDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 0.3)
            .foregroundColor(Theme.Colors.glassBorder)
    }
}
