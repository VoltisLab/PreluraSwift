import SwiftUI

/// Delivery type for checkout (matches Flutter Enum$DeliveryTypeEnum: HOME_DELIVERY, COLLECTION_POINT).
enum DeliveryType: String, CaseIterable {
    case homeDelivery = "Home delivery"
    case collectionPoint = "Collection point"

    var shippingFee: Double {
        switch self {
        case .homeDelivery: return 2.29
        case .collectionPoint: return 2.99
        }
    }

    var iconName: String {
        switch self {
        case .homeDelivery: return "house"
        case .collectionPoint: return "mappin.circle"
        }
    }
}

/// Full payment/checkout screen (Flutter PaymentRoute). Products, address, delivery, buyer protection, total, Pay by card.
struct PaymentView: View {
    let products: [Item]
    let totalPrice: Double
    var customOffer: Bool = false
    var respondToCustomOffer: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var currentUser: User?
    @State private var selectedDelivery: DeliveryType = .homeDelivery
    @State private var buyerProtectionEnabled: Bool = false
    @State private var paymentMethod: PaymentMethod?
    @State private var isLoadingPaymentMethod = true
    @State private var isSubmitting = false
    @State private var showPaymentSuccess = false
    @State private var errorMessage: String?
    @State private var discountTiers: [MultibuyDiscount] = []

    private let userService = UserService()
    private let productService = ProductService()

    /// Sum of all product prices (before multi-buy discount).
    private var orderSubtotal: Double { products.reduce(0) { $0 + $1.price } }
    /// Multi-buy discount % from seller's tiers (when all items from same seller and count qualifies).
    private func discountPercent(for count: Int) -> Int {
        let sorted = discountTiers.filter { $0.isActive && $0.minItems <= count }.sorted { $0.minItems > $1.minItems }
        guard let tier = sorted.first else { return 0 }
        return Int(Double(tier.discountValue) ?? 0)
    }
    private var multiBuyDiscountPercent: Int { discountPercent(for: products.count) }
    private var multiBuyDiscountAmount: Double { orderSubtotal * Double(multiBuyDiscountPercent) / 100 }
    private var afterDiscount: Double { orderSubtotal - multiBuyDiscountAmount }
    private var buyerProtectionFee: Double {
        let p = afterDiscount
        if p <= 10 { return (10 * p) / 100 }
        if p <= 50 { return (8 * p) / 100 }
        if p <= 200 { return (6 * p) / 100 }
        return (5 * p) / 100
    }
    private var total: Double {
        afterDiscount + selectedDelivery.shippingFee + (buyerProtectionEnabled ? buyerProtectionFee : 0)
    }

    /// When all products share the same seller, returns that seller's userId for multibuy fetch.
    private var commonSellerUserId: Int? {
        guard let first = products.first?.seller.userId else { return nil }
        let allSame = products.allSatisfy { $0.seller.userId == first }
        return allSame ? first : nil
    }

    private func formatAddress(_ addr: ShippingAddress?) -> String {
        guard let addr else { return "No address set" }
        var parts: [String] = []
        if !addr.address.isEmpty { parts.append(addr.address) }
        if !addr.city.isEmpty { parts.append(addr.city) }
        if !addr.postcode.isEmpty { parts.append(addr.postcode) }
        return parts.isEmpty ? "No address set" : parts.joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    sectionHeader("Address")
                    NavigationLink(destination: ShippingAddressView()) {
                        paymentRow(title: currentUser?.shippingAddress.map { formatAddress($0) } ?? currentUser?.location ?? "No address set", trailing: "chevron.right")
                    }
                    .buttonStyle(.plain)

                    sectionHeader("Delivery Option")
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(DeliveryType.allCases, id: \.self) { option in
                            deliveryOptionCard(option)
                        }
                    }

                    sectionHeader("Your Contact details")
                    paymentRow(title: currentUser?.phoneDisplay ?? "+44 ••••••••••", trailing: "chevron.right")

                    Toggle(isOn: $buyerProtectionEnabled) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "shield")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.Colors.primaryText)
                            Text(L10n.string("Buyer protection fee"))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                            Text(String(format: "£%.2f", buyerProtectionFee))
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    .tint(Theme.primaryColor)

                    sectionHeader("\(products.count) \(products.count == 1 ? "Item" : "Items")")
                    VStack(spacing: 0) {
                        ForEach(products) { item in
                            HStack(alignment: .top) {
                                Text(item.title)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .lineLimit(2)
                                Spacer()
                                Text(item.formattedPrice)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .overlay(ContentDivider(), alignment: .bottom)
                        }
                        infoRow(L10n.string("Price"), String(format: "£%.2f", orderSubtotal))
                        if products.count > 1 && multiBuyDiscountPercent > 0 {
                            infoRow(String(format: L10n.string("Multi-buy discount (%d%%)"), multiBuyDiscountPercent), String(format: "-£%.2f", multiBuyDiscountAmount), valueColor: Theme.primaryColor)
                        }
                        infoRow("Postage", String(format: "£%.2f", selectedDelivery.shippingFee))
                        if buyerProtectionEnabled {
                            infoRow(L10n.string("Buyer protection fee"), String(format: "£%.2f", buyerProtectionFee))
                        }
                        infoRow(L10n.string("Total"), String(format: "£%.2f", total), isBold: true)
                    }
                    .background(Theme.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.glassBorder, lineWidth: 0.5)
                    )

                    sectionHeader("Active Payment Method")
                    if let method = paymentMethod {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.primaryColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(method.cardBrand) •••• \(method.last4Digits)")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text(String(format: L10n.string("Card ending in %@"), method.last4Digits))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(Theme.Glass.cornerRadius)
                    } else if !isLoadingPaymentMethod {
                        Text(L10n.string("No payment method added"))
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .padding(Theme.Spacing.md)
                        NavigationLink(destination: AddPaymentCardView(onAdded: { Task { await loadPaymentMethod() } })) {
                            Text(L10n.string("Add payment method"))
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.primaryColor)
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 200)
            }
            .background(Theme.Colors.background)

            bottomBar
        }
        .navigationTitle(L10n.string("Payment"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .fullScreenCover(isPresented: $showPaymentSuccess) {
            PaymentSuccessfulView(productId: products.first?.productId) {
                showPaymentSuccess = false
                dismiss()
            }
        }
        .onAppear {
            Task {
                await loadUser()
                await loadPaymentMethod()
            }
        }
        .task(id: "multibuy-\(products.count)-\(commonSellerUserId ?? -1)") {
            guard products.count > 1, let sellerId = commonSellerUserId else {
                discountTiers = []
                return
            }
            userService.updateAuthToken(authService.authToken)
            do {
                discountTiers = try await userService.getMultibuyDiscounts(userId: sellerId)
            } catch {
                discountTiers = []
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.body)
            .fontWeight(.light)
            .foregroundColor(Theme.Colors.secondaryText)
            .padding(.top, Theme.Spacing.xs)
    }

    private func paymentRow(title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.Glass.cornerRadius)
    }

    private func deliveryOptionCard(_ option: DeliveryType) -> some View {
        let isSelected = selectedDelivery == option
        return Button {
            selectedDelivery = option
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: option.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? Theme.primaryColor : Theme.Colors.secondaryText)
                    Text(option.rawValue)
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? Theme.primaryColor : Theme.Colors.primaryText)
                }
                Text(String(format: "£%.2f", option.shippingFee))
                    .font(Theme.Typography.caption)
                    .foregroundColor(isSelected ? Theme.primaryColor : Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(isSelected ? Theme.primaryColor.opacity(0.1) : Theme.Colors.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.primaryColor : Theme.Colors.glassBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(HapticTapButtonStyle(haptic: { HapticManager.selection() }))
    }

    private func infoRow(_ label: String, _ value: String, valueColor: Color? = nil, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? Theme.Typography.body : Theme.Typography.body)
                .fontWeight(isBold ? .medium : .regular)
                .foregroundColor(Theme.Colors.primaryText)
            Spacer()
            Text(value)
                .font(Theme.Typography.body)
                .foregroundColor(valueColor ?? Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .overlay(ContentDivider(), alignment: .bottom)
    }

    private var bottomBar: some View {
        PrimaryButtonBar {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text(L10n.string("This is a secure encryption payment"))
                        .font(Theme.Typography.caption)
                        .fontWeight(.light)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                PrimaryGlassButton("Pay by card", icon: "creditcard", isLoading: isSubmitting, action: payByCard)
            }
        }
    }

    private func loadUser() async {
        do {
            currentUser = try await userService.getUser(username: nil)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func loadPaymentMethod() async {
        isLoadingPaymentMethod = true
        defer { isLoadingPaymentMethod = false }
        do {
            let method = try await userService.getUserPaymentMethod()
            await MainActor.run {
                paymentMethod = method
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func payByCard() {
        errorMessage = nil
        if currentUser?.shippingAddress == nil {
            errorMessage = "Please add a complete shipping address before payment. Go to Settings > Shipping Address."
            return
        }
        guard let method = paymentMethod else {
            errorMessage = "Add a payment method"
            return
        }
        guard let addr = currentUser?.shippingAddress else { return }
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            userService.updateAuthToken(authService.authToken)
            productService.updateAuthToken(authService.authToken)
            do {
                let phone = currentUser?.phoneDisplay ?? "0000000000"
                let deliveryDetails = CreateOrderDeliveryDetails.from(
                    shippingAddress: addr,
                    phoneNumber: phone,
                    deliveryProvider: "EVRI",
                    deliveryType: selectedDelivery == .collectionPoint ? "LOCAL_PICKUP" : "HOME_DELIVERY"
                )
                let productIds = products.compactMap { $0.productId }.compactMap { Int($0) }
                guard !productIds.isEmpty else {
                    await MainActor.run { errorMessage = "Invalid product" }
                    return
                }
                let orderResult: CreateOrderResult
                if productIds.count == 1 {
                    orderResult = try await productService.createOrder(
                        productId: productIds[0],
                        productIds: nil,
                        buyerProtection: buyerProtectionEnabled,
                        shippingFee: Float(selectedDelivery.shippingFee),
                        deliveryDetails: deliveryDetails
                    )
                } else {
                    orderResult = try await productService.createOrder(
                        productId: nil,
                        productIds: productIds,
                        buyerProtection: buyerProtectionEnabled,
                        shippingFee: Float(selectedDelivery.shippingFee),
                        deliveryDetails: deliveryDetails
                    )
                }
                guard let orderIdInt = Int(orderResult.orderId) else {
                    await MainActor.run { errorMessage = "Invalid order id" }
                    return
                }
                let (_, paymentRef) = try await userService.createPaymentIntent(orderId: orderIdInt, paymentMethodId: method.paymentMethodId)
                _ = try await userService.confirmPayment(paymentRef: paymentRef)
                await MainActor.run { showPaymentSuccess = true }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

#Preview {
    PaymentView(products: Item.sampleItems.prefix(1).map { $0 }, totalPrice: Item.sampleItems[0].price)
        .environmentObject(AuthService())
}
