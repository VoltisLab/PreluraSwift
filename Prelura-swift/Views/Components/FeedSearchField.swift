import SwiftUI

/// Feed search field with optional AI icon that opens the dedicated AI chat.
/// Submit parses query with AISearchService and calls onSubmit(ParsedSearch).
struct FeedSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var aiButtonScale: CGFloat = 1.0

    var placeholder: String = "Search items, brands or colours"
    var onSubmit: ((ParsedSearch) -> Void)?
    var onAITap: (() -> Void)?
    var topPadding: CGFloat? = nil

    private let cornerRadius: CGFloat = 30
    private let aiSearch = AISearchService()

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
                    let parsed = aiSearch.parse(query: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    onSubmit?(parsed)
                }

            if let onAITap = onAITap {
                Button(action: onAITap) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.primaryColor)
                        .scaleEffect(aiButtonScale)
                }
                .buttonStyle(HapticTapButtonStyle())
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                aiButtonScale = 1.2
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isFocused ? Theme.primaryColor : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, topPadding ?? Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }
}
