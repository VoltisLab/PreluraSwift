import SwiftUI

/// Single-line text field styled like DiscoverSearchField (rounded, secondary background).
/// Use for Account Settings and other forms where search-field styling is desired.
struct SettingsTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var isEnabled: Bool = true
    var onTap: (() -> Void)? = nil

    private let cornerRadius: CGFloat = 30

    var body: some View {
        Group {
            if let onTap = onTap, !isEnabled {
                Button(action: onTap) {
                    HStack {
                        Text(text.isEmpty ? placeholder : text)
                            .font(Theme.Typography.body)
                            .foregroundColor(text.isEmpty ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
            } else if isSecure {
                SecureField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .textContentType(textContentType ?? .password)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
            } else {
                TextField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(cornerRadius)
    }
}

/// Multiline (bio) field with same styling as SettingsTextField.
struct SettingsTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    private let cornerRadius: CGFloat = 30

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md + 4)
                    .padding(.vertical, Theme.Spacing.md + 8)
            }
            TextEditor(text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(minHeight: minHeight)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(cornerRadius)
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsTextField(placeholder: "Full name", text: .constant(""))
        SettingsTextField(placeholder: "Email", text: .constant(""), keyboardType: .emailAddress, textContentType: .emailAddress)
        SettingsTextEditor(placeholder: "Bio", text: .constant(""))
    }
    .padding()
}
