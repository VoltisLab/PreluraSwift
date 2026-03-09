import SwiftUI

/// Shop Value screen — reimagined with card-based layout; fetches userEarnings from API (matches Flutter).
struct ShopValueView: View {
    @EnvironmentObject var authService: AuthService
    var listingCount: Int = 0
    
    @State private var earnings: UserEarnings?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var userService: UserService {
        let s = UserService()
        if let token = authService.authToken { s.updateAuthToken(token) }
        return s
    }

    var body: some View {
        Group {
            if isLoading && earnings == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        heroCard
                        balanceCard
                        withdrawButton
                        earningsRow
                        footer
                    }
                    .padding(Theme.Spacing.md)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Shop Value")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadEarnings() }
        .onAppear { Task { await loadEarnings() } }
    }
    
    private func loadEarnings() async {
        isLoading = true
        errorMessage = nil
        do {
            let e = try await userService.getUserEarnings()
            await MainActor.run {
                self.earnings = e
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private var networth: Double { earnings?.networth ?? 0 }
    private var pendingPayments: Double { earnings?.pendingPayments.value ?? 0 }
    private var completedPayments: Double { earnings?.completedPayments.value ?? 0 }
    private var earningsThisMonth: Double { earnings?.earningsInMonth.value ?? 0 }
    private var totalEarnings: Double { earnings?.totalEarnings.value ?? 0 }
    private var transactionsCompleted: Int { earnings?.totalEarnings.quantity ?? 0 }

    // MARK: - Hero: current value + listings
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Current shop value")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(formatCurrency(networth))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                Text("\(listingCount) active listings")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    // MARK: - Balance: available + pending
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Balance")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Text("Pending \(formatCurrency(pendingPayments))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.primaryColor)
            }
            Text(formatCurrency(completedPayments))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private var withdrawButton: some View {
        Button(action: {}) {
            Text("Withdraw")
                .font(Theme.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Earnings: two cards
    private var earningsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            earningsCard(title: "This month", value: earningsThisMonth)
            earningsCard(title: "Total earnings", value: totalEarnings)
        }
    }

    private func earningsCard(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Text(formatCurrency(value))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.cornerRadius))
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("\(transactionsCompleted) transactions completed")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            Button(action: {}) {
                Text("Help")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.primaryColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func formatCurrency(_ value: Double) -> String {
        if value == floor(value) {
            return "£\(Int(value))"
        }
        return String(format: "£%.2f", value)
    }
}
