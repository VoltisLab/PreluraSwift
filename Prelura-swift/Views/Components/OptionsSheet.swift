import SwiftUI

/// Reusable modal sheet with title, close button, and consistent presentation. Use for product options, sort, filter, and similar modals.
/// For multiple related sheets (sort / filter / search), use one `.sheet(item:)` with an `Identifiable` enum; chaining several `.sheet(isPresented:)` on the same view stacks modals when more than one binding is true.
/// Matches Sort modal: one colour (Theme.Colors.modalSheetBackground) for nav bar and content area.
struct OptionsSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent] = [.height(300)]
    /// When false, uses system default sheet corner radius (e.g. product Options modal).
    var useCustomCornerRadius: Bool = true
    @ViewBuilder let content: () -> Content

    private var sheetBackground: Color { Theme.Colors.modalSheetBackground }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.secondaryBackground.opacity(0.35))
                        .clipShape(Circle())
                }
                .padding(.trailing, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(sheetBackground)
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
