import SwiftUI

/// Favourites: liked products (default) and Lookbook photos saved from the feed. Matches Flutter MyFavouriteScreen + local photo bookmarks.
struct MyFavouritesView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var shopAllBag: ShopAllBagStore
    @EnvironmentObject private var savedLookbookFavorites: SavedLookbookFavoritesStore
    /// When true, opened from Shop All (e.g. Try Cart rules already apply from that flow).
    var fromShopAll: Bool = false
    /// When true, only saved Lookbook folders (no product favourites tab or product API load).
    var lookbookOnly: Bool = false
    @State private var shopAllBagToolbarActive = false
    @State private var favouritesSegment: Int = 0
    @State private var searchText: String = ""
    @State private var items: [Item] = []
    @State private var totalNumber: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    @State private var lookbookFolderSelectionMode = false
    @State private var selectedLookbookFolderIds: Set<String> = []
    @State private var confirmDeleteSelectedFolders = false

    private let productService = ProductService()
    private let pageCount = 20

    private var productGridColumns: [GridItem] {
        WearhouseLayoutMetrics.productGridColumns(
            horizontalSizeClass: horizontalSizeClass,
            spacing: Theme.Spacing.sm
        )
    }

    /// Folder tiles per row (2 on phone; 3–4 on iPad / Mac).
    private var lookbookFolderGridColumns: [GridItem] {
        WearhouseLayoutMetrics.productGridColumns(
            horizontalSizeClass: horizontalSizeClass,
            spacing: Theme.Spacing.md
        )
    }

    private var isProductsTab: Bool { !lookbookOnly && favouritesSegment == 0 }

    private var filteredItems: [Item] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter { $0.title.lowercased().contains(q) }
    }

    private var filteredLookbookFolders: [LookbookSaveFolder] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = savedLookbookFavorites.folders.sorted { $0.createdAt > $1.createdAt }
        if q.isEmpty { return sorted }
        return sorted.filter { folder in
            if folder.name.lowercased().contains(q) { return true }
            return savedLookbookFavorites.orderedPhotos(in: folder.id).contains {
                $0.posterUsername.lowercased().contains(q) || ($0.caption ?? "").lowercased().contains(q)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !lookbookOnly {
                Picker("", selection: $favouritesSegment) {
                    Text(L10n.string("Products")).tag(0)
                    Text(L10n.string("Lookbook")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xs)
            }

            if isProductsTab {
                productsTabContent
            } else {
                photosTabContent
            }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(L10n.string("Favourites"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(isProductsTab ? L10n.string("Search favourites") : L10n.string("Search lookbook folders"))
        )
        .toolbar {
            if isProductsTab {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shopAllBagToolbarActive.toggle()
                    } label: {
                        Image(systemName: shopAllBagToolbarActive ? "bag.fill" : "bag")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(shopAllBagToolbarActive ? Theme.primaryColor : Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainTappableButtonStyle())
                    .accessibilityLabel("Toggle shopping bag mode")
                }
            } else if !filteredLookbookFolders.isEmpty {
                if lookbookFolderSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.string("Done")) {
                            lookbookFolderSelectionMode = false
                            selectedLookbookFolderIds.removeAll()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.string("Delete")) {
                            confirmDeleteSelectedFolders = true
                        }
                        .disabled(selectedLookbookFolderIds.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.string("Select")) {
                            lookbookFolderSelectionMode = true
                            selectedLookbookFolderIds.removeAll()
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isProductsTab && shopAllBagToolbarActive {
                favouritesTryCartFloatingBar
            }
        }
        .refreshable {
            if !lookbookOnly && isProductsTab {
                await load(resetPage: true)
            }
        }
        .task {
            if !lookbookOnly {
                await load(resetPage: true)
            }
        }
        .onAppear {
            savedLookbookFavorites.reloadFromPersistence()
        }
        .onChange(of: favouritesSegment) { _, newValue in
            guard !lookbookOnly else { return }
            if newValue == 0 {
                lookbookFolderSelectionMode = false
                selectedLookbookFolderIds.removeAll()
            }
        }
        .confirmationDialog(
            L10n.string("Delete selected folders?"),
            isPresented: $confirmDeleteSelectedFolders,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Delete"), role: .destructive) {
                let ids = Array(selectedLookbookFolderIds)
                _ = savedLookbookFavorites.deleteFolders(withIds: ids)
                lookbookFolderSelectionMode = false
                selectedLookbookFolderIds.removeAll()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This will delete the selected folders and every look saved inside them. This can't be undone."))
        }
    }

    @ViewBuilder
    private var productsTabContent: some View {
        if let err = errorMessage {
            Text(err)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.error)
                .padding(.horizontal)
        }

        if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if items.isEmpty {
            Spacer()
            VStack(spacing: Theme.Spacing.md) {
                Text(L10n.string("No favourites yet"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(L10n.string("Items you save as favourites will appear here."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            Spacer()
        } else if filteredItems.isEmpty {
            Spacer()
            Text(String(format: L10n.string("No results for \"%@\""), searchText))
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(
                    columns: productGridColumns,
                    alignment: .leading,
                    spacing: Theme.Spacing.md,
                    pinnedViews: []
                ) {
                    ForEach(filteredItems) { item in
                        favouritesProductCell(item: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.bottom, shopAllBagToolbarActive ? 88 : Theme.Spacing.lg)

                if isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    @ViewBuilder
    private var photosTabContent: some View {
        if filteredLookbookFolders.isEmpty {
            Spacer()
            VStack(spacing: Theme.Spacing.md) {
                Text(L10n.string("No lookbook folders yet"))
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(L10n.string("Save looks from the feed - you can organise them into folders."))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.xl)
            Spacer()
        } else {
            ScrollView {
                LazyVGrid(columns: lookbookFolderGridColumns, alignment: .leading, spacing: Theme.Spacing.md, pinnedViews: []) {
                    ForEach(filteredLookbookFolders) { folder in
                        if lookbookFolderSelectionMode {
                            Button {
                                HapticManager.selection()
                                if selectedLookbookFolderIds.contains(folder.id) {
                                    selectedLookbookFolderIds.remove(folder.id)
                                } else {
                                    selectedLookbookFolderIds.insert(folder.id)
                                }
                            } label: {
                                lookbookFolderGridCell(folder, isSelected: selectedLookbookFolderIds.contains(folder.id))
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        } else {
                            NavigationLink(
                                destination: SavedLookbookFavoritesFeedView(folderId: folder.id, initialPhotoId: nil)
                                    .environmentObject(authService)
                                    .environmentObject(savedLookbookFavorites)
                            ) {
                                lookbookFolderGridCell(folder, isSelected: false)
                            }
                            .buttonStyle(PlainTappableButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    /// Same grid cell structure as `HomeView.homeProductCore`: stable `.id(item.id)` avoids `LazyVGrid` recycling glitches; like control sits above the image like Home.
    @ViewBuilder
    private func favouritesProductCell(item: Item) -> some View {
        let inBag = shopAllBag.items.contains(where: { $0.id == item.id })
        ZStack(alignment: .topLeading) {
            NavigationLink(destination: ItemDetailView(
                item: item,
                authService: authService,
                offersAllowed: !(fromShopAll || shopAllBagToolbarActive),
                shopAllBag: shopAllBagToolbarActive ? shopAllBag : nil,
                activateShopBagActionsInitially: shopAllBagToolbarActive
            )) {
                HomeItemCard(
                    item: item,
                    onLikeTap: nil,
                    hideLikeButton: true,
                    showAddToBag: shopAllBagToolbarActive,
                    onAddToBag: shopAllBagToolbarActive
                        ? {
                            if !shopAllBag.items.contains(where: { $0.id == item.id }) {
                                shopAllBag.add(item)
                            }
                        }
                        : nil,
                    isInBag: inBag,
                    onRemove: shopAllBagToolbarActive
                        ? { shopAllBag.remove(item) }
                        : nil
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .buttonStyle(PlainTappableButtonStyle())
            VStack(spacing: 0) {
                Color.clear.frame(height: 28)
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                        LikeButtonView(isLiked: item.isLiked, likeCount: item.likeCount, action: {
                            unfavourite(item)
                        })
                        .padding(Theme.Spacing.xs)
                    }
                }
                .aspectRatio(1.0 / 1.3, contentMode: .fit)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .id(item.id)
        .onAppear {
            if item.id == filteredItems.last?.id {
                loadMoreIfNeeded()
            }
        }
    }

    private func lookbookFolderGridCell(_ folder: LookbookSaveFolder, isSelected: Bool) -> some View {
        let cover = savedLookbookFavorites.coverImageURL(for: folder.id)
        return VStack(alignment: .center, spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let cover, let url = URL(string: cover), !cover.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            case .failure, .empty:
                                folderPlaceholder
                            @unknown default:
                                folderPlaceholder
                            }
                        }
                    } else {
                        folderPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Glass.bannerSurfaceCornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Theme.primaryColor : Color.clear, lineWidth: 3)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white, Theme.primaryColor)
                        .padding(8)
                }
            }

            Text(folder.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var folderPlaceholder: some View {
        ZStack {
            Theme.Colors.secondaryBackground
            Image(systemName: "bookmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    /// Same as Shop All Try Cart: tap opens `ShopAllBagView` → Checkout → `PaymentView`.
    private var favouritesTryCartFloatingBar: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GlassEffectContainer(spacing: 0) {
                    NavigationLink(destination: ShopAllBagView(store: shopAllBag).environmentObject(authService)) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L10n.string("Shopping bag"))
                                .font(Theme.Typography.headline)
                            Spacer(minLength: 0)
                            Text(shopAllBag.formattedTotal)
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

    private func load(resetPage: Bool) async {
        productService.updateAuthToken(authService.authToken)
        if resetPage {
            currentPage = 1
            items = []
        }
        if currentPage == 1 { isLoading = true }
        errorMessage = nil
        defer {
            if currentPage == 1 { isLoading = false }
        }
        do {
            let (newItems, total) = try await productService.getLikedProducts(pageNumber: currentPage, pageCount: pageCount)
            if currentPage == 1 {
                items = newItems
            } else {
                let ids = Set(items.map { $0.id })
                items += newItems.filter { !ids.contains($0.id) }
            }
            totalNumber = total
        } catch {
            errorMessage = L10n.userFacingError(error)
        }
    }

    private func loadMoreIfNeeded() {
        guard !isLoadingMore, items.count < totalNumber else { return }
        Task {
            isLoadingMore = true
            currentPage += 1
            await load(resetPage: false)
            isLoadingMore = false
        }
    }

    private func unfavourite(_ item: Item) {
        guard let productId = item.productId, !productId.isEmpty else { return }
        items.removeAll { $0.id == item.id }
        Task {
            do {
                _ = try await productService.toggleLike(productId: productId, isLiked: false)
            } catch {
                await MainActor.run {
                    items.append(item)
                }
            }
        }
    }
}

// MARK: - Saved Lookbook folder feed (grid / list switcher)

private struct SavedLookbookFavoritesFeedView: View {
    let folderId: String
    var initialPhotoId: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var savedLookbookFavorites: SavedLookbookFavoritesStore
    @State private var useGrid = false
    @State private var pendingScrollId: String?
    @State private var feedEntries: [LookbookEntry] = []
    @State private var followedCommentBoostUsernames: Set<String> = []
    @State private var commentsEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    @State private var hashtagNavigationSelection: LookbookHashtagSelection?
    @State private var likersPostId: String?
    @State private var removeConfirmPostId: String?
    @State private var isSaveSelectionMode = false
    @State private var selectedSaveIds: Set<String> = []
    @State private var confirmBulkRemoveSaves = false

    private let lookbookListRowBottomPadding: CGFloat = 16
    private let gridGutter: CGFloat = 2

    private var photos: [SavedLookbookPhoto] {
        savedLookbookFavorites.orderedPhotos(in: folderId)
    }

    /// When this changes (add/remove/reorder), rebuild rows from the store; avoids wiping in-memory like counts on unrelated store updates.
    private var folderPhotoIdsSignature: String {
        photos.map(\.id).joined(separator: "\u{1E}")
    }

    private var folderDisplayName: String {
        savedLookbookFavorites.folders.first { $0.id == folderId }?.name ?? ""
    }

    private var gridColumns: [GridItem] {
        WearhouseLayoutMetrics.lookbookFeedGridColumns(horizontalSizeClass: horizontalSizeClass)
    }

    private let productService = ProductService()

    var body: some View {
        Group {
            if photos.isEmpty {
                ContentUnavailableView(
                    L10n.string("No saves in this folder"),
                    systemImage: "bookmark",
                    description: Text(L10n.string("Save looks from the feed into this folder."))
                )
            } else if useGrid {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: gridGutter, pinnedViews: []) {
                        ForEach(photos) { photo in
                            gridThumbSelectable(photo)
                        }
                    }
                    .padding(2)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LookbookScrollImmediateTouchesAnchor()
                            .frame(width: 0, height: 0)
                        LazyVStack(spacing: 0) {
                            ForEach(buildLookbookFeedRows(from: feedEntries)) { model in
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    if isSaveSelectionMode {
                                        Image(systemName: selectedSaveIds.contains(model.entry.apiPostId) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundStyle(
                                                selectedSaveIds.contains(model.entry.apiPostId) ? Theme.primaryColor : Theme.Colors.secondaryText
                                            )
                                            .padding(.leading, Theme.Spacing.sm)
                                            .padding(.top, Theme.Spacing.lg)
                                    }
                                    LookbookFeedRowView(
                                        entry: model.entry,
                                        followedCommentBoostUsernames: followedCommentBoostUsernames,
                                        onCommentsTap: { commentsEntry = $0 },
                                        onProductTap: { selectedProductId = ProductIdNavigator(id: $0) },
                                        onPostDeleted: nil,
                                        onOpenAnalytics: nil,
                                        onLikeTap: { tapped in
                                            handleLookbookFeedLikeTap(tapped, authService: authService, entries: $feedEntries)
                                        },
                                        onRemoveFromFolder: isSaveSelectionMode
                                            ? nil
                                            : {
                                                removeConfirmPostId = model.entry.apiPostId
                                            },
                                        onPostCaptionUpdated: { updated in
                                            let k = updated.lookbookPostKey
                                            if let idx = feedEntries.firstIndex(where: { $0.lookbookPostKey == k }) {
                                                feedEntries[idx] = updated
                                            }
                                        },
                                        feedEntriesForHashtag: feedEntries,
                                        onHashtagNavigate: { hashtagNavigationSelection = $0 },
                                        onLikesListTap: { likersPostId = $0.apiPostId }
                                    )
                                    .allowsHitTesting(!isSaveSelectionMode)
                                    .padding(.bottom, lookbookListRowBottomPadding)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard isSaveSelectionMode else { return }
                                    HapticManager.selection()
                                    let id = model.entry.apiPostId
                                    if selectedSaveIds.contains(id) {
                                        selectedSaveIds.remove(id)
                                    } else {
                                        selectedSaveIds.insert(id)
                                    }
                                }
                                .id(model.entry.apiPostId)
                            }
                        }
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        let target = initialPhotoId ?? pendingScrollId
                        guard let id = target else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                        pendingScrollId = nil
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(folderDisplayName.isEmpty ? L10n.string("Lookbook") : folderDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !photos.isEmpty {
                if isSaveSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.string("Done")) {
                            isSaveSelectionMode = false
                            selectedSaveIds.removeAll()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.string("Delete")) {
                            confirmBulkRemoveSaves = true
                        }
                        .disabled(selectedSaveIds.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            HapticManager.selection()
                            useGrid.toggle()
                        } label: {
                            Image(systemName: useGrid ? "list.bullet" : "square.grid.3x3")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.Colors.primaryText)
                        }
                        .accessibilityLabel(useGrid ? L10n.string("List view") : L10n.string("Grid view"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.string("Select")) {
                            isSaveSelectionMode = true
                            selectedSaveIds.removeAll()
                        }
                    }
                }
            }
        }
        .onAppear {
            productService.updateAuthToken(authService.authToken)
            reloadFeedEntriesFromStore()
        }
        .onChange(of: folderId) { _, _ in reloadFeedEntriesFromStore() }
        .onChange(of: folderPhotoIdsSignature) { _, _ in reloadFeedEntriesFromStore() }
        .task {
            let client = GraphQLClient()
            client.setAuthToken(authService.authToken)
            followedCommentBoostUsernames = await lookbookLoadFollowedUsernamesForFeedComments(
                authService: authService,
                graphQLClient: client
            )
        }
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry, feedEntriesForHashtag: feedEntries) { newCount in
                let key = entry.apiPostId.lowercased()
                if let idx = feedEntries.firstIndex(where: { $0.apiPostId.lowercased() == key }) {
                    var updated = feedEntries[idx]
                    updated.commentsCount = newCount
                    feedEntries[idx] = updated
                }
            }
            .lookbookCommentsPresentationChrome()
        }
        .navigationDestination(item: $selectedProductId) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .navigationDestination(item: $hashtagNavigationSelection) { sel in
            LookbookHashtagFeedResultsView(
                selection: sel,
                matchingEntries: lookbookEntriesMatchingHashtagKey(entries: feedEntries, key: sel.key)
            )
            .environmentObject(authService)
            .environmentObject(savedLookbookFavorites)
        }
        .navigationDestination(item: $likersPostId) { postId in
            LookbookPostLikersView(postId: postId)
                .environmentObject(authService)
        }
        .confirmationDialog(
            L10n.string("Remove from this folder?"),
            isPresented: Binding(
                get: { removeConfirmPostId != nil },
                set: { if !$0 { removeConfirmPostId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.string("Remove"), role: .destructive) {
                if let id = removeConfirmPostId {
                    savedLookbookFavorites.removePost(postId: id, fromFolder: folderId)
                }
                removeConfirmPostId = nil
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This look will be removed from this folder only."))
        }
        .confirmationDialog(
            L10n.string("Remove selected looks?"),
            isPresented: $confirmBulkRemoveSaves,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Remove"), role: .destructive) {
                let ids = Array(selectedSaveIds)
                for pid in ids {
                    savedLookbookFavorites.removePost(postId: pid, fromFolder: folderId)
                }
                isSaveSelectionMode = false
                selectedSaveIds.removeAll()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("These looks will be removed from this folder only."))
        }
    }

    private func reloadFeedEntriesFromStore() {
        feedEntries = savedLookbookFavorites.orderedPhotos(in: folderId).map { $0.asLookbookEntryForFeed() }
    }

    @ViewBuilder
    private func gridThumb(_ photo: SavedLookbookPhoto) -> some View {
        Group {
            if let url = URL(string: photo.imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Theme.Colors.secondaryBackground)
                    }
                }
            } else {
                Rectangle().fill(Theme.Colors.secondaryBackground)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .contentShape(Rectangle())
    }

    private func gridThumbSelectable(_ photo: SavedLookbookPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            gridThumb(photo)
                .overlay {
                    if isSaveSelectionMode {
                        RoundedRectangle(cornerRadius: 0)
                            .strokeBorder(selectedSaveIds.contains(photo.id) ? Theme.primaryColor : Color.clear, lineWidth: 3)
                    }
                }
            if isSaveSelectionMode {
                Image(systemName: selectedSaveIds.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white, Theme.primaryColor)
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSaveSelectionMode {
                HapticManager.selection()
                if selectedSaveIds.contains(photo.id) {
                    selectedSaveIds.remove(photo.id)
                } else {
                    selectedSaveIds.insert(photo.id)
                }
            } else {
                HapticManager.tap()
                pendingScrollId = photo.id
                useGrid = false
            }
        }
    }
}

// MARK: - Save lookbook post to folder(s) from feed

struct LookbookSaveToFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SavedLookbookFavoritesStore
    let entry: LookbookEntry
    let imageUrl: String?
    var onFinish: (_ newlyAddedFolderNames: [String]) -> Void

    @State private var selectedIds: Set<String> = []
    @State private var initialIds: Set<String> = []
    @State private var showNewFolderSheet = false
    @State private var newFolderDraft = ""
    @State private var didEmitFinish = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { folder in
                        Button {
                            toggle(folder.id)
                        } label: {
                            HStack {
                                Text(folder.name)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                Spacer()
                                Image(systemName: selectedIds.contains(folder.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIds.contains(folder.id) ? Theme.primaryColor : Theme.Colors.secondaryText)
                            }
                        }
                    }
                } footer: {
                    Text(L10n.string("You can add the same look to more than one folder."))
                        .font(Theme.Typography.caption)
                }
            }
            .navigationTitle(L10n.string("Save to folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) {
                        emitFinishIfNeeded()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.string("New folder")) {
                        newFolderDraft = ""
                        showNewFolderSheet = true
                    }
                }
            }
            .onAppear {
                store.ensureDefaultFolderIfEmpty(defaultName: L10n.string("My saves"))
                let s = Set(store.folderIdsContaining(postId: entry.apiPostId))
                selectedIds = s
                initialIds = s
            }
            .onDisappear {
                emitFinishIfNeeded()
            }
            .sheet(isPresented: $showNewFolderSheet) {
                NavigationStack {
                    Form {
                        TextField(L10n.string("Folder name"), text: $newFolderDraft)
                    }
                    .navigationTitle(L10n.string("New folder"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.string("Cancel")) { showNewFolderSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("Create")) {
                                if let f = store.createFolder(name: newFolderDraft) {
                                    store.addPost(entry: entry, imageUrl: imageUrl, toFolder: f.id)
                                    selectedIds.insert(f.id)
                                    HapticManager.tap()
                                }
                                newFolderDraft = ""
                                showNewFolderSheet = false
                            }
                            .disabled(newFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .wearhouseSheetContentColumnIfWide()
            }
        }
    }

    private func toggle(_ folderId: String) {
        if selectedIds.contains(folderId) {
            selectedIds.remove(folderId)
            store.removePost(postId: entry.apiPostId, fromFolder: folderId)
        } else {
            selectedIds.insert(folderId)
            store.addPost(entry: entry, imageUrl: imageUrl, toFolder: folderId)
        }
        HapticManager.tap()
    }

    private func emitFinishIfNeeded() {
        guard !didEmitFinish else { return }
        didEmitFinish = true
        let added = selectedIds.subtracting(initialIds)
        let names = store.folders.filter { added.contains($0.id) }.map(\.name).sorted()
        onFinish(names)
    }
}