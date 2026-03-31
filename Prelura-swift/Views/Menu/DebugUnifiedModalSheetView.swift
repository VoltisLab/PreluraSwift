import SwiftUI

// MARK: - Unified modal sheet (prototype; light/dark via Theme + system colors)

/// Single continuous surface for drag indicator, title bar, and content—no extra stacked sheet backgrounds.
/// Uses `Theme.Colors.modalSheetBackground` (follows `Theme.effectiveColorScheme`) and `UIColor.label` / `separator` for system adaptation.
struct PreluraUnifiedModalSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent] = [.medium]
    var usePresentationCornerRadius: Bool = true
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
                        .background(Theme.Colors.secondaryBackground.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(.trailing, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground)
        .presentationDetents(Set(detents))
        .presentationDragIndicator(.visible)
        .presentationBackground(sheetBackground)
        .modifier(UnifiedSheetCornerRadiusModifier(apply: usePresentationCornerRadius))
    }
}

private struct UnifiedSheetCornerRadiusModifier: ViewModifier {
    var apply: Bool
    func body(content: Content) -> some View {
        if apply, #available(iOS 16.4, *) {
            content.presentationCornerRadius(20)
        } else {
            content
        }
    }
}

private struct UnifiedModalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: UIColor.separator))
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }
}

// MARK: - Debug screen

/// Presents the unified sheet with mock actions; toggle system appearance to verify light/dark.
struct DebugUnifiedModalSheetView: View {
    @State private var showSheet = false
    @Environment(\.colorScheme) private var colorScheme

    private var mockRows: [(title: String, icon: String)] {
        [
            ("Share", "square.and.arrow.up"),
            ("Report listing", "flag"),
            ("Copy link", "link"),
            ("Save for later", "bookmark"),
            ("Not interested", "hand.thumbsdown"),
        ]
    }

    var body: some View {
        List {
            Section {
                Text("Uses Theme.effectiveColorScheme for sheet chrome and UIColor.separator for dividers. Toggle Appearance in Settings to verify.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            Section {
                LabeledContent("SwiftUI colorScheme") {
                    Text(colorScheme == .dark ? "dark" : "light")
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Button("Show mock options sheet") {
                    showSheet = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Unified modal sheet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSheet) {
            PreluraUnifiedModalSheet(
                title: "Options",
                onDismiss: { showSheet = false },
                detents: [.height(340), .medium],
                usePresentationCornerRadius: true
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mockRows.enumerated()), id: \.offset) { index, row in
                        MenuItemRow(
                            title: row.title,
                            icon: row.icon,
                            action: { showSheet = false },
                            iconAndSubtitleColor: Theme.Colors.secondaryText
                        )
                        if index < mockRows.count - 1 {
                            UnifiedModalDivider()
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
    }
}

#if DEBUG
#Preview("Debug unified sheet host") {
    NavigationStack {
        DebugUnifiedModalSheetView()
    }
}
#endif
