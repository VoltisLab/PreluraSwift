import SwiftUI

/// Reusable discover-style search field with 30pt corner radius.
/// Use this component for all search bars to ensure consistent styling and position.
struct DiscoverSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    var placeholder: String = "Search members"
    var onSubmit: (() -> Void)? = nil
    var onChange: ((String) -> Void)? = nil
    var showClearButton: Bool = false
    var onClear: (() -> Void)? = nil
    /// When true (default), adds horizontal and vertical outer padding so the field keeps the same position as Discover. Set false when parent already provides horizontal padding (e.g. Browse).
    var outerPadding: Bool = true
    /// Top padding above the search field. Default nil uses Theme.Spacing.sm. Set to Theme.Spacing.xs (or 0) for a tighter layout under the header (e.g. Home).
    var topPadding: CGFloat? = nil
    /// When set, uses this as the search field background instead of secondaryBackground (e.g. Theme.Colors.background to match the page).
    var fieldBackground: Color? = nil

    private let cornerRadius: CGFloat = 30

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Colors.secondaryText)

            TextField(placeholder, text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: text) { oldValue, newValue in
                    onChange?(newValue)
                }

            if showClearButton && !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(fieldBackground ?? Theme.Colors.secondaryBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isFocused ? Theme.primaryColor : Color.clear, lineWidth: 2)
        )
        .modifier(DiscoverSearchFieldOuterPadding(outerPadding: outerPadding, topPadding: topPadding))
    }
}

private struct DiscoverSearchFieldOuterPadding: ViewModifier {
    let outerPadding: Bool
    let topPadding: CGFloat?
    func body(content: Content) -> some View {
        let top = topPadding ?? Theme.Spacing.sm
        if outerPadding {
            content
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, top)
                .padding(.bottom, Theme.Spacing.xs)
        } else {
            content
                .padding(.top, top)
                .padding(.bottom, Theme.Spacing.xs)
        }
    }
}

#Preview {
    VStack {
        DiscoverSearchField(text: .constant(""))
        DiscoverSearchField(text: .constant("test"), showClearButton: true)
    }
    .padding()
}
