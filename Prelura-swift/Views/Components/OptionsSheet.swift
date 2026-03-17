import SwiftUI

/// Reusable modal sheet with title, close button, and consistent presentation. Use for product options, sort, filter, and similar modals.
/// Matches Sort modal: one colour (Theme.Colors.background) for nav bar and content area so no grey/split.
struct OptionsSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent] = [.height(300)]
    /// When false, uses system default sheet corner radius (e.g. product Options modal).
    var useCustomCornerRadius: Bool = true
    @ViewBuilder let content: () -> Content

    private var sheetBackground: Color { Theme.Colors.background }

    var body: some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(sheetBackground)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(sheetBackground, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                }
        }
        .presentationDetents(Set(detents))
        .presentationDragIndicator(.visible)
        .presentationBackground(sheetBackground)
        .modifier(SheetCornerRadiusModifier(apply: useCustomCornerRadius))
    }
}

/// Applies presentation corner radius when available (iOS 16.4+). When apply is false, leaves system default (e.g. product Options sheet).
private struct SheetCornerRadiusModifier: ViewModifier {
    var apply: Bool = true
    func body(content: Content) -> some View {
        if apply, #available(iOS 16.4, *) {
            content.presentationCornerRadius(20)
        } else {
            content
        }
    }
}
