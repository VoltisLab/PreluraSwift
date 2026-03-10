import SwiftUI

/// Payment settings: fetch active payment method, show card or empty state, Add Card / Add Bank, Delete.
struct PaymentSettingsView: View {
    @State private var paymentMethod: PaymentMethod?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false

    private let userService = UserService()

    var body: some View {
        Group {
            if isLoading && paymentMethod == nil && errorMessage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: Text(L10n.string("Active Payment method"))) {
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
                            .padding(.vertical, Theme.Spacing.xs)
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                            .tint(Theme.Colors.error)
                                    } else {
                                        Text(L10n.string("Delete"))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isDeleting)
                        } else {
                            Text(L10n.string("No payment method added"))
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                    Section {
                        NavigationLink(destination: AddPaymentCardView(onAdded: { Task { await load() } })) {
                            Label("Add Payment Card", systemImage: "creditcard")
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        NavigationLink(destination: AddBankAccountView()) {
                            Label("Add Bank Account", systemImage: "building.columns")
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                    }
                    if let err = errorMessage {
                        Section {
                            Text(err)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Payments"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("Remove payment method?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let method = paymentMethod {
                    Task { await deletePaymentMethod(method.paymentMethodId) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(L10n.string("This card will be removed from your account."))
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            paymentMethod = try await userService.getUserPaymentMethod()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePaymentMethod(_ id: String) async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await userService.deletePaymentMethod(paymentMethodId: id)
            paymentMethod = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
