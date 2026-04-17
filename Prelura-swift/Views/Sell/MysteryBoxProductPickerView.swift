import SwiftUI

/// Same product sources as lookbook `ProductSearchSheet`, with per-cell Add / Added chips and a try-cart style floating bar.
struct MysteryBoxProductPickerView: View {
    /// When re-opening from the compose form, pre-select these listings.
    var initialSelection: [Item]? = nil
    /// Called when opening a **new** picker (no initial selection) and the user is at the mystery cap.
    var onQuotaExceeded: (() -> Void)? = nil
    let onCancel: () -> Void
    let onContinue: ([Item]) -> Void

    @EnvironmentObject private var authService: AuthService
    private let productService = ProductService()
    @StateObject private var userService = UserService()

    @State private var query: String = ""
    @State private var myProducts: [Item] = []
    @State private var searchResults: [Item] = []
    @State private var loadingMyProducts = true
    @State private var searching = false
    /// Preserves selection order for the next step.
    @State private var selectedItems: [Item] = []

    private var isSearchMode: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// Mystery-box listings cannot be nested inside another mystery box.
    private var displayedItems: [Item] {
        let raw = isSearchMode ? searchResults : myProducts
        return raw.filter { !$0.isMysteryBox }
    }
    private var showEmptyState: Bool {
        if isSearchMode { return !searching && displayedItems.isEmpty }
        return !loadingMyProducts && displayedItems.isEmpty
    }

    private func isAdded(_ item: Item) -> Bool {
        guard let pid = item.productId else { return false }
        return selectedItems.contains { $0.productId == pid }
    }

    private func toggle(_ item: Item) {
        guard let pid = item.productId, !pid.isEmpty else { return }
        HapticManager.selection()
        if let idx = selectedItems.firstIndex(where: { $0.productId == pid }) {
            selectedItems.remove(at: idx)
        } else {
            selectedItems.append(item)
        }
    }

    private func continueWithSelectionTitle(count: Int) -> String {
        guard count > 0 else { return L10n.string("Continue") }
        if count == 1 { return L10n.string("Continue with one item") }
        return String(format: L10n.string("Continue with %d items"), count)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if showEmptyState {
                        emptyStatePlaceholder
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if loadingMyProducts && !isSearchMode && displayedItems.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            ProgressView()
                            Text(L10n.string("Loading your products…"))
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                if searching {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        ProgressView()
                                        Text(L10n.string("Searching…"))
                                            .font(.subheadline)
                                            .foregroundColor(Theme.Colors.secondaryText)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.top, Theme.Spacing.sm)
                                }
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                        GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                    ],
                                    spacing: Theme.Spacing.md
                                ) {
                                    ForEach(displayedItems) { item in
                                        Button {
                                            toggle(item)
                                        } label: {
                                            WardrobeItemCard(
                                                item: item,
                                                mysteryBoxAddChipMode: true,
                                                isMysteryBoxItemAdded: isAdded(item)
                                            )
                                        }
                                        .buttonStyle(PlainTappableButtonStyle())
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.top, Theme.Spacing.md)
                                .padding(.bottom, 120)
                            }
                        }
                    }
                }

                if !selectedItems.isEmpty {
                    VStack {
                        Spacer()
                        GlassEffectContainer(spacing: 0) {
                            Button {
                                HapticManager.tap()
                                onContinue(selectedItems)
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Spacer(minLength: 0)
                                    Image(systemName: "shippingbox.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(continueWithSelectionTitle(count: selectedItems.count))
                                        .font(Theme.Typography.headline)
                                        .multilineTextAlignment(.center)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.vertical, Theme.Spacing.md)
                                .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
                                .glassEffectTransition(.materialize)
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, 15)
                    }
                    .allowsHitTesting(true)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Add Items"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.string("Search products"))
            )
            .onSubmit(of: .search) {
                if isSearchMode { runSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel"), action: onCancel)
                }
            }
            .task {
                userService.updateAuthToken(authService.authToken)
                productService.updateAuthToken(authService.authToken)
                selectedItems = (initialSelection ?? []).filter { !$0.isMysteryBox }
                let isFreshPicker = (initialSelection ?? []).isEmpty
                if isFreshPicker {
                    let allowed = await SellerMysteryQuota.mysteryPickerEntryAllowed(authToken: authService.authToken)
                    if !allowed {
                        onQuotaExceeded?()
                        onCancel()
                        return
                    }
                }
                loadMyProducts()
            }
            .onChange(of: query) { _, newQuery in
                if newQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResults = []
                } else {
                    runSearch()
                }
            }
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(ProductSearchSheetNavigationBarHairlineHidden())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var emptyStatePlaceholder: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: isSearchMode ? "magnifyingglass" : "tag")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.Colors.secondaryText)
                Text(isSearchMode ? L10n.string("No products found") : L10n.string("You have no products listed yet"))
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                if isSearchMode {
                    Text(L10n.string("Try a different search term or tag from your list above"))
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadMyProducts() {
        loadingMyProducts = true
        Task {
            do {
                let username = authService.username
                let items = try await userService.getUserProducts(username: username)
                await MainActor.run {
                    myProducts = items
                    loadingMyProducts = false
                }
            } catch {
                await MainActor.run {
                    myProducts = []
                    loadingMyProducts = false
                }
            }
        }
    }

    private func runSearch() {
        guard isSearchMode else { return }
        searching = true
        Task {
            do {
                let items = try await productService.searchProducts(
                    query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                    pageCount: 20
                )
                await MainActor.run {
                    searchResults = items
                    searching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    searching = false
                }
            }
        }
    }
}
