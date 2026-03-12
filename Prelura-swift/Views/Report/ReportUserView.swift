import SwiftUI

/// Report user/account options (Flutter ReportAccountOptionsRoute).
struct ReportUserView: View {
    let username: String
    var isProduct: Bool = false
    var productId: Int?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var selectedOption: String?
    @State private var submitted = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private let userService = UserService()
    private let productService = ProductService()

    private let userOptions = [
        "This user has engaged in inappropriate or offensive behaviour towards others",
        "This user has engaged in harassing or abusive behavior towards others on the platform.",
        "The user has violated our community guidelines and terms of service.",
        "The user has posted inappropriate or explicit content.",
        "This user has been involved in fraudulent or deceptive activities.",
        "The user has been consistently unprofessional in their conduct.",
        "The user has been impersonating someone else on the platform.",
        "Other",
    ]
    private let productOptions = [
        "The product has violated our community guidelines and terms of service.",
        "The product has posted inappropriate or explicit content.",
        "This product has been involved in fraudulent or deceptive activities.",
        "The product has been consistently unprofessional in their description.",
        "Other",
    ]

    private var options: [String] { isProduct ? productOptions : userOptions }

    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    selectedOption = option
                } label: {
                    HStack {
                        Text(option)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if selectedOption == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.primaryColor)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            if submitted {
                Text("Report submitted. Thank you.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.primaryColor)
            }
            if let err = errorMessage {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    submitReport()
                }
                .foregroundColor(Theme.primaryColor)
                .disabled(selectedOption == nil || isSubmitting)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func submitReport() {
        guard let reason = selectedOption, !reason.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                if isProduct, let pid = productId {
                    try await productService.reportProduct(productId: String(pid), reason: reason, content: nil)
                } else {
                    try await userService.reportAccount(username: username, reason: reason, content: nil)
                }
                await MainActor.run {
                    submitted = true
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportUserView(username: "testuser")
            .environmentObject(AuthService())
    }
}
