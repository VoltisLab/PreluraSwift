import SwiftUI

/// Report user/account options (Flutter ReportAccountOptionsRoute).
struct ReportUserView: View {
    let username: String
    var isProduct: Bool = false
    var productId: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: String?
    @State private var submitted = false

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
                .disabled(selectedOption == nil)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func submitReport() {
        guard selectedOption != nil else { return }
        // TODO: Call report API
        submitted = true
    }
}

#Preview {
    NavigationStack {
        ReportUserView(username: "testuser")
    }
}
