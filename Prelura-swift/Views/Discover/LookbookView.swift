//
//  LookbookView.swift
//  Prelura-swift
//
//  Instagram-style feed: full-width images, scrollable, poster, likes/comments (tappable), style filters.
//

import SwiftUI
import Shimmer
import UIKit

/// One lookbook post: image(s), poster, likes, comments, styles for filtering. Remote URLs in `imageUrls` (carousel), or legacy document/asset.
/// Optional tags + productSnapshots come from local LookbookFeedStore (merged when post id / URL matches).
struct LookbookEntry: Identifiable {
    let id: UUID
    let imageNames: [String]
    /// When set, first image is loaded from Documents (legacy local).
    let documentImagePath: String?
    /// Remote slide URLs (single or multiple for in-post carousel). Empty when using document/assets only.
    let imageUrls: [String]
    /// First remote URL, if any.
    var imageUrl: String? { imageUrls.first }
    let posterUsername: String
    let caption: String?
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
    let styles: [String]
    /// Tag positions (0–1) and productIds; from local store when available.
    let tags: [LookbookTagData]?
    /// productId -> snapshot for thumbnails; from local store when available.
    let productSnapshots: [String: LookbookProductSnapshot]?

    init(id: UUID? = nil, imageNames: [String], documentImagePath: String? = nil, imageUrl: String? = nil, posterUsername: String, caption: String? = nil, likesCount: Int, commentsCount: Int, isLiked: Bool, styles: [String], tags: [LookbookTagData]? = nil, productSnapshots: [String: LookbookProductSnapshot]? = nil) {
        self.id = id ?? UUID()
        self.imageNames = imageNames
        self.documentImagePath = documentImagePath
        if let u = imageUrl, !u.isEmpty {
            self.imageUrls = [u]
        } else {
            self.imageUrls = []
        }
        self.posterUsername = posterUsername
        self.caption = caption
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.isLiked = isLiked
        self.styles = styles
        self.tags = tags
        self.productSnapshots = productSnapshots
    }

    /// Entry from server (feed). Merges local multi-image URLs and tags when record matches.
    init(from serverPost: ServerLookbookPost, localRecord: LookbookUploadRecord? = nil) {
        self.id = UUID(uuidString: serverPost.id) ?? UUID()
        self.imageNames = []
        self.documentImagePath = nil
        let serverTrim = serverPost.imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromServer: [String] = serverTrim.isEmpty ? [] : [serverTrim]
        if let local = localRecord {
            let localUrls = dedupeOrderedValidLookbookURLs(local.allImageUrls)
            if localUrls.count > 1 {
                self.imageUrls = localUrls
            } else {
                self.imageUrls = fromServer.isEmpty ? localUrls : fromServer
            }
        } else {
            self.imageUrls = fromServer
        }
        self.posterUsername = serverPost.username
        self.caption = serverPost.caption
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

/// Ordered de-duplication so accidental duplicate URLs do not spawn a multi-page `TabView` with collapsed height.
private func dedupeOrderedValidLookbookURLs(_ urls: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for u in urls {
        let t = u.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, URL(string: t) != nil else { continue }
        if seen.insert(t).inserted { out.append(t) }
    }
    return out
}

// MARK: - Canonical media frames (1080×1350, 1080×1080, 1920×1080)

/// Width ÷ height for each canonical lookbook crop; closest bucket is chosen from the loaded image’s pixel aspect ratio.
private enum LookbookCanonicalAspect: CGFloat, CaseIterable {
    case portrait1080x1350 = 0.8 // 1080/1350
    case square1080 = 1
    case landscape1920x1080 = 1.7777777777777777 // 1920/1080

    static func bucket(for imageWidthOverHeight: CGFloat) -> Self {
        allCases.min(by: { abs($0.rawValue - imageWidthOverHeight) < abs($1.rawValue - imageWidthOverHeight) })!
    }
}

// MARK: - One feed row per post

private struct LookbookFeedRowModel: Identifiable {
    let id: String
    let entry: LookbookEntry
}

private func buildLookbookFeedRows(from list: [LookbookEntry]) -> [LookbookFeedRowModel] {
    list.enumerated().map { i, entry in
        LookbookFeedRowModel(id: "\(i)-\(entry.id.uuidString)", entry: entry)
    }
}

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
    @State private var fullScreenEntry: LookbookEntry?
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
                        ForEach(buildLookbookFeedRows(from: filteredEntries)) { row in
                            lookbookFeedRow(model: row)
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
            LookbookCommentsSheet(entry: entry) { newCount in
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    var updated = entries[idx]
                    updated.commentsCount = newCount
                    entries[idx] = updated
                }
            }
        }
        .fullScreenCover(item: $fullScreenEntry) { entry in
            LookbookFullscreenViewer(entry: entry)
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
            await MainActor.run {
                entries = []
                feedLoading = false
                feedError = nil
            }
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
                feedLoading = false
                let isCancelled = (error as? CancellationError) != nil
                    || (error as? URLError)?.code == .cancelled
                    || error.localizedDescription.lowercased().contains("cancelled")
                feedError = isCancelled ? nil : error.localizedDescription
                // Keep existing feed on refresh failure so the list doesn’t go blank.
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

    private func lookbookFeedRow(model: LookbookFeedRowModel) -> some View {
        LookbookFeedRowView(
            entry: model.entry,
            onHeartTap: { entry in
                let entryId = entry.id
                guard let i = entries.firstIndex(where: { $0.id == entryId }) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    var e = entries[i]
                    e.isLiked.toggle()
                    e.likesCount += e.isLiked ? 1 : -1
                    entries[i] = e
                }
                Task { await syncLookbookLike(postId: entryId.uuidString) }
            },
            onImageDoubleTap: { entry in
                let entryId = entry.id
                guard let i = entries.firstIndex(where: { $0.id == entryId }), !entries[i].isLiked else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    var e = entries[i]
                    e.isLiked = true
                    e.likesCount += 1
                    entries[i] = e
                }
                Task { await syncLookbookLike(postId: entryId.uuidString) }
            },
            onCommentsTap: { entry in commentsEntry = entry },
            onImageTap: { entry in fullScreenEntry = entry },
            onProductTap: { productId in selectedProductId = ProductIdNavigator(id: productId) }
        )
        .id(model.id)
        .padding(.bottom, lookbookSpacing)
    }

    private func syncLookbookLike(postId: String) async {
        do {
            let client = GraphQLClient()
            client.setAuthToken(authService.authToken)
            let service = LookbookService(client: client)
            let result = try await service.toggleLike(postId: postId)
            await MainActor.run {
                guard let uuid = UUID(uuidString: postId),
                      let idx = entries.firstIndex(where: { $0.id == uuid }) else { return }
                var entry = entries[idx]
                entry.isLiked = result.liked
                entry.likesCount = result.likesCount
                entries[idx] = entry
            }
        } catch {
            await MainActor.run {
                guard let uuid = UUID(uuidString: postId),
                      let idx = entries.firstIndex(where: { $0.id == uuid }) else { return }
                var entry = entries[idx]
                entry.isLiked.toggle()
                entry.likesCount += entry.isLiked ? 1 : -1
                entries[idx] = entry
            }
        }
    }
}

// MARK: - Feed image: canonical aspect bucket, fill frame, double-tap like, pinch zoom, bag for tagged products.
private struct LookbookFeedImage: View {
    let imageName: String
    let documentImagePath: String?
    let imageUrl: String?
    let tags: [LookbookTagData]?
    let productSnapshots: [String: LookbookProductSnapshot]?
    /// When false, tagged pins are hidden (e.g. secondary carousel slides).
    let showTagOverlay: Bool
    let onDoubleTapLike: () -> Void
    let onTap: () -> Void
    let onProductTap: (String) -> Void

    @State private var scale: CGFloat = 1
    @State private var anchorScale: CGFloat = 1
    @State private var dragOffset: CGSize = .zero
    @State private var anchorDragOffset: CGSize = .zero
    @State private var showTaggedProducts = false
    @State private var bucket: LookbookCanonicalAspect = .square1080
    @State private var remoteImage: UIImage?
    @State private var remoteLoading = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4
    private let bagSize: CGFloat = 44
    private let thumbSize: CGFloat = 56

    private var hasTaggedProducts: Bool {
        guard showTagOverlay, let tags = tags, let snapshots = productSnapshots, !tags.isEmpty else { return false }
        return tags.contains { snapshots[$0.productId] != nil }
    }

    private var localUIImage: UIImage? {
        if let path = documentImagePath,
           let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) { return ui }
        if !imageName.isEmpty, let ui = UIImage(named: imageName) { return ui }
        return nil
    }

    private var filledImageLayer: some View {
        Group {
            if let ui = localUIImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else if let ui = remoteImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else if imageUrl != nil, let _ = URL(string: imageUrl!) {
                if remoteLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.secondaryBackground.opacity(0.5))
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(48)
                }
            } else if !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(48)
            }
        }
    }

    var body: some View {
        filledImageLayer
            .scaleEffect(scale)
            .offset(dragOffset)
            .frame(maxWidth: .infinity)
            .aspectRatio(bucket.rawValue, contentMode: .fit)
            .clipped()
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
                    .buttonStyle(PlainTappableButtonStyle())
                    .padding(Theme.Spacing.sm)
                }
            }
            .overlay {
                if showTaggedProducts, showTagOverlay, let tags = tags, let snapshots = productSnapshots {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture(count: 2, perform: onDoubleTapLike)
            .onTapGesture(perform: onTap)
            .highPriorityGesture(
                MagnificationGesture()
                    .onChanged { value in scale = anchorScale * value }
                    .onEnded { _ in
                        scale = min(max(scale, minScale), maxScale)
                        anchorScale = scale
                        if scale <= 1.01 {
                            dragOffset = .zero
                            anchorDragOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard scale > 1.01 else { return }
                        dragOffset = CGSize(
                            width: anchorDragOffset.width + value.translation.width,
                            height: anchorDragOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard scale > 1.01 else { return }
                        anchorDragOffset = dragOffset
                    }
            )
            .onAppear(perform: syncBucketFromLocalIfPossible)
            .task(id: imageUrl) { await loadRemoteIfNeeded() }
    }

    private func syncBucketFromLocalIfPossible() {
        if let ui = localUIImage {
            bucket = LookbookCanonicalAspect.bucket(for: ui.size.width / max(ui.size.height, 1))
        }
    }

    private func loadRemoteIfNeeded() async {
        guard let urlString = imageUrl, let url = URL(string: urlString) else {
            await MainActor.run {
                remoteImage = nil
                remoteLoading = false
            }
            return
        }
        if localUIImage != nil { return }
        await MainActor.run { remoteLoading = true }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let ui = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            let b = LookbookCanonicalAspect.bucket(for: ui.size.width / max(ui.size.height, 1))
            await MainActor.run {
                remoteImage = ui
                bucket = b
                remoteLoading = false
            }
        } catch {
            await MainActor.run {
                remoteImage = nil
                remoteLoading = false
            }
        }
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
        .buttonStyle(PlainTappableButtonStyle())
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

// MARK: - Feed row: one post; multiple images in a page TabView (carousel).
private struct LookbookFeedRowView: View {
    let entry: LookbookEntry
    let onHeartTap: (LookbookEntry) -> Void
    let onImageDoubleTap: (LookbookEntry) -> Void
    let onCommentsTap: (LookbookEntry) -> Void
    let onImageTap: (LookbookEntry) -> Void
    let onProductTap: (String) -> Void

    @State private var carouselIndex: Int = 0

    private let iconSize: CGFloat = 18

    private func detailLine(for entry: LookbookEntry) -> String {
        if let first = entry.styles.first, !first.isEmpty {
            return "\(StyleSelectionView.displayName(for: first)) fit"
        }
        return "New fit"
    }

    /// Stable height for the media slot: `TabView` + async image load otherwise collapsed to a few points in `LazyVStack`.
    private var mediaBlock: some View {
        let urls = entry.imageUrls
        return Color.clear
            .aspectRatio(LookbookCanonicalAspect.portrait1080x1350.rawValue, contentMode: .fit)
            .overlay {
                mediaOverlayInner(urls: urls)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func mediaOverlayInner(urls: [String]) -> some View {
        if urls.count > 1 {
            TabView(selection: $carouselIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                    LookbookFeedImage(
                        imageName: entry.imageNames.first ?? "",
                        documentImagePath: idx == 0 ? entry.documentImagePath : nil,
                        imageUrl: url,
                        tags: entry.tags,
                        productSnapshots: entry.productSnapshots,
                        showTagOverlay: idx == 0,
                        onDoubleTapLike: { onImageDoubleTap(entry) },
                        onTap: { onImageTap(entry) },
                        onProductTap: onProductTap
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        } else {
            LookbookFeedImage(
                imageName: entry.imageNames.first ?? "",
                documentImagePath: entry.documentImagePath,
                imageUrl: urls.first,
                tags: entry.tags,
                productSnapshots: entry.productSnapshots,
                showTagOverlay: true,
                onDoubleTapLike: { onImageDoubleTap(entry) },
                onTap: { onImageTap(entry) },
                onProductTap: onProductTap
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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
            .padding(.top, Theme.Spacing.sm)

            Text("📍 \(detailLine(for: entry))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)
                .padding(.horizontal, Theme.Spacing.md)

            if let caption = entry.caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HashtagColoredText(text: caption)
                    .padding(.horizontal, Theme.Spacing.md)
            }

            mediaBlock
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, Theme.Spacing.md)

            HStack(spacing: Theme.Spacing.lg) {
                Button(action: { onHeartTap(entry) }) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: iconSize))
                            .foregroundColor(entry.isLiked ? Theme.primaryColor : Theme.Colors.primaryText)
                        Text("\(entry.likesCount)")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Likes")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainTappableButtonStyle())
                Button(action: { onCommentsTap(entry) }) {
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
                .buttonStyle(PlainTappableButtonStyle())
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)

            Rectangle()
                .fill(Theme.Colors.glassBorder.opacity(0.45))
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.md)
        }
        .onChange(of: entry.imageUrls.count) { _, newCount in
            if carouselIndex >= newCount { carouselIndex = max(0, newCount - 1) }
        }
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

// MARK: - Comments sheet
struct LookbookCommentsSheet: View {
    let entry: LookbookEntry
    var onCountChanged: ((Int) -> Void)? = nil
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ServerLookbookComment] = []
    @State private var draft: String = ""
    @State private var loading = false
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading {
                    ProgressView().padding(.top, Theme.Spacing.lg)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(comments) { c in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(Theme.Colors.secondaryBackground)
                                    .frame(width: 32, height: 32)
                                    .overlay(Text(String(c.username.prefix(1)).uppercased())
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.secondaryText))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.username)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.Colors.primaryText)
                                    HashtagColoredText(text: c.text)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Add a comment", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    Button(sending ? "..." : "Send") {
                        sendComment()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                    .foregroundColor(Theme.primaryColor)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
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
            .task { await loadComments() }
        }
    }

    private func loadComments() async {
        loading = true
        defer { loading = false }
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        if let loaded = try? await service.fetchComments(postId: entry.id.uuidString) {
            comments = loaded
            onCountChanged?(loaded.count)
        }
    }

    private func sendComment() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        let client = GraphQLClient()
        client.setAuthToken(authService.authToken)
        let service = LookbookService(client: client)
        Task {
            do {
                let result = try await service.addComment(postId: entry.id.uuidString, text: text)
                await MainActor.run {
                    draft = ""
                    comments.append(result.comment)
                    onCountChanged?(result.commentsCount)
                    sending = false
                }
            } catch {
                await MainActor.run { sending = false }
            }
        }
    }
}

// MARK: - Thumbnail for search / list (server URL, document image, or asset)
private struct LookbookEntryThumbnail: View {
    let entry: LookbookEntry
    var body: some View {
        Group {
            if let urlString = entry.imageUrls.first, let url = URL(string: urlString) {
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

private struct HashtagColoredText: View {
    let text: String

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let pattern = "#\\w+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if let range = Range(match.range, in: result) {
                result[range].foregroundColor = Theme.primaryColor
                result[range].font = Theme.Typography.subheadline.weight(.semibold)
            }
        }
        return result
    }

    var body: some View {
        Text(attributed)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.primaryText)
            .lineLimit(nil)
    }
}

private struct LookbookFullscreenViewer: View {
    let entry: LookbookEntry
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(entry.imageUrls.enumerated()), id: \.offset) { idx, url in
                    LookbookFullscreenImage(documentImagePath: idx == 0 ? entry.documentImagePath : nil, imageName: entry.imageNames.first ?? "", imageUrl: url)
                        .tag(idx)
                }
                if entry.imageUrls.isEmpty {
                    LookbookFullscreenImage(documentImagePath: entry.documentImagePath, imageName: entry.imageNames.first ?? "", imageUrl: nil)
                        .tag(0)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 10)
            .padding(.trailing, 12)
            .buttonStyle(.plain)
        }
    }
}

private struct LookbookFullscreenImage: View {
    let documentImagePath: String?
    let imageName: String
    let imageUrl: String?

    @State private var scale: CGFloat = 1
    @State private var anchorScale: CGFloat = 1
    @State private var dragOffset: CGSize = .zero
    @State private var anchorDragOffset: CGSize = .zero

    private var localUIImage: UIImage? {
        if let path = documentImagePath,
           let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: path),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) { return ui }
        if !imageName.isEmpty, let ui = UIImage(named: imageName) { return ui }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if let ui = localUIImage {
                    Image(uiImage: ui).resizable().scaledToFit()
                } else if let s = imageUrl, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        case .empty: ProgressView().tint(.white)
                        default:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white.opacity(0.7))
                                .padding(80)
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white.opacity(0.7))
                        .padding(80)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(scale)
            .offset(dragOffset)
            .contentShape(Rectangle())
            .highPriorityGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1, anchorScale * value)
                    }
                    .onEnded { _ in
                        scale = min(max(scale, 1), 6)
                        anchorScale = scale
                        if scale <= 1.01 {
                            dragOffset = .zero
                            anchorDragOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard scale > 1.01 else { return }
                        dragOffset = CGSize(
                            width: anchorDragOffset.width + value.translation.width,
                            height: anchorDragOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        guard scale > 1.01 else { return }
                        anchorDragOffset = dragOffset
                    }
            )
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
