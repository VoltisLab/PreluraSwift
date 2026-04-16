import SwiftUI
import UIKit

private enum OrderFeedbackSheetRole {
    case buyerRatesSeller
    case sellerRatesBuyer
}

/// Order details: status, seller/buyer, items, summary. Matches reference design with section labels and rounded cards.
struct OrderDetailView: View {
    let order: Order
    /// When viewing from My Orders: true = sold (so other party is Buyer), false = bought (so other party is Seller). When nil (e.g. from chat), section shows "Other party".
    var isSeller: Bool? = nil
    /// Hides buyer “I have a problem” / multibuy picker and all cancel-order entry points (e.g. when opened from Order Help → Order status to avoid loops).
    var suppressBuyerHelpAndCancelActions: Bool = false

    @EnvironmentObject var authService: AuthService
    private let userService = UserService()
    private let productService = ProductService()

    @State private var shippingLabelLoading = false
    @State private var shippingLabelError: String?
    @State private var showConfirmShippingSheet = false
    @State private var confirmShippingCarrier = ""
    @State private var confirmShippingTracking = ""
    @State private var confirmShippingTrackingURL = ""
    @State private var confirmShippingSubmitting = false
    @State private var confirmShippingError: String?
    @State private var productDetailItem: Item?
    @State private var loadingProductDetail = false
    @State private var currentUser: User?
    @State private var hydratedOrder: Order?
    @State private var showTrackingWeb = false
    @State private var trackingWebURL: URL?
    @State private var isTrackingWebLoading = false
    @State private var showTrackingCopiedToast = false
    @State private var cancellationBusy = false
    @State private var cancellationActionError: String?
    @State private var showMultibuyProblemProductPicker = false
    @State private var orderHelpProductContext: OrderProductSummary?
    @State private var showLeaveFeedbackSheet = false
    @State private var feedbackSheetRole: OrderFeedbackSheetRole = .buyerRatesSeller
    @State private var leaveFeedbackRefreshToken = UUID()
    @State private var showReviewSubmittedFeedback = false
    @State private var showConfirmMarkDelivered = false
    @State private var markDeliveredBusy = false
    @State private var markDeliveredError: String?
    /// When `userOrders` / chat omits numeric ids on `otherParty`, resolve via `getUser(username)`.
    @State private var resolvedCounterpartyNumericUserId: Int?
    /// When false, buyer review hints stay hidden so we don’t flash “missing id” before hydrate / lookup finishes.
    @State private var didFinishOrderDetailBootstrap = false

    init(order: Order, isSeller: Bool? = nil, suppressBuyerHelpAndCancelActions: Bool = false) {
        self.order = order
        self.isSeller = isSeller
        self.suppressBuyerHelpAndCancelActions = suppressBuyerHelpAndCancelActions
        // Do not seed `hydratedOrder` from a snapshot cache: a stale copy kept the UI on an old
        // status (e.g. CONFIRMED) so “Leave a review” never appeared after the order reached DELIVERED.
        _hydratedOrder = State(initialValue: nil)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private var orderDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy 'at' HH:mm"
        return f
    }

    private var deliveryDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }

    /// Section label for the other party: "Seller", "Buyer", or "Other party".
    private var otherPartySectionTitle: String {
        guard let isSeller = isSeller else { return L10n.string("Other party") }
        return isSeller ? L10n.string("Buyer") : L10n.string("Seller")
    }

    private var effectiveOrder: Order { hydratedOrder ?? order }

    /// My Orders passes an explicit role; chat / deep links may use `nil` — infer from numeric ids once `currentUser` is loaded.
    private var viewerIsOrderBuyer: Bool {
        if let s = isSeller { return !s }
        guard let me = currentUser?.userId, me != 0 else { return false }
        if let bid = effectiveOrder.buyerUserId, bid == me { return true }
        // Chat / partial payloads: seller id known, buyer id missing — if we're not the seller, we're the buyer.
        let sellerId = effectiveOrder.sellerUserId ?? effectiveOrder.otherParty?.userId
        if let sid = sellerId, sid != 0, me != sid {
            if let bid = effectiveOrder.buyerUserId, bid != 0, bid != me { return false }
            return true
        }
        return false
    }

    private var viewerIsOrderSeller: Bool {
        if let s = isSeller { return s }
        guard let me = currentUser?.userId, me != 0 else { return false }
        if let sid = effectiveOrder.sellerUserId, sid == me { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headerSection
                processingCard
                productCard
                sellerPayoutNoticeIfNeeded
                if effectiveOrder.otherParty != nil {
                    sectionLabel(otherPartySectionTitle)
                    outlinedPartyCard
                }
                sectionLabel(L10n.string("Shipping Address"))
                shippingAddressAndDeliverySection
                sectionLabel("Tracking details")
                shippingSelectedCard

                buyerMarkDeliveredSectionIfNeeded

                sellerLeaveReviewSectionIfNeeded

                buyerLeaveReviewSection

                if canShowBuyerOrderHelp, !suppressBuyerHelpAndCancelActions {
                            if effectiveOrder.hasOpenOrderIssue {
                                buyerReportedProblemSummary
                            } else if shouldPickProductBeforeOrderHelp {
                                Button {
                                    showMultibuyProblemProductPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "exclamationmark.bubble")
                                        Text(L10n.string("I have a problem"))
                                    }
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.primaryColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                                }
                                .buttonStyle(PlainTappableButtonStyle())
                            } else {
                                NavigationLink(destination: OrderHelpView(orderId: effectiveOrder.id, conversationId: "")) {
                                    HStack {
                                        Image(systemName: "exclamationmark.bubble")
                                        Text(L10n.string("I have a problem"))
                                    }
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.primaryColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                                }
                                .buttonStyle(PlainTappableButtonStyle())
                            }
                        }

                        if hasPendingCancellation, isPendingCancellationInitiator {
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: "clock")
                                    .foregroundColor(Theme.Colors.secondaryText)
                                Text(L10n.string("You requested to cancel this order. The other party must approve before it is cancelled."))
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                        }

                        if canShowRespondToCancellation {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text(L10n.string("The other party asked to cancel this order."))
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                HStack(spacing: Theme.Spacing.md) {
                                    Button {
                                        Task { await respondToCancellationRequest(approve: false) }
                                    } label: {
                                        Text(L10n.string("Decline"))
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.primaryText)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(Theme.Colors.tertiaryBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                                    }
                                    .buttonStyle(PlainTappableButtonStyle())
                                    .disabled(cancellationBusy)

                                    Button {
                                        Task { await respondToCancellationRequest(approve: true) }
                                    } label: {
                                        Text(L10n.string("Approve"))
                                            .font(Theme.Typography.body)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(Theme.primaryColor)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                                    }
                                    .buttonStyle(PlainTappableButtonStyle())
                                    .disabled(cancellationBusy)
                                }
                                if cancellationBusy {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                }
                                if let err = cancellationActionError, !err.isEmpty {
                                    Text(err)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.error)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                        }

                        if canShowCancelOrder, !suppressBuyerHelpAndCancelActions {
                            NavigationLink(destination: CancelOrderView(order: effectiveOrder)) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text(L10n.string("Cancel order"))
                                }
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }

                        if canShowSellerCancelOrder, !suppressBuyerHelpAndCancelActions {
                            NavigationLink(destination: CancelOrderView(order: effectiveOrder, isSellerRequest: true)) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text(L10n.string("Cancel order"))
                                }
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }

                bothPartiesReviewedSummaryIfNeeded
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, canShowSellerShipping ? Theme.Spacing.md : Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Order details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            if showReviewSubmittedFeedback {
                Text(L10n.string("Thanks! Your review was submitted."))
                    .font(Theme.Typography.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, canShowSellerShipping ? 88 : 32)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: showReviewSubmittedFeedback)
        .onChange(of: showReviewSubmittedFeedback) { _, on in
            guard on else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showReviewSubmittedFeedback = false
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if canShowSellerShipping {
                shippingActionSheet
            }
        }
        .task(id: order.id) {
            userService.updateAuthToken(authService.authToken)
            await MainActor.run {
                resolvedCounterpartyNumericUserId = nil
                didFinishOrderDetailBootstrap = false
            }

            currentUser = try? await userService.getUser(username: nil)

            await hydrateOrderIfNeeded(force: true)
            await refreshTrackingDetailsIfNeeded()
            await resolveCounterpartyNumericUserIdIfNeeded()
            await MainActor.run { didFinishOrderDetailBootstrap = true }
        }
        .sheet(isPresented: $showTrackingWeb) {
            if let trackingWebURL {
                NavigationStack {
                    WebView(url: trackingWebURL, isLoading: $isTrackingWebLoading)
                        .navigationTitle("Tracking")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showMultibuyProblemProductPicker) {
            MultibuyOrderProblemProductPickerSheet(
                products: effectiveOrder.products,
                onContinue: { product in
                    showMultibuyProblemProductPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        orderHelpProductContext = product
                    }
                },
                onCancel: {
                    showMultibuyProblemProductPicker = false
                }
            )
        }
        .navigationDestination(item: $orderHelpProductContext) { product in
            OrderHelpView(orderId: effectiveOrder.id, conversationId: "", helpContextProduct: product)
        }
        .sheet(isPresented: $showLeaveFeedbackSheet) {
            if let oid = numericOrderIdIfAvailable,
               let rateeId = rateeUserIdForFeedbackSheet {
                LeaveOrderFeedbackSheet(
                    orderId: oid,
                    rateeUserId: rateeId,
                    role: feedbackSheetRole,
                    buyerSubmitReleasesPayment: feedbackSheetRole == .buyerRatesSeller && orderStatusUppercased == "DELIVERED",
                    onFinished: {
                        showLeaveFeedbackSheet = false
                        leaveFeedbackRefreshToken = UUID()
                        withAnimation(.easeOut(duration: 0.25)) {
                            showReviewSubmittedFeedback = true
                        }
                        Task { await hydrateOrderIfNeeded(force: true) }
                    }
                )
                .environmentObject(authService)
                .id(leaveFeedbackRefreshToken)
            } else {
                Text("Unable to open feedback for this order.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding()
            }
        }
    }

    /// Buyer confirms the parcel arrived so the order can move to **DELIVERED** (enables review). Parity with Flutter chat `updateOrderStatus`.
    /// Includes **CONFIRMED**: backend only allows `CONFIRMED → SHIPPED → DELIVERED`, not `CONFIRMED → DELIVERED` (fixes “Invalid status transition”).
    private var shouldShowBuyerMarkDeliveredButton: Bool {
        guard viewerIsOrderBuyer else { return false }
        guard !suppressBuyerHelpAndCancelActions else { return false }
        guard !effectiveOrder.hasOpenOrderIssue else { return false }
        guard numericOrderIdIfAvailable != nil else { return false }
        let st = orderStatusUppercased
        return st == "CONFIRMED" || st == "SHIPPED" || st == "IN_TRANSIT" || st == "READY_FOR_PICKUP"
    }

    @ViewBuilder
    private var buyerMarkDeliveredSectionIfNeeded: some View {
        if shouldShowBuyerMarkDeliveredButton {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Button {
                    showConfirmMarkDelivered = true
                } label: {
                    HStack {
                        Image(systemName: "shippingbox.and.arrow.backward")
                        Text(L10n.string("I've received this item"))
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.primaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                }
                .buttonStyle(PlainTappableButtonStyle())
                .disabled(markDeliveredBusy)

                if markDeliveredBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let err = markDeliveredError, !err.isEmpty {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
            .confirmationDialog(
                L10n.string("Confirm receipt"),
                isPresented: $showConfirmMarkDelivered,
                titleVisibility: .visible
            ) {
                Button(L10n.string("Confirm")) {
                    Task { await markOrderDelivered() }
                }
                Button(L10n.string("Cancel"), role: .cancel) {}
            } message: {
                Text(
                    L10n.string(
                        "Please confirm you received the correct item. You can leave a review after this. This cannot be undone."
                    )
                )
            }
        }
    }

    /// Show the buyer review row whenever the order may receive a review later; gate tapping with `shouldShowLeaveReviewForBuyer`.
    /// Matches the Seller card: if you see a counterparty, you should see this row (even while ids or status still catch up).
    private var canShowBuyerLeaveReviewRow: Bool {
        guard viewerIsOrderBuyer else { return false }
        let st = orderStatusUppercased
        guard st != "CANCELLED" && st != "REFUNDED" else { return false }
        guard !effectiveOrder.buyerHasLeftReview else { return false }
        guard effectiveOrder.otherParty != nil else { return false }

        let sellerId = effectiveSellerNumericIdForBuyerReview
        let buyerId = effectiveOrder.buyerUserId ?? currentUser?.userId
        if let sellerId, let buyerId, buyerId != 0 {
            let leftManualBuyerReview = effectiveOrder.orderReviews.contains {
                $0.isAutoReview == false && $0.reviewerUserId == buyerId && $0.reviewedUserId == sellerId
            }
            if leftManualBuyerReview { return false }
        }
        return true
    }

    private var buyerLeaveReviewDisabledHint: String? {
        guard canShowBuyerLeaveReviewRow, !shouldShowLeaveReviewForBuyer else { return nil }
        guard didFinishOrderDetailBootstrap else { return nil }
        let sellerId = effectiveSellerNumericIdForBuyerReview
        if numericOrderIdIfAvailable == nil {
            return L10n.string("We couldn't read this order's ID. Open it from My orders or pull to refresh.")
        }
        if sellerId == nil {
            return L10n.string("The seller is shown above, but we still need their account ID from the server to submit a review. Pull to refresh or open from My orders.")
        }
        if effectiveOrder.hasOpenOrderIssue {
            return L10n.string("You can't leave a review while a problem report is open.")
        }
        return L10n.string("You can leave a review once your order has been delivered.")
    }

    @ViewBuilder
    private var buyerLeaveReviewSection: some View {
        if canShowBuyerLeaveReviewRow {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    guard shouldShowLeaveReviewForBuyer else { return }
                    feedbackSheetRole = .buyerRatesSeller
                    showLeaveFeedbackSheet = true
                } label: {
                    HStack {
                        Image(systemName: "star.bubble")
                        Text(L10n.string("Leave a review"))
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(shouldShowLeaveReviewForBuyer ? Theme.primaryColor : Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                }
                .buttonStyle(PlainTappableButtonStyle())
                .disabled(!shouldShowLeaveReviewForBuyer)

                if let hint = buyerLeaveReviewDisabledHint {
                    Text(hint)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var sellerLeaveReviewSectionIfNeeded: some View {
        if shouldShowLeaveReviewForSeller {
            Button {
                feedbackSheetRole = .sellerRatesBuyer
                showLeaveFeedbackSheet = true
            } label: {
                HStack {
                    Image(systemName: "star.bubble")
                    Text(L10n.string("Leave a review"))
                }
                .font(Theme.Typography.body)
                .foregroundColor(Theme.primaryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
            }
            .buttonStyle(PlainTappableButtonStyle())
        }
    }

    /// Replaces “I have a problem” when `hasOpenOrderIssue` (buyer already reported).
    @ViewBuilder
    private var buyerReportedProblemSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(Theme.primaryColor)
                Text(L10n.string("Problem reported"))
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
            }
            Text(L10n.string("You already reported a problem for this order. You cannot submit another report while it is open."))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let issue = effectiveOrder.openOrderIssue {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("\(L10n.string("Type")): \(humanizedOrderIssueType(issue.issueType))")
                    if !issue.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(issue.description)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(5)
                    }
                    Text("\(L10n.string("Status")): \(buyerReportedProblemStatusLabel(issue.status))")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                NavigationLink(destination: OrderIssueDetailView(issueId: issue.issueId, publicId: issue.publicId)) {
                    HStack {
                        Text(L10n.string("View report details"))
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.primaryColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                }
                .buttonStyle(PlainTappableButtonStyle())
            } else {
                Text(L10n.string("This order is on hold until the report is resolved."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
    }

    private func humanizedOrderIssueType(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "—" }
        return t.replacingOccurrences(of: "_", with: " ").lowercased().capitalized
    }

    private func buyerReportedProblemStatusLabel(_ status: String) -> String {
        switch status.uppercased() {
        case "PENDING": return L10n.string("On hold — under review")
        case "RESOLVED": return L10n.string("Resolved")
        case "DECLINED": return L10n.string("Declined")
        default: return status
        }
    }

    @ViewBuilder
    private var sellerPayoutNoticeIfNeeded: some View {
        if isSeller == true, orderStatusUppercased == "DELIVERED" {
            if effectiveOrder.hasOpenOrderIssue {
                Text("Payment is on hold while a buyer issue is open.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
            } else {
                Text("Payment is released after the buyer leaves feedback, or automatically 3 days after delivery if they do not.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
            }
        }
    }

    private var orderStatusUppercased: String {
        effectiveOrder.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var numericOrderIdIfAvailable: Int? {
        Int(effectiveOrder.id.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedOtherPartyUsernameForLookup() -> String? {
        let raw = effectiveOrder.otherParty?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("@") {
            let rest = String(raw.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            return rest.isEmpty ? nil : rest
        }
        return raw
    }

    /// Seller's backend user id for buyer→seller review (order fields, then profile lookup).
    private var effectiveSellerNumericIdForBuyerReview: Int? {
        let v = effectiveOrder.sellerUserId ?? effectiveOrder.otherParty?.userId ?? resolvedCounterpartyNumericUserId
        guard let v, v != 0 else { return nil }
        return v
    }

    /// Buyer's backend user id for seller→buyer review.
    private var effectiveBuyerNumericIdForSellerReview: Int? {
        let v = effectiveOrder.buyerUserId ?? effectiveOrder.otherParty?.userId ?? resolvedCounterpartyNumericUserId
        guard let v, v != 0 else { return nil }
        return v
    }

    /// Who receives the star rating in the feedback sheet (must match `userOrders` party ids when `otherParty.userId` is missing).
    private var rateeUserIdForFeedbackSheet: Int? {
        switch feedbackSheetRole {
        case .buyerRatesSeller:
            return effectiveSellerNumericIdForBuyerReview
        case .sellerRatesBuyer:
            return effectiveBuyerNumericIdForSellerReview
        }
    }

    /// Buyer rates seller: delivered (completes order) or completed if a review is still outstanding.
    /// Uses `userOrders` buyer/seller ids (not `viewMe`) so the button works even when `getUser` fails or omits numeric id.
    /// Hide only when a **manual** buyer→seller row exists in `orderReviews`.
    private var shouldShowLeaveReviewForBuyer: Bool {
        guard viewerIsOrderBuyer else { return false }
        let st = orderStatusUppercased
        guard st == "DELIVERED" || st == "COMPLETED" else { return false }
        guard !effectiveOrder.hasOpenOrderIssue else { return false }
        guard !effectiveOrder.buyerHasLeftReview else { return false }
        guard numericOrderIdIfAvailable != nil else { return false }
        guard let sellerId = effectiveSellerNumericIdForBuyerReview else { return false }
        let buyerId = effectiveOrder.buyerUserId ?? currentUser?.userId
        if let buyerId, buyerId != 0 {
            let leftManualBuyerReview = effectiveOrder.orderReviews.contains {
                // Only `false` means “buyer left a real review”. `true` = platform auto; `nil` = unknown — keep CTA visible.
                $0.isAutoReview == false && $0.reviewerUserId == buyerId && $0.reviewedUserId == sellerId
            }
            if leftManualBuyerReview { return false }
        }
        return true
    }

    /// Seller rates buyer after the order is completed (manual review only; ignores platform auto-reviews).
    private var shouldShowLeaveReviewForSeller: Bool {
        guard viewerIsOrderSeller else { return false }
        guard orderStatusUppercased == "COMPLETED" else { return false }
        guard !effectiveOrder.hasOpenOrderIssue else { return false }
        guard numericOrderIdIfAvailable != nil else { return false }
        guard let buyerId = effectiveBuyerNumericIdForSellerReview else { return false }
        let sellerId = effectiveOrder.sellerUserId ?? currentUser?.userId
        if let sellerId, sellerId != 0 {
            let already = effectiveOrder.orderReviews.contains {
                $0.isAutoReview == false && $0.reviewerUserId == sellerId && $0.reviewedUserId == buyerId
            }
            if already { return false }
        }
        return true
    }

    /// Manual buyer→seller and seller→buyer rows in `orderReviews` (same rules as review CTAs).
    private var bothPartiesSubmittedManualReviews: Bool {
        let buyerId = effectiveOrder.buyerUserId
            ?? (viewerIsOrderBuyer ? currentUser?.userId : nil)
            ?? (viewerIsOrderSeller ? effectiveOrder.otherParty?.userId : nil)
        let sellerId = effectiveOrder.sellerUserId
            ?? (viewerIsOrderSeller ? currentUser?.userId : nil)
            ?? (viewerIsOrderBuyer ? effectiveOrder.otherParty?.userId : nil)
        guard let bid = buyerId, bid != 0, let sid = sellerId, sid != 0 else { return false }
        let buyerRatedSeller = effectiveOrder.orderReviews.contains {
            $0.isAutoReview == false && $0.reviewerUserId == bid && $0.reviewedUserId == sid
        }
        let sellerRatedBuyer = effectiveOrder.orderReviews.contains {
            $0.isAutoReview == false && $0.reviewerUserId == sid && $0.reviewedUserId == bid
        }
        return buyerRatedSeller && sellerRatedBuyer
    }

    @ViewBuilder
    private var bothPartiesReviewedSummaryIfNeeded: some View {
        if bothPartiesSubmittedManualReviews {
            Text(L10n.string("You and the other party have both left reviews for this order."))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(Theme.Colors.secondaryText)
            .padding(.top, 1)
            .padding(.bottom, 1)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(effectiveOrder.products.count > 1 ? "Multibuy · \(effectiveOrder.displayOrderId)" : "Order - \(effectiveOrder.displayOrderId)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.Colors.primaryText)
            HStack(spacing: Theme.Spacing.sm) {
                Text("Order date: \(orderDateFormatter.string(from: effectiveOrder.createdAt))")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                if let delivery = resolvedDeliveryDate {
                    Text("|")
                        .foregroundColor(Theme.Colors.secondaryText)
                    Label("Delivery: \(deliveryDateFormatter.string(from: delivery))", systemImage: "truck.box")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
    }

    private var processingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image("ParcelIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Theme.Colors.secondaryText)
                Text(effectiveOrder.statusDisplay)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Text("\(progressPercent)%")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            ProgressView(value: Double(progressPercent), total: 100)
                .tint(.green)
        }
        .padding(Theme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }

    private var progressPercent: Int {
        switch effectiveOrder.status {
        case "CONFIRMED": return 20
        case "SHIPPED": return 65
        case "DELIVERED": return 95
        case "COMPLETED": return 100
        case "CANCELLED", "REFUNDED": return 0
        default: return 25
        }
    }

    private var productCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if effectiveOrder.products.count <= 1 {
                singleProductCardLink
            } else {
                multibuyProductRows
            }
            if let disc = effectiveOrder.discountPrice?.trimmingCharacters(in: .whitespacesAndNewlines),
               !disc.isEmpty,
               let d = Double(disc),
               d > 0.001 {
                HStack {
                    Text(L10n.string("Multi-buy discount"))
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.primaryColor)
                    Spacer()
                    Text(CurrencyFormatter.gbp(-d))
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.primaryColor)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }

    private var singleProductCardLink: some View {
        let p = effectiveOrder.products.first
        return NavigationLink {
            productDestinationView
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                productThumb(url: p?.imageUrl, isMysteryBox: p?.isMysteryBox == true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p?.name ?? "Product")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                    if let details = metadataLine(for: p), !details.isEmpty {
                        Text(details)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    Text("£\(p?.price ?? effectiveOrder.priceTotal)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.primaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.top, 6)
            }
            .padding(Theme.Spacing.md)
        }
        .buttonStyle(PlainTappableButtonStyle())
    }

    private var multibuyProductRows: some View {
        ForEach(Array(effectiveOrder.products.enumerated()), id: \.element.id) { index, p in
            VStack(spacing: 0) {
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Colors.glassBorder)
                        .frame(height: 0.5)
                        .padding(.leading, Theme.Spacing.md)
                }
                NavigationLink {
                    OrderLineProductDetailHost(productId: p.id)
                } label: {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        productThumb(url: p.imageUrl, isMysteryBox: p.isMysteryBox)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.Colors.primaryText)
                                .lineLimit(2)
                            if let details = metadataLine(for: p), !details.isEmpty {
                                Text(details)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 6)
                            Text("£\(p.price ?? "—")")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .padding(.top, 6)
                    }
                    .padding(Theme.Spacing.md)
                }
                .buttonStyle(PlainTappableButtonStyle())
            }
        }
    }

    private var outlinedPartyCard: some View {
        Group {
            if let other = effectiveOrder.otherParty {
                HStack(spacing: Theme.Spacing.md) {
                    avatarView(url: other.avatarURL, username: other.username)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(other.username)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        if isSeller == true, let count = effectiveOrder.buyerOrderCountWithSeller {
                            Label("\(count) \(count == 1 ? "order" : "orders")", systemImage: "bag")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        } else {
                            Text("@\(other.username)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var productDestinationView: some View {
        if let item = productDetailItem {
            ItemDetailView(item: item, authService: authService)
                .environmentObject(authService)
        } else if loadingProductDetail {
            ProgressView("Loading product...")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .onAppear(perform: loadProductForDetail)
        } else {
            ProgressView("Loading product...")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .onAppear(perform: loadProductForDetail)
        }
    }

    private var shippingAddressAndDeliverySection: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Group {
                if let addr = effectiveOrder.shippingAddress, !formatShippingAddress(addr).isEmpty {
                    outlinedShippingAddressCard(addr)
                } else {
                    Text("No address available")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(Theme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Delivery")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                Text(resolvedDeliveryDate.map { deliveryDateFormatter.string(from: $0) } ?? "TBD")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
    }

    private var shippingSelectedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(effectiveOrder.shipmentService?.isEmpty == false ? effectiveOrder.shipmentService! : "Not selected")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            if let tracking = effectiveOrder.trackingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
               !tracking.isEmpty,
               let url = URL(string: tracking) {
                Button {
                    trackingWebURL = url
                    showTrackingWeb = true
                } label: {
                    Text("Check tracking")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.primaryColor)
                }
                .buttonStyle(PlainTappableButtonStyle())
            } else if let trackingNumber = effectiveOrder.trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trackingNumber.isEmpty {
                Button {
                    if let tracking = effectiveOrder.trackingUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !tracking.isEmpty,
                       let url = URL(string: tracking) {
                        trackingWebURL = url
                        showTrackingWeb = true
                    } else {
                        UIPasteboard.general.string = trackingNumber
                        showTrackingCopiedToast = true
                    }
                } label: {
                    Text("Tracking: \(trackingNumber)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.primaryColor)
                }
                .buttonStyle(PlainTappableButtonStyle())
            } else {
                Text("No tracking information available")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if showTrackingCopiedToast {
                Text("Tracking copied")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_100_000_000)
                        showTrackingCopiedToast = false
                    }
            }
        }
    }

    private func outlinedShippingAddressCard(_ addr: ShippingAddress) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if !addr.address.isEmpty { Text(addr.address) }
            if !addr.city.isEmpty { Text(addr.city) }
            if !addr.postcode.isEmpty { Text(addr.postcode) }
            if !addr.country.isEmpty { Text(addr.country) }
        }
        .font(Theme.Typography.body)
        .foregroundColor(Theme.Colors.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }

    private var statusCard: some View {
        Text(order.statusDisplay)
            .font(Theme.Typography.body)
            .fontWeight(.medium)
            .foregroundColor(Theme.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
    }

    private var otherPartyCard: some View {
        Group {
            if let other = order.otherParty {
                HStack(spacing: Theme.Spacing.md) {
                    avatarView(url: other.avatarURL, username: other.username)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(other.username)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("@\(other.username)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
            }
        }
    }

    private func avatarView(url: String?, username: String) -> some View {
        Group {
            if let u = url, !u.isEmpty, let parsed = URL(string: u) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholderAvatar(username: username)
                    }
                }
            } else {
                placeholderAvatar(username: username)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private func placeholderAvatar(username: String) -> some View {
        Circle()
            .fill(Theme.Colors.tertiaryBackground)
            .overlay(
                Text(String((username.isEmpty ? "?" : username).prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            )
    }

    private var itemsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(order.products) { product in
                HStack(spacing: Theme.Spacing.md) {
                    productThumb(url: product.imageUrl, isMysteryBox: product.isMysteryBox)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        if let price = product.price, !price.isEmpty {
                            Text("£\(price)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
            }
        }
    }

    private var summaryCard: some View {
        HStack {
            Text(L10n.string("Total"))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Text("£\(order.priceTotal)")
                .font(Theme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.primaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
    }

    private func shippingAddressCard(_ addr: ShippingAddress) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if !addr.address.isEmpty {
                Text(addr.address)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                if !addr.city.isEmpty {
                    Text(addr.city)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                if let state = addr.state, !state.isEmpty {
                    Text(state)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                if !addr.postcode.isEmpty {
                    Text(addr.postcode)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            if !addr.country.isEmpty {
                Text(addr.country)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
    }

    private func formatShippingAddress(_ addr: ShippingAddress) -> String {
        var parts: [String] = []
        if !addr.address.isEmpty { parts.append(addr.address) }
        if !addr.city.isEmpty { parts.append(addr.city) }
        if let state = addr.state, !state.isEmpty { parts.append(state) }
        if !addr.postcode.isEmpty { parts.append(addr.postcode) }
        if !addr.country.isEmpty { parts.append(addr.country) }
        return parts.joined(separator: ", ")
    }

    private func metadataLine(for product: OrderProductSummary?) -> String? {
        guard let product else { return nil }
        var parts: [String] = []
        if let size = product.size, !size.isEmpty { parts.append("Size: \(size)") }
        if !product.colors.isEmpty { parts.append("Colour: \(product.colors.joined(separator: ", "))") }
        if let style = product.style, !style.isEmpty { parts.append("Style: \(style)") }
        if let brand = product.brand, !brand.isEmpty { parts.append("Brand: \(brand)") }
        if !product.materials.isEmpty { parts.append("Material: \(product.materials.joined(separator: ", "))") }
        if let condition = product.condition, !condition.isEmpty { parts.append(condition.replacingOccurrences(of: "_", with: " ")) }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    private func loadProductForDetail() {
        guard !loadingProductDetail, productDetailItem == nil,
              let first = order.products.first, let productId = Int(first.id) else { return }
        loadingProductDetail = true
        Task {
            defer { loadingProductDetail = false }
            if let item = try? await productService.getProduct(id: productId) {
                await MainActor.run {
                    productDetailItem = item
                }
            }
        }
    }

    private var resolvedDeliveryDate: Date? {
        if let d = order.deliveryDate { return d }
        guard let service = effectiveOrder.shipmentService?.uppercased(),
              let opts = currentUser?.postageOptions else { return nil }
        let days: Int?
        switch service {
        case "ROYAL_MAIL":
            days = opts.royalMailStandardDays ?? opts.royalMailFirstClassDays
        case "EVRI":
            days = opts.evriDays
        case "DPD":
            days = opts.dpdDays
        default:
            days = nil
        }
        guard let d = days, d > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: d, to: effectiveOrder.createdAt)
    }

    private func productThumb(url: String?, isMysteryBox: Bool) -> some View {
        Group {
            if isMysteryBox {
                MysteryBoxAnimatedMediaView()
            } else if let u = url, !u.isEmpty, let parsed = URL(string: u) {
                AsyncImage(url: parsed) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Rectangle().fill(Theme.Colors.tertiaryBackground)
                    }
                }
            } else {
                Rectangle()
                    .fill(Theme.Colors.tertiaryBackground)
                    .overlay(Image(systemName: "photo").foregroundColor(Theme.Colors.secondaryText))
            }
        }
        .frame(width: 120, height: 140)
        .clipped()
        .cornerRadius(12)
    }

    /// Buyer help entry (same destinations as chat order card): buyer only; hide when order is done, cancelled, or both parties have finished reviewing.
    private var canShowBuyerOrderHelp: Bool {
        guard viewerIsOrderBuyer else { return false }
        if bothPartiesSubmittedManualReviews { return false }
        let st = effectiveOrder.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard st != "CANCELLED" && st != "REFUNDED" && st != "COMPLETED" else { return false }
        return true
    }

    /// Multibuy: buyer must pick which line item the issue is about before opening help.
    private var shouldPickProductBeforeOrderHelp: Bool {
        effectiveOrder.products.count > 1
    }

    private var hasPendingCancellation: Bool {
        (effectiveOrder.cancellation?.status.uppercased() == "PENDING")
    }

    /// Buyer has submitted a request and is waiting on the seller.
    private var isPendingCancellationInitiator: Bool {
        guard let c = effectiveOrder.cancellation, c.status.uppercased() == "PENDING" else { return false }
        if c.requestedBySeller { return isSeller == true }
        return isSeller == false
    }

    /// Counterparty can approve or decline a pending request.
    private var canShowRespondToCancellation: Bool {
        guard let c = effectiveOrder.cancellation, c.status.uppercased() == "PENDING" else { return false }
        guard let sellerView = isSeller else { return false }
        if c.requestedBySeller { return sellerView == false }
        return sellerView == true
    }

    /// Show "Cancel order" when: buyer view, order not yet delivered/cancelled/refunded, no open cancellation request.
    private var canShowCancelOrder: Bool {
        guard isSeller == false else { return false }
        guard !effectiveOrder.hasOpenOrderIssue else { return false }
        guard !hasPendingCancellation else { return false }
        let tracking = effectiveOrder.trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !tracking.isEmpty { return false }
        let terminal = ["SHIPPED", "IN_TRANSIT", "READY_FOR_PICKUP", "DELIVERED", "CANCELLED", "REFUNDED"]
        return !terminal.contains(effectiveOrder.status)
    }

    /// Seller-initiated cancellation request (confirmed, pre-tracking), when no pending request exists.
    private var canShowSellerCancelOrder: Bool {
        guard isSeller == true else { return false }
        guard !hasPendingCancellation else { return false }
        let tracking = effectiveOrder.trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !tracking.isEmpty { return false }
        let terminal = ["SHIPPED", "IN_TRANSIT", "READY_FOR_PICKUP", "DELIVERED", "CANCELLED", "REFUNDED"]
        return !terminal.contains(effectiveOrder.status)
    }

    /// Show seller shipping actions when: seller view, order paid (CONFIRMED/PENDING/SHIPPED).
    private var canShowSellerShipping: Bool {
        guard isSeller == true else { return false }
        return ["CONFIRMED", "SHIPPED"].contains(effectiveOrder.status)
    }

    /// Once shipped/tracking exists, lock shipping actions to prevent tracking edits.
    private var sellerShippingActionsLocked: Bool {
        if effectiveOrder.status == "SHIPPED" { return true }
        let tracking = effectiveOrder.trackingNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !tracking.isEmpty
    }

    private var sellerShippingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    showConfirmShippingSheet = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L10n.string("Confirm shipping (manual)"))
                            .font(Theme.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                }
                .buttonStyle(PlainTappableButtonStyle())
                .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
                .disabled(sellerShippingActionsLocked)
                .opacity(sellerShippingActionsLocked ? 0.45 : 1)

                PrimaryGlassButton(
                    L10n.string("View shipping label"),
                    icon: "shippingbox",
                    isLoading: shippingLabelLoading
                ) {
                    Task { await generateLabel() }
                }
                .disabled(shippingLabelLoading || sellerShippingActionsLocked)
                .opacity(sellerShippingActionsLocked ? 0.45 : 1)
            }

            if let err = shippingLabelError {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
        }
        .sheet(isPresented: $showConfirmShippingSheet) {
            confirmShippingSheet
                .onAppear {
                    // Default carrier from selected shipping service shown on this screen.
                    if confirmShippingCarrier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let service = effectiveOrder.shipmentService,
                       !service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        confirmShippingCarrier = service
                    }
                }
        }
    }

    private var shippingActionSheet: some View {
        VStack(spacing: Theme.Spacing.sm) {
            sellerShippingCard
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 6)
        .padding(.bottom, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.Colors.glassBorder)
                .frame(height: 1)
                .opacity(0.4)
        }
    }

    private var confirmShippingSheet: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("Carrier name"))
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(confirmShippingCarrier)
                        .font(.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                TextField(L10n.string("Tracking number"), text: $confirmShippingTracking)
                    .textContentType(.none)
                TextField(L10n.string("Tracking URL (optional)"), text: $confirmShippingTrackingURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if let err = confirmShippingError {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
            .navigationTitle(L10n.string("Confirm shipping"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) {
                        showConfirmShippingSheet = false
                        confirmShippingError = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Submit")) {
                        Task { await submitConfirmShipping() }
                    }
                    .disabled(confirmShippingCarrier.trimmingCharacters(in: .whitespaces).isEmpty || confirmShippingTracking.trimmingCharacters(in: .whitespaces).isEmpty || confirmShippingSubmitting)
                }
            }
        }
    }

    private func generateLabel() async {
        guard let orderId = numericOrderIdIfAvailable else { return }
        shippingLabelError = nil
        shippingLabelLoading = true
        defer { shippingLabelLoading = false }
        userService.updateAuthToken(authService.authToken)
        do {
            let result = try await userService.generateShippingLabel(orderId: orderId)
            if result.success, let urlStr = result.labelUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                await MainActor.run { UIApplication.shared.open(url) }
            } else {
                shippingLabelError = result.message ?? "No label URL"
            }
        } catch {
            shippingLabelError = L10n.userFacingError(error)
        }
    }

    private func submitConfirmShipping() async {
        guard let orderId = numericOrderIdIfAvailable else { return }
        let carrier = confirmShippingCarrier.trimmingCharacters(in: .whitespaces)
        let tracking = confirmShippingTracking.trimmingCharacters(in: .whitespaces)
        let trackingURL = confirmShippingTrackingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !carrier.isEmpty, !tracking.isEmpty else { return }
        confirmShippingError = nil
        confirmShippingSubmitting = true
        defer { confirmShippingSubmitting = false }
        userService.updateAuthToken(authService.authToken)
        do {
            try await userService.confirmShipping(
                orderId: orderId,
                carrierName: carrier,
                trackingNumber: tracking,
                trackingUrl: trackingURL.isEmpty ? nil : trackingURL
            )
            await MainActor.run {
                showConfirmShippingSheet = false
                confirmShippingCarrier = ""
                confirmShippingTracking = ""
                confirmShippingTrackingURL = ""
            }
            await hydrateOrderIfNeeded(force: true)
        } catch {
            confirmShippingError = L10n.userFacingError(error)
        }
    }

    private func respondToCancellationRequest(approve: Bool) async {
        guard let orderId = numericOrderIdIfAvailable else { return }
        await MainActor.run {
            cancellationBusy = true
            cancellationActionError = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            if approve {
                try await userService.approveOrderCancellation(orderId: orderId)
            } else {
                try await userService.rejectOrderCancellation(orderId: orderId)
            }
            await hydrateOrderIfNeeded(force: true)
            await refreshTrackingDetailsIfNeeded()
        } catch {
            await MainActor.run {
                cancellationActionError = L10n.userFacingError(error)
            }
        }
        await MainActor.run { cancellationBusy = false }
    }

    private func markOrderDelivered() async {
        guard let orderId = numericOrderIdIfAvailable else { return }
        await MainActor.run {
            markDeliveredBusy = true
            markDeliveredError = nil
        }
        userService.updateAuthToken(authService.authToken)
        do {
            await hydrateOrderIfNeeded(force: true)
            var st = orderStatusUppercased
            if st == "CONFIRMED" {
                try await userService.updateOrderStatus(orderId: orderId, status: "SHIPPED")
                await hydrateOrderIfNeeded(force: true)
                st = orderStatusUppercased
            }
            if st != "DELIVERED" && st != "COMPLETED" {
                try await userService.updateOrderStatus(orderId: orderId, status: "DELIVERED")
            }
            await hydrateOrderIfNeeded(force: true)
            await refreshTrackingDetailsIfNeeded()
            await MainActor.run {
                markDeliveredBusy = false
                presentLeaveReviewSheetAfterDeliveryIfEligible()
            }
        } catch {
            await MainActor.run {
                markDeliveredError = L10n.userFacingError(error)
                markDeliveredBusy = false
            }
        }
    }

    /// After a successful “received item” flow, open the same sheet as “Leave a review” when the buyer may rate the seller.
    private func presentLeaveReviewSheetAfterDeliveryIfEligible() {
        guard viewerIsOrderBuyer else { return }
        let st = orderStatusUppercased
        guard st == "DELIVERED" || st == "COMPLETED" else { return }
        guard !effectiveOrder.hasOpenOrderIssue else { return }
        guard !effectiveOrder.buyerHasLeftReview else { return }
        guard numericOrderIdIfAvailable != nil else { return }
        guard let sellerId = effectiveSellerNumericIdForBuyerReview else { return }
        let buyerId = effectiveOrder.buyerUserId ?? currentUser?.userId
        if let buyerId, buyerId != 0 {
            let leftManualBuyerReview = effectiveOrder.orderReviews.contains {
                $0.isAutoReview == false && $0.reviewerUserId == buyerId && $0.reviewedUserId == sellerId
            }
            if leftManualBuyerReview { return }
        }
        feedbackSheetRole = .buyerRatesSeller
        showLeaveFeedbackSheet = true
    }

    /// Fills `resolvedCounterpartyNumericUserId` when the order row shows the counterparty by username but omits numeric `userId` (needed for `rateUser`).
    private func resolveCounterpartyNumericUserIdIfNeeded() async {
        guard resolvedCounterpartyNumericUserId == nil else { return }
        guard let username = normalizedOtherPartyUsernameForLookup() else { return }
        let rawSellerId = effectiveOrder.sellerUserId ?? effectiveOrder.otherParty?.userId
        let rawBuyerId = effectiveOrder.buyerUserId ?? effectiveOrder.otherParty?.userId
        let missingSellerId = viewerIsOrderBuyer && (rawSellerId == nil || rawSellerId == 0)
        let missingBuyerId = viewerIsOrderSeller && (rawBuyerId == nil || rawBuyerId == 0)
        guard missingSellerId || missingBuyerId else { return }
        userService.updateAuthToken(authService.authToken)
        guard let profile = try? await userService.getUserByUsername(username), let uid = profile.userId, uid != 0 else { return }
        await MainActor.run { resolvedCounterpartyNumericUserId = uid }
    }

    private func hydrateOrderIfNeeded(force: Bool = false) async {
        guard force || hydratedOrder == nil else { return }
        let sold = (try? await userService.getUserOrders(isSeller: true, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = sold.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
            }
            return
        }
        let bought = (try? await userService.getUserOrders(isSeller: false, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = bought.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
            }
            return
        }
        let pub = order.publicId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !pub.isEmpty {
            if let found = sold.first(where: { ($0.publicId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == pub }) {
                await MainActor.run { hydratedOrder = found }
                return
            }
            if let found = bought.first(where: { ($0.publicId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == pub }) {
                await MainActor.run { hydratedOrder = found }
            }
        }
    }

    /// Re-check tracking on each page open until tracking exists, then persist and stop future checks.
    private func refreshTrackingDetailsIfNeeded() async {
        let currentTracking = effectiveOrder.trackingUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !currentTracking.isEmpty { return }

        let sold = (try? await userService.getUserOrders(isSeller: true, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = sold.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
            }
            return
        }
        let bought = (try? await userService.getUserOrders(isSeller: false, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = bought.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
            }
        }
    }
}

/// Rate the other party on an order (`rateUser`); buyer→seller or seller→buyer.
private struct LeaveOrderFeedbackSheet: View {
    let orderId: Int
    let rateeUserId: Int
    var role: OrderFeedbackSheetRole
    /// Buyer flow while status is still DELIVERED (submit completes order / payout).
    var buyerSubmitReleasesPayment: Bool
    var onFinished: () -> Void

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 5
    @State private var selectedSuggestionTags: Set<String> = []
    @State private var comment = ""
    @State private var busy = false
    @State private var errorMessage: String?

    private let userService = UserService()
    private let maxReviewCommentLength = 500

    private var reviewTagSuggestions: [String] {
        switch role {
        case .buyerRatesSeller:
            return [
                L10n.string("Fast delivery"),
                L10n.string("Item as described"),
                L10n.string("Great communication"),
                L10n.string("Well packaged"),
                L10n.string("Accurate photos"),
                L10n.string("Would buy again"),
            ]
        case .sellerRatesBuyer:
            return [
                L10n.string("Quick payment"),
                L10n.string("Smooth transaction"),
                L10n.string("Great communication"),
                L10n.string("Polite and friendly"),
                L10n.string("Would sell again"),
                L10n.string("Easy to work with"),
            ]
        }
    }

    private var footerText: String {
        switch role {
        case .buyerRatesSeller:
            if buyerSubmitReleasesPayment {
                return "Submitting completes your order and releases payment to the seller, unless the order is on hold."
            }
            return "Your feedback is shared with the seller and visible on their profile."
        case .sellerRatesBuyer:
            return "Your rating helps other sellers understand their experience with this buyer."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    InteractiveStarRatingControl(rating: $rating)

                    ZStack(alignment: .bottomTrailing) {
                        TextField(L10n.string("Comment (optional)"), text: $comment, axis: .vertical)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .lineLimit(6...12)
                            .frame(minHeight: 140, alignment: .topLeading)
                            .padding(.horizontal, Theme.TextInput.insetHorizontal)
                            .padding(.top, Theme.TextInput.insetVertical)
                            .padding(.bottom, 28)
                            .padding(.trailing, Theme.Spacing.sm)
                        Text("\(min(comment.count, maxReviewCommentLength))/\(maxReviewCommentLength)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(.trailing, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.sm)
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                    .onChange(of: comment) { _, new in
                        if new.count > maxReviewCommentLength {
                            comment = String(new.prefix(maxReviewCommentLength))
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.string("What went well?"))
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.primaryText)

                        HorizontalFlowLayout(
                            horizontalSpacing: Theme.Spacing.sm,
                            verticalSpacing: Theme.Spacing.sm
                        ) {
                            ForEach(reviewTagSuggestions, id: \.self) { tag in
                                PillTag(
                                    title: tag,
                                    isSelected: selectedSuggestionTags.contains(tag),
                                    accentWhenUnselected: true,
                                    showShadow: false,
                                    singleLineTitle: true,
                                    action: {
                                        if selectedSuggestionTags.contains(tag) {
                                            selectedSuggestionTags.remove(tag)
                                        } else {
                                            selectedSuggestionTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    Text(footerText)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Leave a review"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.Colors.glassBorder.opacity(0.35))
                        .frame(height: 0.5)
                    Group {
                        if busy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                        } else {
                            Button {
                                Task { await submit() }
                            } label: {
                                Text(L10n.string("Submit"))
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.primaryColor)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.md)
                        }
                    }
                    .background(Theme.Colors.background)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.primaryColor)
                    .disabled(busy)
                }
            }
        }
    }

    private func submit() async {
        await MainActor.run {
            busy = true
            errorMessage = nil
        }
        userService.updateAuthToken(authService.authToken)
        let snapped = (rating * 2).rounded() / 2
        do {
            let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            try await userService.rateUser(
                comment: trimmedComment,
                highlights: selectedSuggestionTags.sorted(),
                orderId: orderId,
                rating: snapped,
                userId: rateeUserId
            )
            await MainActor.run {
                busy = false
                HapticManager.success()
                dismiss()
                onFinished()
            }
        } catch {
            await MainActor.run {
                busy = false
                errorMessage = L10n.userFacingError(error)
            }
        }
    }
}

/// Sheet: single-select one order line before “I have a problem” help (multibuy).
private struct MultibuyOrderProblemProductPickerSheet: View {
    let products: [OrderProductSummary]
    let onContinue: (OrderProductSummary) -> Void
    let onCancel: () -> Void

    @State private var selectedId: String?

    var body: some View {
        let detentHeight = Self.clampedDetentHeight(productCount: products.count)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("Which item is your issue about? Choose one to continue."))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.xs)

                    VStack(spacing: 0) {
                        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 56 + Theme.Spacing.md * 2)
                            }
                            Button {
                                selectedId = product.id
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Group {
                                        if product.isMysteryBox {
                                            MysteryBoxAnimatedMediaView()
                                        } else if let urlString = product.imageUrl, let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let img): img.resizable().scaledToFill()
                                                default: ImageShimmerPlaceholderFilled(cornerRadius: 8)
                                                }
                                            }
                                        } else {
                                            ImageShimmerPlaceholderFilled(cornerRadius: 8)
                                        }
                                    }
                                    .frame(width: 56, height: 56)
                                    .clipped()
                                    .cornerRadius(8)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.primaryText)
                                            .multilineTextAlignment(.leading)
                                        if let line = Self.formattedPriceLine(from: product.price) {
                                            Text(line)
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.secondaryText)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if selectedId == product.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Theme.primaryColor)
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.descriptionFieldCornerRadius, style: .continuous))
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .padding(.bottom, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Select item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Continue")) {
                        guard let id = selectedId, let picked = products.first(where: { $0.id == id }) else { return }
                        onContinue(picked)
                    }
                    .disabled(selectedId == nil)
                }
            }
        }
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.visible)
    }

    /// Inline nav + instruction + rows + tight bottom inset (sheet safe area adds home indicator).
    private static func preferredDetentHeight(productCount: Int) -> CGFloat {
        let navChrome: CGFloat = 108
        let instructionBlock: CGFloat = 92
        let rowWithDivider: CGFloat = 78
        let bottomContentPadding: CGFloat = Theme.Spacing.xs + 12
        let n = max(productCount, 1)
        return navChrome + instructionBlock + CGFloat(n) * rowWithDivider + bottomContentPadding
    }

    private static func clampedDetentHeight(productCount: Int) -> CGFloat {
        let screen = UIScreen.main.bounds.height
        let raw = preferredDetentHeight(productCount: productCount)
        return min(screen * 0.92, max(raw, 300))
    }

    /// API may return `"50"`, `"50.00"`, or `"£50"`; always show GBP like the rest of the app.
    private static func formattedPriceLine(from raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = Double(cleaned) {
            return CurrencyFormatter.gbp(v)
        }
        return raw
    }
}

/// Loads `Item` by id for each row in a multi-item order (separate navigation stacks per line).
private struct OrderLineProductDetailHost: View {
    let productId: String
    @EnvironmentObject private var authService: AuthService
    @State private var item: Item?
    @State private var loading = true
    private let productService = ProductService()

    var body: some View {
        Group {
            if let item {
                ItemDetailView(item: item, authService: authService)
            } else if loading {
                ProgressView(L10n.string("Loading..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(L10n.string("Product unavailable"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.Colors.background)
        .task {
            guard let id = Int(productId) else {
                loading = false
                return
            }
            productService.updateAuthToken(authService.authToken)
            item = try? await productService.getProduct(id: id)
            loading = false
        }
    }
}
