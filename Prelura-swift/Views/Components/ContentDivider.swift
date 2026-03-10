import SwiftUI

/// Thin horizontal separator between content sections (e.g. above Categories on profile).
/// Use as a standalone view or in `.overlay(ContentDivider(), alignment: .bottom)` / `.top`.
/// Do not use for menu card row dividers (those stay as `menuDivider` in ProfileMenuView).
struct ContentDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundColor(Theme.Colors.glassBorder)
    }
}
