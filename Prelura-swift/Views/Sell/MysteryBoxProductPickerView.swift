import SwiftUI

/// Same product sources as lookbook `ProductSearchSheet`, with per-cell Add / Added chips and a try-cart style floating bar.
struct MysteryBoxProductPickerView: View {
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
    private var displayedItems: [Item] { isSearchMode ? searchResults : myProducts }
    private var showEmptyState: Bool {
        if isSearchMode { return !searching && searchResults.isEmpty }
        return !loadingMyProducts && myProducts.isEmpty
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
                        HStack {
                            Spacer()
                            GlassEffectContainer(spacing: 0) {
                                Button {
                                    HapticManager.tap()
                                    onContinue(selectedItems)
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Image(systemName: "shippingbox.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(L10n.string("Continue"))
                                            .font(Theme.Typography.headline)
                                        Spacer(minLength: 0)
                                        Text("\(selectedItems.count)")
                                            .font(Theme.Typography.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Theme.Spacing.lg)
                                    .padding(.vertical, Theme.Spacing.md)
                                    .glassEffect(.clear.tint(Theme.primaryColor), in: .rect(cornerRadius: 30))
                                    .glassEffectTransition(.materialize)
                                }
                                .buttonStyle(PlainTappableButtonStyle())
                            }
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, 15)
                    }
                    .allowsHitTesting(true)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Tag product"))
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
            .onAppear {
                userService.updateAuthToken(authService.authToken)
                productService.updateAuthToken(authService.authToken)
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
