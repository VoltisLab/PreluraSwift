import SwiftUI

/// Static bottom bar that holds the main primary (filled) CTA. Use with ZStack(alignment: .bottom) so content scrolls above it.
/// Matches ItemDetailView / PaymentView: background, ContentDivider on top, padding, safe area at bottom.
struct PrimaryButtonBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.background)
            .overlay(ContentDivider(), alignment: .top)
            .ignoresSafeArea(edges: .bottom)
    }
}
