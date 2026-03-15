//
//  LookbookView.swift
//  Prelura-swift
//
//  Instagram-style feed: full-width images, scrollable, poster, likes/comments (tappable), style filters.
//

import SwiftUI

/// One lookbook post: image(s), poster, likes, comments, styles for filtering.
struct LookbookEntry: Identifiable {
    let id = UUID()
    let imageNames: [String]
    let posterUsername: String
    var likesCount: Int
    var commentsCount: Int
    var isLiked: Bool
    /// Style raw values (e.g. "CASUAL", "VINTAGE") for filter pills; matches upload Style enum.
    let styles: [String]
}

private let lookbookSpacing: CGFloat = 12
private let lookbookTopId = "lookbook_top"

/// Style raw values for filter pills — same as StyleSelectionView (uploads). Subset used for display.
private let lookbookStylePillValues: [String] = [
    "CASUAL", "VINTAGE", "STREETWEAR", "MINIMALIST", "BOHO", "CHIC", "FORMAL_WEAR",
    "PARTY_DRESS", "LOUNGEWEAR", "ACTIVEWEAR", "Y2K", "DRESSES_GOWNS", "DENIM_JEANS",
    "SUMMER_STYLES", "WINTER_ESSENTIALS", "ATHLEISURE", "DATE_NIGHT", "VACATION_RESORT_WEAR"
]

/// Static lookbook content with mock poster, engagement, and styles.
private func makeLookbookEntries() -> [LookbookEntry] {
    [
        LookbookEntry(imageNames: ["LookbookGrid1"], posterUsername: "stylebyjade", likesCount: 234, commentsCount: 12, isLiked: false, styles: ["CASUAL", "MINIMALIST"]),
        LookbookEntry(imageNames: ["LookbookGrid2", "LookbookGrid3"], posterUsername: "preloved_em", likesCount: 89, commentsCount: 5, isLiked: false, styles: ["VINTAGE", "BOHO"]),
        LookbookEntry(imageNames: ["LookbookGrid4"], posterUsername: "thriftqueen", likesCount: 412, commentsCount: 28, isLiked: false, styles: ["STREETWEAR", "Y2K"]),
        LookbookEntry(imageNames: ["LookbookGrid5", "LookbookGrid6"], posterUsername: "vintagevibes_", likesCount: 156, commentsCount: 9, isLiked: false, styles: ["VINTAGE", "FORMAL_WEAR"]),
        LookbookEntry(imageNames: ["LookbookGrid7"], posterUsername: "secondhandstories", likesCount: 67, commentsCount: 3, isLiked: false, styles: ["LOUNGEWEAR", "CASUAL"]),
        LookbookEntry(imageNames: ["LookbookGrid8"], posterUsername: "curatedbykate", likesCount: 521, commentsCount: 41, isLiked: false, styles: ["CHIC", "DRESSES_GOWNS"]),
        LookbookEntry(imageNames: ["LookbookGrid1", "LookbookGrid2"], posterUsername: "slowfashion_uk", likesCount: 198, commentsCount: 14, isLiked: false, styles: ["SUMMER_STYLES", "BOHO"]),
        LookbookEntry(imageNames: ["LookbookGrid3"], posterUsername: "rewearcollective", likesCount: 73, commentsCount: 6, isLiked: false, styles: ["MINIMALIST", "DENIM_JEANS"]),
        LookbookEntry(imageNames: ["LookbookGrid4", "LookbookGrid5", "LookbookGrid6"], posterUsername: "prelura_faves", likesCount: 302, commentsCount: 22, isLiked: false, styles: ["PARTY_DRESS", "DATE_NIGHT"]),
        LookbookEntry(imageNames: ["LookbookGrid7"], posterUsername: "stylebyjade", likesCount: 145, commentsCount: 8, isLiked: false, styles: ["ACTIVEWEAR", "ATHLEISURE"]),
        LookbookEntry(imageNames: ["LookbookGrid8"], posterUsername: "thriftqueen", likesCount: 267, commentsCount: 19, isLiked: false, styles: ["WINTER_ESSENTIALS", "CHIC"]),
        LookbookEntry(imageNames: ["LookbookGrid1"], posterUsername: "vintagevibes_", likesCount: 94, commentsCount: 4, isLiked: false, styles: ["VACATION_RESORT_WEAR", "SUMMER_STYLES"]),
    ]
}

struct LookbookView: View {
    @State private var entries: [LookbookEntry] = makeLookbookEntries()
    @State private var scrollPosition: String? = lookbookTopId
    @State private var selectedStylePills: Set<String> = []
    @State private var showSearchSheet: Bool = false
    @State private var searchText: String = ""
    @State private var commentsEntry: LookbookEntry?

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
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 1).id(lookbookTopId)
                stylePillsRow
                ForEach(filteredEntries) { entry in
                    lookbookPostCard(entry: entry)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollPosition(id: $scrollPosition, anchor: .top)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Lookbooks"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSearchSheet = true }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: Theme.AppBar.buttonSize, height: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticTapButtonStyle())
            }
        }
        .sheet(item: $commentsEntry) { entry in
            LookbookCommentsSheet(entry: entry)
        }
        .sheet(isPresented: $showSearchSheet) {
            LookbookSearchSheet(searchText: $searchText, entries: filteredEntries)
        }
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
            onCommentsTap: { commentsEntry = entry }
        )
        .id(entry.id.uuidString)
        .padding(.bottom, lookbookSpacing)
    }
}

// MARK: - Feed image: double-tap to like, pinch with 2 fingers to zoom
private struct LookbookFeedImage: View {
    let imageName: String
    let onDoubleTapLike: () -> Void
    @State private var scale: CGFloat = 1
    @State private var anchorScale: CGFloat = 1

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onDoubleTapLike)
            .highPriorityGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = anchorScale * value
                    }
                    .onEnded { _ in
                        scale = min(max(scale, minScale), maxScale)
                        anchorScale = scale
                    }
            )
    }
}

// MARK: - Post card (poster, image with double-tap like + pinch-zoom, likes/comments row)
// Like state is held locally in the card (Flutter pattern: setState first, then notify parent) so tap always updates UI.
private struct LookbookPostCard: View {
    let entry: LookbookEntry
    let onHeartTap: () -> Void
    let onImageDoubleTap: () -> Void
    let onCommentsTap: () -> Void

    @State private var isLiked: Bool
    @State private var likesCount: Int

    init(entry: LookbookEntry, onHeartTap: @escaping () -> Void, onImageDoubleTap: @escaping () -> Void, onCommentsTap: @escaping () -> Void) {
        self.entry = entry
        self.onHeartTap = onHeartTap
        self.onImageDoubleTap = onImageDoubleTap
        self.onCommentsTap = onCommentsTap
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

            LookbookFeedImage(imageName: entry.imageNames[0], onDoubleTapLike: onImageDoubleTap)
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
                                Image(entry.imageNames[0])
                                    .resizable()
                                    .scaledToFill()
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
        }
    }
}
#endif
