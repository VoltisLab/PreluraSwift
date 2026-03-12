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
        List {
            Section {
                Text("If the item you received doesn't match the description, you can raise an issue within 3 days of delivery.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                    .listRowBackground(Theme.Colors.background)
            }

            Section(header: Text("What's the issue?").font(Theme.Typography.headline).foregroundColor(Theme.Colors.primaryText)) {
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
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                SellLabeledField(
                    label: "Additional details (optional)",
                    placeholder: "Describe the issue...",
                    text: $description,
                    minLines: 6,
                    maxLines: nil
                )
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                .listRowBackground(Theme.Colors.background)
            }

            Section {
                NavigationLink(destination: HelpChatView()) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Start a conversation with support")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .listRowBackground(Theme.primaryColor)
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
            }
        }
        .listStyle(.insetGrouped)
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
