//
//  LookbookView.swift
//  Prelura-swift
//
//  Instagram-style feed: full-width images, scrollable, poster, likes/comments (tappable), style filters.
//

import SwiftUI
import Shimmer

/// One lookbook post: image(s), poster, likes, comments, styles for filtering. Server-only (imageUrl) or legacy local (documentImagePath/imageNames).
/// Optional tags + productSnapshots come from local LookbookFeedStore (merged when post id/imageUrl matches).
struct LookbookEntry: Identifiable {
    let id: UUID
    let imageNames: [String]
    /// When set, first image is loaded from Documents (legacy local).
    let documentImagePath: String?
    /// When set, image is loaded from server URL.
    let imageUrl: String?
    let posterUsername: String
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
    let styles: [String]
    /// Tag positions (0–1) and productIds; from local store when available.
    let tags: [LookbookTagData]?
    /// productId -> snapshot for thumbnails; from local store when available.
    let productSnapshots: [String: LookbookProductSnapshot]?

    init(id: UUID? = nil, imageNames: [String], documentImagePath: String? = nil, imageUrl: String? = nil, posterUsername: String, likesCount: Int, commentsCount: Int, isLiked: Bool, styles: [String], tags: [LookbookTagData]? = nil, productSnapshots: [String: LookbookProductSnapshot]? = nil) {
        self.id = id ?? UUID()
        self.imageNames = imageNames
        self.documentImagePath = documentImagePath
        self.imageUrl = imageUrl
        self.posterUsername = posterUsername
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.isLiked = isLiked
        self.styles = styles
        self.tags = tags
        self.productSnapshots = productSnapshots
    }

    /// Entry from server (feed). Merges local tags/snapshots when record matches.
    init(from serverPost: ServerLookbookPost, localRecord: LookbookUploadRecord? = nil) {
        self.id = UUID(uuidString: serverPost.id) ?? UUID()
        self.imageNames = []
        self.documentImagePath = nil
        self.imageUrl = serverPost.imageUrl
        self.posterUsername = serverPost.username
        self.likesCount = serverPost.likesCount ?? 0
        self.commentsCount = serverPost.commentsCount ?? 0
        self.isLiked = serverPost.userLiked ?? false
        self.styles = localRecord?.styles ?? []
        self.tags = localRecord?.tags
        self.productSnapshots = localRecord?.productSnapshots
    }
}

private let lookbookSpacing: CGFloat = 12
private let lookbookTopId = "lookbook_top"

/// Style raw values for filter pills — same as StyleSelectionView (uploads). Subset used for display.
private let lookbookStylePillValues: [String] = [
    "CASUAL", "VINTAGE", "STREETWEAR", "MINIMALIST", "BOHO", "CHIC", "FORMAL_WEAR",
    "PARTY_DRESS", "LOUNGEWEAR", "ACTIVEWEAR", "Y2K", "DRESSES_GOWNS", "DENIM_JEANS",
    "SUMMER_STYLES", "WINTER_ESSENTIALS", "ATHLEISURE", "DATE_NIGHT", "VACATION_RESORT_WEAR"
]

private struct ProductIdNavigator: Identifiable, Hashable {
    let id: String
}

struct LookbookView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var entries: [LookbookEntry] = []
    @State private var feedLoading = false
    @State private var feedError: String?
    @State private var scrollPosition: String? = lookbookTopId
    @State private var selectedStylePills: Set<String> = []
    @State private var showSearchSheet: Bool = false
    @State private var searchText: String = ""
    @State private var commentsEntry: LookbookEntry?
    @State private var selectedProductId: ProductIdNavigator?
    private let productService = ProductService()

    private var filteredEntries: [LookbookEntry] {
        if selectedStylePills.isEmpty { return entries }
        return entries.filter { entry in
            !Set(entry.styles).isDisjoint(with: selectedStylePills)
        }
    }

    private var stylePillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(lookbookStylePillValues, id: \.self) { raw in
                    PillTag(
                        title: StyleSelectionView.displayName(for: raw),
                        isSelected: selectedStylePills.contains(raw)
                    ) {
                        if selectedStylePills.contains(raw) {
                            selectedStylePills.remove(raw)
                        } else {
                            selectedStylePills.insert(raw)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 1).id(lookbookTopId)
                    stylePillsRow
                if feedLoading && entries.isEmpty {
                    LookbookShimmerView()
                } else if filteredEntries.isEmpty {
                    emptyPlaceholder(minHeight: geometry.size.height - 120)
                } else {
                        ForEach(filteredEntries) { entry in
                            lookbookPostCard(entry: entry)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .scrollPosition(id: $scrollPosition, anchor: .top)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Lookbooks"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.sm) {
                    NavigationLink(destination: LookbooksUploadView()) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticTapButtonStyle())
                    Button(action: { showSearchSheet = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticTapButtonStyle())
                }
            }
        }
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry)
        }
        .sheet(isPresented: $showSearchSheet) {
            LookbookSearchSheet(searchText: $searchText, entries: filteredEntries)
        }
        .navigationDestination(item: $selectedProductId) { nav in
            LookbookProductDetailLoader(productId: nav.id, productService: productService, authService: authService)
        }
        .onAppear { loadFeedFromServer() }
        .refreshable { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServer() {
        Task { await loadFeedFromServerAsync() }
    }

    private func loadFeedFromServerAsync() async {
        guard authService.isAuthenticated else {
            entries = []
            return
        }
        await MainActor.run { feedLoading = true; feedError = nil }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        service.setAuthToken(authService.authToken)
        do {
            let posts = try await service.fetchLookbooks()
            let localRecords = LookbookFeedStore.load()
            await MainActor.run {
                entries = posts.map { post in
                    LookbookEntry(from: post, localRecord: localRecords.first { r in r.id == post.id || r.imagePath == post.imageUrl })
                }
                feedLoading = false
                feedError = nil
            }
        } catch {
            await MainActor.run {
                entries = []
                feedLoading = false
                // Don't show "cancelled" when pull-to-refresh is dismissed (task cancelled)
                let isCancelled = (error as? CancellationError) != nil
                    || (error as? URLError)?.code == .cancelled
                    || error.localizedDescription.lowercased().contains("cancelled")
                feedError = isCancelled ? nil : error.localizedDescription
            }
        }
    }

    private func emptyPlaceholder(minHeight: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            Text("No lookbooks yet")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            Text("Upload from the menu to add your first look.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            if let err = feedError, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: max(minHeight, 200))
    }

    private func lookbookPostCard(entry: LookbookEntry) -> some View {
        let entryId = entry.id
        return LookbookPostCard(
            entry: entry,
            onHeartTap: {
                guard let i = entries.firstIndex(where: { $0.id == entryId }) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    var e = entries[i]
                    e.isLiked.toggle()
                    e.likesCount += e.isLiked ? 1 : -1
                    entries[i] = e
                }
            },
            onImageDoubleTap: {
                guard let i = entries.firstIndex(where: { $0.id == entryId }), !entries[i].isLiked else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    var e = entries[i]
                    e.isLiked = true
                    e.likesCount += 1
                    entries[i] = e
                }
            },
            onCommentsTap: { commentsEntry = entry },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) }
        )
        .id(entry.id.uuidString)
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Feed image: double-tap to like, pinch zoom, bag icon to reveal tagged product thumbnails at pin positions.
private struct LookbookFeedImage: View {
    let imageName: String
    let documentImagePath: String?
    let imageUrl: String?
    let tags: [LookbookTagData]?
    let productSnapshots: [String: LookbookProductSnapshot]?
    let onDoubleTapLike: () -> Void
    let onProductTap: (String) -> Void

    @State private var scale: CGFloat = 1
    @State private var anchorScale: CGFloat = 1
    @State private var showTaggedProducts = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4
    private let bagSize: CGFloat = 44
    private let thumbSize: CGFloat = 56

    private var hasTaggedProducts: Bool {
        guard let tags = tags, let snapshots = productSnapshots, !tags.isEmpty else { return false }
        return tags.contains { snapshots[$0.productId] != nil }
    }

    private var imageView: some View {
        Group {
            if let urlString = imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(Theme.Colors.secondaryText)
                    default: ProgressView().frame(maxWidth: .infinity).frame(minHeight: 200)
                    }
                }
            } else if let path = documentImagePath,
               let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    var body: some View {
        imageView
            .scaleEffect(scale)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if hasTaggedProducts {
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTaggedProducts.toggle() } }) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: bagSize, height: bagSize)
                            .background(Theme.primaryColor.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Spacing.sm)
                }
            }
            .overlay {
                if showTaggedProducts, let tags = tags, let snapshots = productSnapshots {
                    GeometryReader { g in
                        ForEach(tags.filter { snapshots[$0.productId] != nil }) { tag in
                            if let snapshot = snapshots[tag.productId] {
                                let x = g.size.width * tag.x
                                let y = g.size.height * tag.y
                                productThumbnail(snapshot: snapshot, onTap: { onProductTap(tag.productId) })
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    .allowsHitTesting(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onDoubleTapLike)
            .highPriorityGesture(
                MagnificationGesture()
                    .onChanged { value in scale = anchorScale * value }
                    .onEnded { _ in
                        scale = min(max(scale, minScale), maxScale)
                        anchorScale = scale
                    }
            )
    }

    private func productThumbnail(snapshot: LookbookProductSnapshot, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Group {
                    if let urlString = snapshot.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color.gray.opacity(0.3)
                            }
                        }
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(snapshot.title)
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: thumbSize + 16)
            }
            .padding(6)
            .background(Theme.Colors.background.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading shimmer for Lookbooks feed (pills + post card placeholders)
private struct LookbookShimmerView: View {
    var body: some View {
        VStack(spacing: 0) {
            stylePillsShimmer
            ForEach(0..<3, id: \.self) { _ in
                LookbookPostCardShimmer()
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
        .shimmering()
    }

    private var stylePillsShimmer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.Glass.tagCornerRadius)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 72, height: 36)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
    }
}

private struct LookbookPostCardShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 36, height: 36)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 100, height: 14)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            RoundedRectangle(cornerRadius: 0)
                .fill(Theme.Colors.secondaryBackground)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)

            HStack(spacing: Theme.Spacing.lg) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 80, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 70, height: 16)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            Divider().background(Theme.Colors.glassBorder.opacity(0.5)).padding(.leading, Theme.Spacing.md)
        }
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Post card (poster, image with double-tap like + pinch-zoom, likes/comments row, bag for tagged products)
// Like state is held locally in the card (Flutter pattern: setState first, then notify parent) so tap always updates UI.
private struct LookbookPostCard: View {
    let entry: LookbookEntry
    let onHeartTap: () -> Void
    let onImageDoubleTap: () -> Void
    let onCommentsTap: () -> Void
    let onProductTap: (String) -> Void

    @State private var isLiked: Bool
    @State private var likesCount: Int

    init(entry: LookbookEntry, onHeartTap: @escaping () -> Void, onImageDoubleTap: @escaping () -> Void, onCommentsTap: @escaping () -> Void, onProductTap: @escaping (String) -> Void) {
        self.entry = entry
        self.onHeartTap = onHeartTap
        self.onImageDoubleTap = onImageDoubleTap
        self.onCommentsTap = onCommentsTap
        self.onProductTap = onProductTap
        _isLiked = State(initialValue: entry.isLiked)
        _likesCount = State(initialValue: entry.likesCount)
    }

    private let iconSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(entry.posterUsername.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.secondaryText)
                    )
                Text(entry.posterUsername)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            LookbookFeedImage(
                imageName: entry.imageNames.first ?? "",
                documentImagePath: entry.documentImagePath,
                imageUrl: entry.imageUrl,
                tags: entry.tags,
                productSnapshots: entry.productSnapshots,
                onDoubleTapLike: {
                if !isLiked {
                    isLiked = true
                    likesCount += 1
                }
                onImageDoubleTap()
            },
                onProductTap: onProductTap
            )
                .frame(maxWidth: .infinity)

            HStack(spacing: Theme.Spacing.lg) {
                Button(action: {
                    isLiked.toggle()
                    likesCount += isLiked ? 1 : -1
                    if likesCount < 0 { likesCount = 0 }
                    onHeartTap()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: iconSize))
                            .foregroundColor(isLiked ? Theme.primaryColor : Theme.Colors.primaryText)
                        Text("\(likesCount)")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Likes")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(action: onCommentsTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: iconSize))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("\(entry.commentsCount)")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Comments")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()
                .background(Theme.Colors.glassBorder.opacity(0.5))
                .padding(.leading, Theme.Spacing.md)
        }
        .onChange(of: entry.isLiked) { _, new in isLiked = new }
        .onChange(of: entry.likesCount) { _, new in likesCount = new }
    }
}

// MARK: - Loads product by id and presents ItemDetailView (for tagged product tap from lookbook feed)
private struct LookbookProductDetailLoader: View {
    let productId: String
    let productService: ProductService
    let authService: AuthService
    @State private var item: Item?
    @State private var failed = false

    var body: some View {
        Group {
            if let item = item {
                ItemDetailView(item: item, authService: authService)
            } else if failed {
                ContentUnavailableView("Product unavailable", systemImage: "bag", description: Text("This item may have been removed."))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let id = Int(productId) else { failed = true; return }
            do {
                let loaded = try await productService.getProduct(id: id)
                await MainActor.run { item = loaded; if loaded == nil { failed = true } }
            } catch {
                await MainActor.run { failed = true }
            }
        }
    }
}

// MARK: - Comments sheet (mock)
struct LookbookCommentsSheet: View {
    let entry: LookbookEntry
    @Environment(\.dismiss) private var dismiss

    private static let mockComments: [(author: String, text: String)] = [
        ("stylefan", "Love this look!"),
        ("thriftlover", "Where is the top from?"),
        ("preloved_em", "So good 🔥"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(Self.mockComments.enumerated()), id: \.offset) { _, c in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(Theme.Colors.secondaryBackground)
                                .frame(width: 32, height: 32)
                                .overlay(Text(String(c.author.prefix(1)).uppercased())
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.secondaryText))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.author)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text(c.text)
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
                .padding(.vertical, Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Comments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
    }
}

// MARK: - Thumbnail for search / list (server URL, document image, or asset)
private struct LookbookEntryThumbnail: View {
    let entry: LookbookEntry
    var body: some View {
        Group {
            if let urlString = entry.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: Image(systemName: "photo").resizable().scaledToFit().foregroundStyle(Theme.Colors.secondaryText)
                    default: ProgressView()
                    }
                }
            } else if let path = entry.documentImagePath,
               let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let first = entry.imageNames.first {
                Image(first)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }
}

// MARK: - Search sheet (filter by search text in username/caption)
struct LookbookSearchSheet: View {
    @Binding var searchText: String
    let entries: [LookbookEntry]
    @Environment(\.dismiss) private var dismiss

    private var filteredBySearch: [LookbookEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return entries }
        return entries.filter { $0.posterUsername.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.secondaryText)
                    TextField(L10n.string("Search lookbooks"), text: $searchText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .autocorrectionDisabled()
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.secondaryBackground)
                .cornerRadius(10)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredBySearch) { entry in
                            HStack(spacing: Theme.Spacing.sm) {
                                LookbookEntryThumbnail(entry: entry)
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .cornerRadius(8)
                                Text(entry.posterUsername)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(L10n.string("Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Done")) { dismiss() }
                        .foregroundColor(Theme.primaryColor)
                }
            }
        }
    }
}

extension LookbookEntry: Equatable {
    static func == (lhs: LookbookEntry, rhs: LookbookEntry) -> Bool { lhs.id == rhs.id }
}

extension LookbookEntry: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#if DEBUG
struct LookbookView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LookbookView()
                .environmentObject(AuthService())
        }
    }
}
#endif
