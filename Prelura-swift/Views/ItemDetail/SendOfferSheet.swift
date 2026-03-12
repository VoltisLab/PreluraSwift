import SwiftUI

/// Modal sheet for sending an offer on a product. Uses Theme.primaryColor for accents. Calls createOffer API.
struct SendOfferSheet: View {
    let item: Item
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    private let productService = ProductService()

    @State private var offerAmount: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @FocusState private var offerFieldFocused: Bool

    private var offerValue: Double? {
        let cleaned = offerAmount.replacingOccurrences(of: "£", with: "").trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private var canSubmit: Bool {
        guard let value = offerValue, value > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        HStack(spacing: Theme.Spacing.md) {
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
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text(item.formattedPrice)
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.primaryColor)
                            }
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 30))

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Your offer")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("£")
                                    .font(Theme.Typography.title2)
                                    .foregroundColor(Theme.primaryColor)
                                TextField("0", text: $offerAmount)
                                    .keyboardType(.decimalPad)
                                    .font(Theme.Typography.title2)
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .focused($offerFieldFocused)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .background(Theme.Colors.background)

                PrimaryButtonBar {
                    PrimaryGlassButton("Send offer", icon: "paperplane.fill", isLoading: isSubmitting, action: submitOffer)
                        .disabled(!canSubmit)
                }
            }
            .navigationTitle(L10n.string("Send an offer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .foregroundColor(Theme.primaryColor)
                    .buttonStyle(HapticTapButtonStyle())
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(Theme.primaryColor)
        }
        .onAppear {
            offerAmount = item.price == floor(item.price) ? "\(Int(item.price))" : String(format: "%.2f", item.price)
            offerFieldFocused = true
        }
    }

    private func submitOffer() {
        guard canSubmit, let value = offerValue else { return }
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
                _ = try await productService.createOffer(offerPrice: value, productIds: [productId], message: nil)
                await MainActor.run {
                    dismiss()
                    onDismiss()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
