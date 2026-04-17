import SwiftUI

/// Multiline description control shared with **Sell → Describe your item**: `ZStack` + top-leading placeholder + `TextEditor` / hashtag editor, theme surface and corner radius.
struct PreluraMultilineDescriptionField: View {
    var placeholder: String = ""
    @Binding var text: String
    var minLines: Int = 6
    /// When true, uses `HashtagHighlightingTextEditor` (UIKit) with the same insets as Sell listings.
    var highlightHashtags: Bool = false

    private var minHeight: CGFloat {
        minLines > 1 ? CGFloat(minLines) * 24 : 44
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.TextInput.insetHorizontal)
                    .padding(.vertical, Theme.TextInput.insetVertical)
            }
            if highlightHashtags {
                HashtagHighlightingTextEditor(text: $text)
                    .frame(minHeight: minHeight)
            } else {
                TextEditor(text: $text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, Theme.TextInput.insetHorizontal)
                    .padding(.vertical, Theme.TextInput.insetVertical)
                    .frame(minHeight: minHeight, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
    }
}
