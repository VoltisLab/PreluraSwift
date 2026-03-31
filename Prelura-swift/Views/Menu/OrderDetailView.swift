import SwiftUI
import UIKit

/// Order details: status, seller/buyer, items, summary. Matches reference design with section labels and rounded cards.
struct OrderDetailView: View {
    private static var orderSnapshotCache: [String: Order] = [:]

    let order: Order
    /// When viewing from My Orders: true = sold (so other party is Buyer), false = bought (so other party is Seller). When nil (e.g. from chat), section shows "Other party".
    var isSeller: Bool? = nil

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
    @State private var isInitialPageLoading = true
    @State private var hasLoadedOnce = false
    @State private var showTrackingCopiedToast = false
    @State private var cancellationBusy = false
    @State private var cancellationActionError: String?

    init(order: Order, isSeller: Bool? = nil) {
        self.order = order
        self.isSeller = isSeller
        let cached = Self.orderSnapshotCache[order.id]
        _hydratedOrder = State(initialValue: cached)
        _isInitialPageLoading = State(initialValue: cached == nil)
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

    var body: some View {
        Group {
            if isInitialPageLoading {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                    Text("Loading order details...")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(Theme.Colors.background)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        headerSection
                        processingCard
                        productCard
                        if effectiveOrder.otherParty != nil {
                            sectionLabel(otherPartySectionTitle)
                            outlinedPartyCard
                        }
                        sectionLabel(L10n.string("Shipping Address"))
                        shippingAddressAndDeliverySection
                        sectionLabel("Tracking details")
                        shippingSelectedCard

                        if canShowBuyerOrderHelp {
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
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
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
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                        }

                        if canShowCancelOrder {
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
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }

                        if canShowSellerCancelOrder {
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
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, canShowSellerShipping ? Theme.Spacing.md : Theme.Spacing.xl)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Order details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if canShowSellerShipping {
                shippingActionSheet
            }
        }
        .task {
            guard !hasLoadedOnce else { return }
            hasLoadedOnce = true
            userService.updateAuthToken(authService.authToken)

            currentUser = try? await userService.getUser(username: nil)

            // Keep page content stable once loaded: only fetch full hydration the first time.
            if hydratedOrder == nil {
                await hydrateOrderIfNeeded()
                isInitialPageLoading = false
            }

            // Tracking details is the only section that should re-check on each open.
            await refreshTrackingDetailsIfNeeded()
        }
        .sheet(isPresented: $showTrackingWeb) {
            if let trackingWebURL {
                NavigationStack {
                    WebView(url: trackingWebURL, isLoading: $isTrackingWebLoading)
                        .navigationTitle("Tracking")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .preluraModalSheetBackground()
            }
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
            Text("Order - \(effectiveOrder.displayOrderId)")
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
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }

    private var progressPercent: Int {
        switch effectiveOrder.status {
        case "CONFIRMED": return 20
        case "SHIPPED": return 65
        case "DELIVERED": return 100
        case "CANCELLED", "REFUNDED": return 0
        default: return 25
        }
    }

    private var productCard: some View {
        let p = effectiveOrder.products.first
        return NavigationLink {
            productDestinationView
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                productThumb(url: p?.imageUrl)
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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainTappableButtonStyle())
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
                    RoundedRectangle(cornerRadius: 16)
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
                            RoundedRectangle(cornerRadius: 16)
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
                RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
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
            RoundedRectangle(cornerRadius: 16)
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
        .frame(width: 120, height: 140)
        .clipped()
        .cornerRadius(12)
    }

    /// Buyer help entry (same destinations as chat order card): not for cancelled/refunded orders.
    private var canShowBuyerOrderHelp: Bool {
        guard isSeller == false else { return false }
        let st = effectiveOrder.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return st != "CANCELLED" && st != "REFUNDED"
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
        guard let orderId = Int(effectiveOrder.id) else { return }
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
        guard let orderId = Int(effectiveOrder.id) else { return }
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
            confirmShippingError = error.localizedDescription
        }
    }

    private func respondToCancellationRequest(approve: Bool) async {
        guard let orderId = Int(effectiveOrder.id) else { return }
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
                cancellationActionError = error.localizedDescription
            }
        }
        await MainActor.run { cancellationBusy = false }
    }

    private func hydrateOrderIfNeeded(force: Bool = false) async {
        guard force || hydratedOrder == nil else { return }
        let sold = (try? await userService.getUserOrders(isSeller: true, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = sold.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
                Self.orderSnapshotCache[order.id] = found
            }
            return
        }
        let bought = (try? await userService.getUserOrders(isSeller: false, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = bought.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
                Self.orderSnapshotCache[order.id] = found
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
                Self.orderSnapshotCache[order.id] = found
            }
            return
        }
        let bought = (try? await userService.getUserOrders(isSeller: false, pageNumber: 1, pageCount: 100).orders) ?? []
        if let found = bought.first(where: { $0.id == order.id }) {
            await MainActor.run {
                hydratedOrder = found
                Self.orderSnapshotCache[order.id] = found
            }
        }
    }
}
