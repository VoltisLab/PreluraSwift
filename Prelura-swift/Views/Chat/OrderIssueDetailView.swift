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
    @State private var supportConversationId: String?
    @State private var navigateToHelpChat = false
    @State private var isOpeningSupport = false
    @State private var supportOpenError: String?
    @State private var sellerSupportSingleUserMessageMode = false
    /// True between tapping Help and support and `load()` finishing (hides entry immediately).
    @State private var sellerSupportEntryUsedOptimistic = false
    @State private var showWithdrawConfirm = false
    @State private var isWithdrawing = false
    @State private var withdrawFeedback: String?

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
        .confirmationDialog(
            "Withdraw this report?",
            isPresented: $showWithdrawConfirm,
            titleVisibility: .visible
        ) {
            Button("Accept order and withdraw report", role: .destructive) {
                Task { await withdrawReport() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "You will not be able to open another report for this order. If delivery was already confirmed, the sale will be marked complete."
            )
        }
        .onChange(of: navigateToHelpChat) { _, isActive in
            if !isActive {
                Task { await load() }
            }
        }
        .alert("Refund without return?", isPresented: $confirmRefundWithoutReturn) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                Task { await submitResolution(resolution: Self.refundWithoutReturn, returnPostagePaidBy: nil) }
            }
        } message: {
            Text("The buyer will be refunded and keeps the item.")
        }
        .background(
            NavigationLink(
                destination: HelpChatView(
                    orderId: issue?.order?.id,
                    conversationId: supportConversationId,
                    issueDraft: nil,
                    isAdminSupportThread: false,
                    customerUsername: nil,
                    sellerOrderIssueSupportSingleUserMessage: sellerSupportSingleUserMessageMode
                ),
                isActive: $navigateToHelpChat
            ) { EmptyView() }
                .hidden()
        )
    }

    @ViewBuilder
    private func issueBody(_ issue: OrderIssueDetails) -> some View {
        if let formatted = Self.formatReportDate(issue.createdAt) {
            sectionLabel("Report date and time")
            card {
                Text(formatted)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }

        sectionLabel("Status")
        card {
            Text(humanReadableStatus(issue))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
        }

        sectionLabel("Issue type")
        card {
            Text(humanReadableIssueType(issue.issueType))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.primaryColor)
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

        if let withdrawFeedback, !withdrawFeedback.isEmpty {
            Text(withdrawFeedback)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }

        if isCurrentUserReporter(issue), isIssuePending(issue) {
            Button {
                showWithdrawConfirm = true
            } label: {
                HStack {
                    if isWithdrawing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Cancel report and accept order")
                        .font(Theme.Typography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(isWithdrawing ? Theme.Colors.tertiaryBackground : Theme.primaryColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: Self.issueContentCornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isWithdrawing || isSubmittingResolution)
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

        if sellerSupportEntryAvailable(issue) {
            Button {
                Task { await openSellerSupportChat(issueId: issue.id) }
            } label: {
                HStack {
                    if isOpeningSupport {
                        ProgressView()
                            .padding(.trailing, 6)
                    }
                    Text("Help and support")
                }
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .disabled(isOpeningSupport || isSubmittingResolution)
            .padding(.top, Theme.Spacing.md)
        } else {
            Text("You've already contacted support for this issue. Continue the conversation in Messages.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.md)
        }

        if let supportOpenError, !supportOpenError.isEmpty {
            Text(supportOpenError)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.error)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    private func sellerSupportEntryAvailable(_ issue: OrderIssueDetails) -> Bool {
        if sellerSupportEntryUsedOptimistic { return false }
        return issue.sellerSupportConversationId == nil
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
            .background(Theme.Colors.background)
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

    private func isCurrentUserReporter(_ issue: OrderIssueDetails) -> Bool {
        let me = (authService.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let reporter = (issue.raisedBy?.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !me.isEmpty, !reporter.isEmpty else { return false }
        return me == reporter
    }

    private func humanReadableStatus(_ issue: OrderIssueDetails) -> String {
        let s = (issue.status ?? "").uppercased()
        switch s {
        case "PENDING": return "Pending — under review"
        case "WITHDRAWN": return "Withdrawn — buyer accepted the order"
        case "DECLINED": return "Declined"
        case "RESOLVED": return "Resolved"
        default:
            return s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func formatReportDate(_ iso: String?) -> String? {
        guard let iso, !iso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        let date = f1.date(from: trimmed) ?? f2.date(from: trimmed)
        guard let date else { return trimmed }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: date)
    }

    private func withdrawReport() async {
        guard let id = issue?.id else { return }
        await MainActor.run {
            isWithdrawing = true
            withdrawFeedback = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            let result = try await userService.withdrawOrderCase(issueId: id)
            await MainActor.run {
                isWithdrawing = false
                if result.success {
                    withdrawFeedback = result.message
                } else {
                    withdrawFeedback = result.message ?? "Could not withdraw this report."
                }
            }
            if result.success {
                await load()
            }
        } catch {
            await MainActor.run {
                isWithdrawing = false
                withdrawFeedback = L10n.userFacingError(error)
            }
        }
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
                if result?.sellerSupportConversationId != nil {
                    sellerSupportEntryUsedOptimistic = true
                }
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

    private func openSellerSupportChat(issueId: Int) async {
        await MainActor.run {
            isOpeningSupport = true
            supportOpenError = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            let cid = try await userService.ensureSellerOrderIssueSupportThread(issueId: issueId)
            await MainActor.run {
                supportConversationId = String(cid)
                sellerSupportSingleUserMessageMode = true
                sellerSupportEntryUsedOptimistic = true
                isOpeningSupport = false
                navigateToHelpChat = true
            }
            await load()
        } catch {
            await MainActor.run {
                isOpeningSupport = false
                supportOpenError = L10n.userFacingError(error)
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
