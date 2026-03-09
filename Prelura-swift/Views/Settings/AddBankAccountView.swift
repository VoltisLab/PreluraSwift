import SwiftUI

struct AddBankAccountView: View {
    @State private var sortCode: String = ""
    @State private var accountNumber: String = ""
    @State private var accountHolderName: String = ""
    @State private var accountLabel: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case sortCode, accountNumber, accountHolderName, accountLabel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Enter your UK bank details. Your information is stored securely and used only for payouts.")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.bottom, Theme.Spacing.xs)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Sort code")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(
                        placeholder: "00-00-00",
                        text: $sortCode,
                        keyboardType: .numberPad
                    )
                    .focused($focusedField, equals: .sortCode)
                    .onChange(of: sortCode) { _, newValue in
                        sortCode = formatSortCode(newValue)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Account number")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(
                        placeholder: "12345678",
                        text: $accountNumber,
                        keyboardType: .numberPad
                    )
                    .focused($focusedField, equals: .accountNumber)
                    .onChange(of: accountNumber) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }.prefix(8)
                        accountNumber = String(filtered)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Account holder name")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(
                        placeholder: "As shown on your bank account",
                        text: $accountHolderName,
                        textContentType: .name
                    )
                    .focused($focusedField, equals: .accountHolderName)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Account label (optional)")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    SettingsTextField(
                        placeholder: "e.g. Main account",
                        text: $accountLabel
                    )
                    .focused($focusedField, equals: .accountLabel)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.red)
                }

                Button(action: addBankAccount) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Add bank account")
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(canSubmit ? Theme.primaryColor : Theme.primaryColor.opacity(0.5))
                    .cornerRadius(30)
                }
                .disabled(!canSubmit || isSaving)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Add Bank Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        let sortDigits = sortCode.filter { $0.isNumber }
        return sortDigits.count == 6
            && accountNumber.count == 8
            && !accountHolderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func formatSortCode(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }.prefix(6)
        let s = String(digits)
        if s.count <= 2 { return s }
        if s.count <= 4 { return s.prefix(2) + "-" + s.dropFirst(2) }
        return s.prefix(2) + "-" + s.dropFirst(2).prefix(2) + "-" + s.dropFirst(4)
    }

    private func addBankAccount() {
        errorMessage = nil
        guard canSubmit else { return }
        isSaving = true
        // Placeholder: wire to bank account API when available (backend unchanged)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        AddBankAccountView()
    }
}
