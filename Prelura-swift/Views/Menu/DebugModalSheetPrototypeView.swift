import SwiftUI

// MARK: - Unified modal sheet (prototype; intended to replace OptionsSheet + stacked presentation backgrounds)

/// Single-surface modal: header and list share one background so there is no two-tone sheet.
/// Uses `Theme` surfaces and UIKit semantic colors so light/dark track the app appearance.
struct PreluraUnifiedModalSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var detents: [PresentationDetent] = [.height(320)]
    var presentationCornerRadiusPoints: CGFloat = 20
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(sheetBackground)
        .presentationDetents(Set(detents))
        .presentationDragIndicator(.visible)
        .presentationBackground(sheetBackground)
        .presentationCornerRadius(presentationCornerRadiusPoints)
    }
}

// MARK: - Debug host

/// Preview the unified sheet with mock actions; toggle app appearance to verify light/dark.
struct DebugModalSheetPrototypeView: View {
    @State private var showSheet = false

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(uiColor: UIColor.separator))
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }

    var body: some View {
        List {
            Section {
                Button("Present mock options sheet") {
                    showSheet = true
                }
                .foregroundColor(Theme.Colors.primaryText)
            } footer: {
                Text("Uses Theme.Colors.modalSheetBackground and system separator/label colors. Change Appearance in Settings to verify both modes.")
                    .font(Theme.Typography.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Modal sheet prototype")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSheet) {
            PreluraUnifiedModalSheet(title: "Options", onDismiss: { showSheet = false }, detents: [.height(300)]) {
                VStack(alignment: .leading, spacing: 0) {
                    mockRow(title: "Share", icon: "square.and.arrow.up")
                    rowDivider
                    mockRow(title: "Report listing", icon: "flag")
                    rowDivider
                    mockRow(title: "Copy link", icon: "link")
                }
                .padding(.vertical, Theme.Spacing.md)
            }
        }
    }

    private func mockRow(title: String, icon: String) -> some View {
        Button {
            showSheet = false
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DebugModalSheetPrototypeView()
    }
}
