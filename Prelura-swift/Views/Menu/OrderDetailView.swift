import SwiftUI

/// Order details: status, seller/buyer, items, summary. Matches reference design with section labels and rounded cards.
struct OrderDetailView: View {
    let order: Order
    /// When viewing from My Orders: true = sold (so other party is Buyer), false = bought (so other party is Seller). When nil (e.g. from chat), section shows "Other party".
    var isSeller: Bool? = nil

    @EnvironmentObject var authService: AuthService
    private let userService = UserService()

    @State private var rateStars: Int = 0
    @State private var rateComment: String = ""
    @State private var isSubmittingRating = false
    @State private var hasRated = false
    @State private var ratingError: String?
    @State private var shippingLabelLoading = false
    @State private var shippingLabelError: String?
    @State private var showConfirmShippingSheet = false
    @State private var confirmShippingCarrier = ""
    @State private var confirmShippingTracking = ""
    @State private var confirmShippingSubmitting = false
    @State private var confirmShippingError: String?

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    /// Section label for the other party: "Seller", "Buyer", or "Other party".
    private var otherPartySectionTitle: String {
        guard let isSeller = isSeller else { return L10n.string("Other party") }
        return isSeller ? L10n.string("Buyer") : L10n.string("Seller")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Header: Order - PR23DG2DF3 (matches debug design)
                Text("Order - \(order.displayOrderId)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryText)

                // Status: label above, then single card with status text in purple
                sectionLabel(L10n.string("Status"))
                statusCard

                if order.otherParty != nil {
                    sectionLabel(otherPartySectionTitle)
                    otherPartyCard
                }

                sectionLabel(L10n.string("Items"))
                itemsSection

                sectionLabel(L10n.string("Summary"))
                summaryCard

                if let addr = order.shippingAddress, !formatShippingAddress(addr).isEmpty {
                    sectionLabel(L10n.string("Shipping Address"))
                    shippingAddressCard(addr)
                }

                if canShowRateSeller {
                    sectionLabel(L10n.string("Rate seller"))
                    rateSellerCard
                }

                if canShowCancelOrder {
                    NavigationLink(destination: CancelOrderView(order: order)) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text(L10n.string("Cancel order"))
                        }
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }

                if canShowSellerShipping {
                    sectionLabel(L10n.string("Shipping"))
                    sellerShippingCard
                }

                Text("Ordered \(dateFormatter.string(from: order.createdAt))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Order details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
    }

    private var statusCard: some View {
        Text(order.statusDisplay)
            .font(Theme.Typography.body)
            .fontWeight(.medium)
            .foregroundColor(Theme.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private var otherPartyCard: some View {
        Group {
            if let other = order.otherParty {
                HStack(spacing: Theme.Spacing.md) {
                    avatarView(url: other.avatarURL, username: other.username)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(other.displayName.isEmpty ? other.username : other.displayName)
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
                    productThumb(url: product.imageUrl)
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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

    private func productThumb(url: String?) -> some View {
        Group {
            if let u = url, !u.isEmpty, let parsed = URL(string: u) {
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
        .frame(width: 56, height: 56)
        .clipped()
        .cornerRadius(8)
    }

    /// Show "Cancel order" when: buyer view, order not yet delivered/cancelled/refunded.
    private var canShowCancelOrder: Bool {
        guard isSeller == false else { return false }
        let terminal = ["DELIVERED", "CANCELLED", "REFUNDED"]
        return !terminal.contains(order.status)
    }

    /// Show seller shipping actions when: seller view, order paid (CONFIRMED/PENDING/SHIPPED).
    private var canShowSellerShipping: Bool {
        guard isSeller == true else { return false }
        return ["CONFIRMED", "PENDING", "SHIPPED"].contains(order.status)
    }

    /// Show "Rate seller" when: buyer view (isSeller == false), order delivered, we have orderId and seller userId, and not yet rated.
    private var canShowRateSeller: Bool {
        guard isSeller == false,
              order.status == "DELIVERED",
              !hasRated,
              Int(order.id) != nil,
              let other = order.otherParty, other.userId != nil else { return false }
        return true
    }

    private var rateSellerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        rateStars = i
                    } label: {
                        Image(systemName: i <= rateStars ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundColor(i <= rateStars ? Theme.primaryColor : Theme.Colors.tertiaryBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField(L10n.string("Add a comment (optional)"), text: $rateComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            if let err = ratingError {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
            Button {
                Task { await submitRating() }
            } label: {
                if isSubmittingRating {
                    ProgressView()
                        .tint(Theme.Colors.primaryText)
                } else {
                    Text(L10n.string("Submit rating"))
                }
            }
            .disabled(rateStars == 0 || isSubmittingRating)
            .buttonStyle(.borderedProminent)
            .tint(Theme.primaryColor)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private func submitRating() async {
        guard let orderId = Int(order.id), let userId = order.otherParty?.userId else { return }
        ratingError = nil
        isSubmittingRating = true
        defer { isSubmittingRating = false }
        userService.updateAuthToken(authService.authToken)
        do {
            try await userService.rateUser(comment: rateComment.isEmpty ? "No comment" : rateComment, orderId: orderId, rating: rateStars, userId: userId)
            hasRated = true
        } catch {
            ratingError = error.localizedDescription
        }
    }

    private var sellerShippingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button {
                Task { await generateLabel() }
            } label: {
                if shippingLabelLoading {
                    ProgressView()
                        .tint(Theme.Colors.primaryText)
                } else {
                    Label(L10n.string("View shipping label"), systemImage: "shippingbox")
                }
            }
            .disabled(shippingLabelLoading)
            .buttonStyle(.borderedProminent)
            .tint(Theme.primaryColor)

            Button {
                showConfirmShippingSheet = true
            } label: {
                Label(L10n.string("Confirm shipping (manual)"), systemImage: "location.circle")
            }
            .buttonStyle(.bordered)
            .tint(Theme.primaryColor)

            if let err = shippingLabelError {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
        .sheet(isPresented: $showConfirmShippingSheet) {
            confirmShippingSheet
        }
    }

    private var confirmShippingSheet: some View {
        NavigationStack {
            Form {
                TextField(L10n.string("Carrier name"), text: $confirmShippingCarrier)
                    .textContentType(.none)
                TextField(L10n.string("Tracking number"), text: $confirmShippingTracking)
                    .textContentType(.none)
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
        guard let orderId = Int(order.id) else { return }
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
            shippingLabelError = error.localizedDescription
        }
    }

    private func submitConfirmShipping() async {
        guard let orderId = Int(order.id) else { return }
        let carrier = confirmShippingCarrier.trimmingCharacters(in: .whitespaces)
        let tracking = confirmShippingTracking.trimmingCharacters(in: .whitespaces)
        guard !carrier.isEmpty, !tracking.isEmpty else { return }
        confirmShippingError = nil
        confirmShippingSubmitting = true
        defer { confirmShippingSubmitting = false }
        userService.updateAuthToken(authService.authToken)
        do {
            try await userService.confirmShipping(orderId: orderId, carrierName: carrier, trackingNumber: tracking, trackingUrl: nil)
            await MainActor.run {
                showConfirmShippingSheet = false
                confirmShippingCarrier = ""
                confirmShippingTracking = ""
            }
        } catch {
            confirmShippingError = error.localizedDescription
        }
    }
}
