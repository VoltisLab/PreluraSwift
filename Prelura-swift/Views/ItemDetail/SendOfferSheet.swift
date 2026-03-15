import SwiftUI

// MARK: - Sheet content (used inside OptionsSheet for same styling as Sort/Filter)

/// Send-offer content for OptionsSheet. Matches Flutter: product info, -5/-10/-15% chips, price input, Clear + Send Offer. Styling matches SortSheetContent (dividers, glass buttons).
struct SendOfferSheetContent: View {
    let item: Item
    var onDismiss: () -> Void

    @EnvironmentObject var authService: AuthService
    @Environment(\.optionalTabCoordinator) private var tabCoordinator
    private let productService = ProductService()

    @State private var offerAmount: String = ""
    @State private var selectedSuggestionPrice: Double? = nil
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @FocusState private var offerFieldFocused: Bool

    private var maxPrice: Double { item.price }
    private var fivePercent: Double { maxPrice * 0.95 }
    private var tenPercent: Double { maxPrice * 0.90 }
    private var fifteenPercent: Double { maxPrice * 0.85 }

    private var offerValue: Double? {
        let cleaned = offerAmount.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private var canSubmit: Bool {
        guard let value = offerValue, value > 0 else { return false }
        if value < maxPrice * 0.6 { return false }
        return true
    }

    private var optionDivider: some View {
        Rectangle()
            .fill(Theme.Colors.glassBorder)
            .frame(height: 0.5)
            .padding(.horizontal, Theme.Spacing.md)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product info row
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                if let url = item.imageURLs.first, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Theme.Colors.secondaryBackground)
                        }
                    }
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    if let size = item.size, !size.isEmpty {
                        Text("Size \(size)")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    Spacer(minLength: 4)
                    priceRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            optionDivider

            // Suggestion chips (-5%, -10%, -15%)
            HStack(spacing: 8) {
                suggestionChip(price: fivePercent, discount: "-5%")
                suggestionChip(price: tenPercent, discount: "-10%")
                suggestionChip(price: fifteenPercent, discount: "-15%")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            optionDivider

            // Your offer input
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(L10n.string("Your offer"))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                HStack(spacing: Theme.Spacing.sm) {
                    Text("£")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.primaryColor)
                    TextField("0", text: $offerAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: offerAmount) { _, newValue in
                            let sanitized = PriceFieldFilter.sanitizePriceInput(newValue)
                            if sanitized != newValue { offerAmount = sanitized }
                        }
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                        .focused($offerFieldFocused)
                        .onChange(of: offerAmount) { _, _ in
                            errorMessage = nil
                            if let v = offerValue, v != selectedSuggestionPrice { selectedSuggestionPrice = nil }
                        }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            if let err = errorMessage {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xs)
            }
            optionDivider

            // Clear + Send Offer (same pattern as Sort: BorderGlassButton + PrimaryGlassButton)
            VStack(spacing: Theme.Spacing.sm) {
                BorderGlassButton(L10n.string("Clear")) {
                    offerAmount = ""
                    selectedSuggestionPrice = nil
                    errorMessage = nil
                }
                PrimaryGlassButton(L10n.string("Send offer"), icon: "paperplane.fill", isLoading: isSubmitting, action: submitOffer)
                    .disabled(!canSubmit)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.background)
        .onAppear {
            let initial = item.price == floor(item.price) ? "\(Int(item.price))" : String(format: "%.2f", item.price)
            offerAmount = initial
            offerFieldFocused = true
        }
    }

    private var priceRow: some View {
        HStack(spacing: 4) {
            if item.originalPrice != nil, item.originalPrice! > item.price {
                Text(item.formattedOriginalPrice)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .strikethrough()
                Text(item.formattedPrice)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
            } else {
                Text(item.formattedPrice)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.primaryColor)
            }
        }
    }

    private func suggestionChip(price: Double, discount: String) -> some View {
        let isSelected = selectedSuggestionPrice == price
        let priceStr = price == floor(price) ? "\(Int(price))" : String(format: "%.2f", price)
        return Button(action: {
            HapticManager.selection()
            offerAmount = price == floor(price) ? "\(Int(price))" : String(format: "%.2f", price)
            selectedSuggestionPrice = price
            errorMessage = nil
        }) {
            HStack(spacing: 6) {
                Text("£\(priceStr)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(discount)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Theme.primaryColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? Theme.primaryColor : Theme.Colors.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func submitOffer() {
        guard let value = offerValue, value > 0 else { return }
        if value < maxPrice * 0.6 {
            errorMessage = "Offer too low. Try again."
            return
        }
        guard let productIdStr = item.productId, let productId = Int(productIdStr) else {
            errorMessage = "Product ID missing"
            return
        }
        errorMessage = nil
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            productService.updateAuthToken(authService.authToken)
            do {
                let (_, conversation) = try await productService.createOffer(offerPrice: value, productIds: [productId], message: nil)
                await MainActor.run {
                    onDismiss()
                    if let conv = conversation, let tc = tabCoordinator {
                        tc.selectTab(3)
                        tc.pendingOpenConversation = conv
                    }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
