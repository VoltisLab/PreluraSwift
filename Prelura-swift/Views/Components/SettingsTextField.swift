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
    /// When true, adds a grey border and no shadow (e.g. Filter modal price fields).
    var bordered: Bool = false

    @State private var passwordVisible: Bool = false
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
                HStack(spacing: Theme.Spacing.sm) {
                    Group {
                        if passwordVisible {
                            TextField(placeholder, text: $text)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .textContentType(textContentType ?? .password)
                        } else {
                            SecureField(placeholder, text: $text)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .textContentType(textContentType ?? .password)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    Button(action: { passwordVisible.toggle() }) {
                        Image(systemName: passwordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
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
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(bordered ? Theme.Colors.glassBorder : .clear, lineWidth: bordered ? 1 : 0)
        )
    }
}

/// Multiline (bio) field with same styling as SettingsTextField.
struct SettingsTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    /// When set, input is capped at this length and the field never accepts more.
    var maxLength: Int? = nil

    private let cornerRadius: CGFloat = 30

    private var effectiveBinding: Binding<String> {
        guard let max = maxLength else { return $text }
        return Binding(
            get: { text },
            set: { newValue in
                if newValue.count <= max {
                    text = newValue
                } else {
                    text = String(newValue.prefix(max))
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md + 4)
                    .padding(.vertical, Theme.Spacing.md + 8)
            }
            TextEditor(text: effectiveBinding)
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
