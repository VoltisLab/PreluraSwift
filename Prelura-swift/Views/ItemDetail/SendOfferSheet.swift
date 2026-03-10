import SwiftUI

/// Modal sheet for sending an offer on a product. Uses Theme.primaryColor for accents.
struct SendOfferSheet: View {
    let item: Item
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var offerAmount: String = ""
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
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
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))

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
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
                        }

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(L10n.string("Message (optional)"))
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            TextField("Add a message to the seller...", text: $message, axis: .vertical)
                                .lineLimit(3...6)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
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
        isSubmitting = true
        // TODO: Call API to send offer (productId: item.productId, amount: value, message: message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isSubmitting = false
            dismiss()
            onDismiss()
        }
    }
}
