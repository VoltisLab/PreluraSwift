import SwiftUI

/// Which slice of the seller’s `userProducts` the grid shows (client-side; API must return `HIDDEN` / `SOLD` in that query).
enum ProfileListingScope: String, CaseIterable, Hashable {
    /// For-sale listings (not sold, not hidden from shop).
    case active
    /// Includes sold listings; still excludes hidden-from-shop rows.
    case all
    case sold
    case hidden
    var titleKey: String {
        switch self {
        case .active: return "Active"
        case .all: return "All"
        case .sold: return "Sold"
        case .hidden: return "Hidden"
        }
    }
    var shortTitle: String { L10n.string(titleKey) }
}

/// Own profile: choose Active (live shop) vs All (incl. sold), Sold, or Hidden-from-shop listings.
struct ProfileListingScopeSheetContent: View {
    @Binding var selected: ProfileListingScope
    var onApply: () -> Void

    private var optionDivider: some View {
        Rectangle()
            .fill(Theme.Colors.glassBorder)
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ProfileListingScope.allCases.enumerated()), id: \.offset) { index, option in
                Button(action: { selected = option }) {
                    HStack {
                        Text(L10n.string(option.titleKey))
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Spacer()
                        if selected == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
                if index < ProfileListingScope.allCases.count - 1 { optionDivider }
            }
            optionDivider
            VStack(spacing: Theme.Spacing.sm) {
                BorderGlassButton(L10n.string("Clear")) {
                    selected = .active
                }
                PrimaryGlassButton(L10n.string("Apply"), action: onApply)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
