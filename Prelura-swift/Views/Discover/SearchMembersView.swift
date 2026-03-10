import SwiftUI

/// Search results for "Search members" on Discover. Shows members matching the query.
/// Backend member search can be wired here when available.
struct SearchMembersView: View {
    @Environment(\.dismiss) private var dismiss
    let query: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(L10n.string("Search members"))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("Enter a name or username to find members.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    // Placeholder for member results when API is available
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.secondaryText)
                        Text(String(format: "Results for \"%@\"", query))
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Member search results will appear here.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Search members"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
    }
}
