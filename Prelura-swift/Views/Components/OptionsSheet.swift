import SwiftUI

/// Reusable modal sheet with title, close button, and consistent presentation. Use for product options, sort, filter, and similar modals.
struct OptionsSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent] = [.height(300)]
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
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
        .presentationBackground(Theme.Colors.background)
    }
}
