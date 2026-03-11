import SwiftUI

/// "Item not as described" help flow (Flutter ItemNotAsDescribedHelpScreen). Option to describe issue and start conversation.
struct ItemNotAsDescribedHelpView: View {
    var orderId: String?
    var conversationId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var description: String = ""
    @State private var selectedIssueType: String? = nil

    private let issueTypes: [(id: String, label: String)] = [
        ("NOT_AS_DESCRIBED", "Item not as described"),
        ("TOO_SMALL", "Item is too small"),
        ("COUNTERFEIT", "Item is counterfeit"),
        ("DAMAGED", "Item is damaged or broken"),
        ("WRONG_COLOR", "Item is wrong colour"),
        ("WRONG_SIZE", "Item is wrong size"),
        ("DEFECTIVE", "Item doesn't work / defective"),
        ("OTHER", "Other")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("If the item you received doesn't match the description, you can raise an issue within 3 days of delivery.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)

                Text("What's the issue?")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                ForEach(issueTypes, id: \.id) { type in
                    Button {
                        selectedIssueType = type.id
                    } label: {
                        HStack {
                            Text(type.label)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if selectedIssueType == type.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(Theme.Glass.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }

                Text("Additional details (optional)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                TextField("Describe the issue...", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .font(Theme.Typography.body)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(30)

                NavigationLink(destination: HelpChatView()) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Start a conversation with support")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Item Not as Described")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        ItemNotAsDescribedHelpView(orderId: nil, conversationId: nil)
    }
}
