import SwiftUI

/// Shared order issue detail page for both buyer and seller from chat "Issue with order" card.
struct OrderIssueDetailView: View {
    var issueId: Int? = nil
    var publicId: String? = nil

    private enum SelectedRefundPath: Equatable {
        case none
        case withoutReturn
        case withReturn
    }

    @EnvironmentObject var authService: AuthService
    @State private var issue: OrderIssueDetails?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showReturnPostageSection = false
    @State private var selectedReturnPostagePayer: String?
    @State private var isSubmittingResolution = false
    @State private var resolutionFeedback: String?
    @State private var confirmRefundWithoutReturn = false
    /// Which refund path the seller has focused (drives checkmark + border on the two banners).
    @State private var selectedRefundPath: SelectedRefundPath = .none

    private let userService = UserService()

    /// Slightly larger than `Theme.Glass.cornerRadius` so issue description + refund rows read as the same family of rounded cards.
    private static let issueContentCornerRadius: CGFloat = 16

    private static let refundWithoutReturn = "REFUND_WITHOUT_RETURN"
    private static let refundWithReturn = "REFUND_WITH_RETURN"
    private static let postageSeller = "SELLER"
    private static let postageBuyer = "BUYER"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Theme.Spacing.md)
                } else if let issue {
                    issueBody(issue)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.error)
                } else {
                    Text("Issue unavailable")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Issue with order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await load() }
        .alert("Refund without return?", isPresented: $confirmRefundWithoutReturn) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                Task { await submitResolution(resolution: Self.refundWithoutReturn, returnPostagePaidBy: nil) }
            }
        } message: {
            Text("The buyer will be refunded and keeps the item.")
        }
    }

    @ViewBuilder
    private func issueBody(_ issue: OrderIssueDetails) -> some View {
        sectionLabel("Issue type")
        card {
            Text(humanReadableIssueType(issue.issueType))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
        }

        sectionLabel("Description")
        card {
            Text(issue.description)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
        }

        if let other = issue.otherIssueDescription, !other.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sectionLabel("Additional details")
            card {
                Text(other)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }

        if !issue.imagesUrl.isEmpty {
            sectionLabel("Images")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(issue.imagesUrl, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(Theme.Colors.tertiaryBackground)
                                }
                            }
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }

        if !isIssuePending(issue) {
            sectionLabel("Outcome")
            card {
                Text(resolutionSummary(for: issue))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }

        if let resolutionFeedback, !resolutionFeedback.isEmpty {
            Text(resolutionFeedback)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }

        if isCurrentUserSeller(issue), isIssuePending(issue) {
            sellerResolutionSection(issue)
        }
    }

    @ViewBuilder
    private func sellerResolutionSection(_ issue: OrderIssueDetails) -> some View {
        Divider()
            .padding(.vertical, Theme.Spacing.sm)

        Text("Refund the customer")
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.primaryText)

        Text("Choose how you want to resolve this report. This is shown on the page so you can complete everything here.")
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)

        resolutionActionButton(
            title: "Refund without return",
            subtitle: "Buyer keeps the item and receives a refund.",
            isSelected: selectedRefundPath == .withoutReturn
        ) {
            selectedRefundPath = .withoutReturn
            showReturnPostageSection = false
            confirmRefundWithoutReturn = true
        }

        resolutionActionButton(
            title: "Refund with return",
            subtitle: "Buyer sends the item back before the refund is completed.",
            isSelected: selectedRefundPath == .withReturn
        ) {
            selectedRefundPath = .withReturn
            showReturnPostageSection = true
            selectedReturnPostagePayer = nil
        }

        if showReturnPostageSection {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Who pays return postage?")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.top, Theme.Spacing.sm)

                postageChoiceRow(
                    title: "Seller pays return postage",
                    value: Self.postageSeller,
                    selected: selectedReturnPostagePayer
                ) {
                    selectedReturnPostagePayer = Self.postageSeller
                }

                postageChoiceRow(
                    title: "Buyer pays return postage",
                    value: Self.postageBuyer,
                    selected: selectedReturnPostagePayer
                ) {
                    selectedReturnPostagePayer = Self.postageBuyer
                }

                Button {
                    Task {
                        await submitResolution(
                            resolution: Self.refundWithReturn,
                            returnPostagePaidBy: selectedReturnPostagePayer
                        )
                    }
                } label: {
                    HStack {
                        if isSubmittingResolution {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Confirm refund with return")
                            .font(Theme.Typography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        (selectedReturnPostagePayer != nil && !isSubmittingResolution)
                            ? Theme.primaryColor
                            : Theme.Colors.tertiaryBackground
                    )
                    .foregroundColor(
                        (selectedReturnPostagePayer != nil && !isSubmittingResolution)
                            ? .white
                            : Theme.Colors.secondaryText
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Self.issueContentCornerRadius))
                }
                .disabled(selectedReturnPostagePayer == nil || isSubmittingResolution)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }

    private func resolutionActionButton(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.primaryColor)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.primaryColor)
                        .accessibilityLabel("Selected")
                }
            }
            .padding(Theme.Spacing.md)
            .background(isSelected ? Theme.primaryColor.opacity(0.12) : Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Self.issueContentCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.issueContentCornerRadius)
                    .stroke(
                        isSelected ? Theme.primaryColor : Theme.Colors.glassBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmittingResolution)
    }

    private func postageChoiceRow(title: String, value: String, selected: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                if selected == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.primaryColor)
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                selected == value ? Theme.primaryColor.opacity(0.12) : Theme.Colors.secondaryBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.issueContentCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Self.issueContentCornerRadius)
                    .stroke(
                        selected == value ? Theme.primaryColor : Theme.Colors.glassBorder,
                        lineWidth: selected == value ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Self.issueContentCornerRadius))
    }

    private func isIssuePending(_ issue: OrderIssueDetails) -> Bool {
        (issue.status ?? "").uppercased() == "PENDING"
    }

    private func isCurrentUserSeller(_ issue: OrderIssueDetails) -> Bool {
        guard let me = authService.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !me.isEmpty,
              let sellerName = issue.order?.seller?.username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !sellerName.isEmpty else {
            return false
        }
        return me == sellerName
    }

    private func resolutionSummary(for issue: OrderIssueDetails) -> String {
        let res = issue.resolution ?? ""
        if res == Self.refundWithoutReturn {
            return "Refund without return"
        }
        if res == Self.refundWithReturn {
            if issue.returnPostagePaidBy == Self.postageSeller {
                return "Refund with return — seller pays return postage"
            }
            if issue.returnPostagePaidBy == Self.postageBuyer {
                return "Refund with return — buyer pays return postage"
            }
            return "Refund with return"
        }
        let st = (issue.status ?? "").replacingOccurrences(of: "_", with: " ").capitalized
        return st.isEmpty ? "Updated" : st
    }

    private func submitResolution(resolution: String, returnPostagePaidBy: String?) async {
        guard let id = issue?.id else { return }
        await MainActor.run {
            isSubmittingResolution = true
            resolutionFeedback = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            let result = try await userService.resolveOrderIssue(
                issueId: id,
                resolution: resolution,
                returnPostagePaidBy: returnPostagePaidBy
            )
            await MainActor.run {
                isSubmittingResolution = false
                if result.success {
                    resolutionFeedback = result.message
                    showReturnPostageSection = false
                    selectedReturnPostagePayer = nil
                } else {
                    resolutionFeedback = result.message ?? "Could not update issue."
                }
            }
            if result.success {
                await load()
            }
        } catch {
            await MainActor.run {
                isSubmittingResolution = false
                resolutionFeedback = L10n.userFacingError(error)
            }
        }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            let result = try await userService.getOrderIssue(issueId: issueId, publicId: publicId)
            await MainActor.run {
                issue = result
                isLoading = false
                if issue == nil { errorMessage = "Issue not found" }
                if let i = issue, !isIssuePending(i) {
                    showReturnPostageSection = false
                    selectedReturnPostagePayer = nil
                    selectedRefundPath = .none
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = L10n.userFacingError(error)
            }
        }
    }

    private func humanReadableIssueType(_ raw: String) -> String {
        switch raw {
        case "NOT_AS_DESCRIBED": return "Item not as described"
        case "TOO_SMALL": return "Item is too small"
        case "COUNTERFEIT": return "Item is counterfeit"
        case "DAMAGED": return "Item is damaged or broken"
        case "WRONG_COLOR": return "Item is wrong colour"
        case "WRONG_SIZE": return "Item is wrong size"
        case "DEFECTIVE": return "Item doesn't work / defective"
        case "OTHER": return "Other"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
