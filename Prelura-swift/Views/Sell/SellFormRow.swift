import SwiftUI

/// Single form row for the Sell screen (matches Flutter MenuCard).
/// Title and optional value with chevron; use inside NavigationLink and add divider overlay in parent.
struct SellFormRow: View {
    let title: String
    let value: String?

    init(title: String, value: String? = nil) {
        self.title = title
        self.value = value
    }

    private var hasValue: Bool {
        guard let v = value, !v.isEmpty else { return false }
        return true
    }

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(hasValue ? Theme.Colors.primaryText : Theme.Colors.secondaryText)

            Spacer()

            if let v = value, !v.isEmpty {
                Text(v)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
    }
}
