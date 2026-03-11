import SwiftUI

/// Thin horizontal separator between content sections (e.g. above Categories on profile).
/// Use as a standalone view or in `.overlay(ContentDivider(), alignment: .bottom)` / `.top`.
/// Do not use for menu card row dividers (those stay as `menuDivider` in ProfileMenuView).
/// Height is 1 physical pixel (1/displayScale) so all dividers render the same, avoiding the
/// brighter look that 0.5pt can get when it lands on half-pixel boundaries.
struct ContentDivider: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .frame(height: max(1.0 / CGFloat(displayScale), 0.5))
            .foregroundColor(Theme.Colors.glassBorder)
    }
}
