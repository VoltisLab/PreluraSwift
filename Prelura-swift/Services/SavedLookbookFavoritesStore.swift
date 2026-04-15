import Combine
import Foundation

/// A lookbook photo the user bookmarked from the feed (stored locally).
struct SavedLookbookPhoto: Codable, Identifiable, Equatable {
    let id: String
    var imageUrl: String
    var posterUsername: String
    var caption: String?
    let savedAt: Date
    /// Captured when saving from the main feed (older saves may be nil).
    var posterProfilePictureUrl: String?
    var styles: [String]?
    var likesCount: Int?
    var isLiked: Bool?
    var commentsCount: Int?
}

/// User-created folder for saved lookbook posts (local only).
struct LookbookSaveFolder: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let createdAt: Date
}

private struct LookbookFavoritesV2Payload: Codable {
    var folders: [LookbookSaveFolder]
    var photoById: [String: SavedLookbookPhoto]
    /// Folder id → ordered post ids (0 = most recently added in that folder).
    var folderPosts: [String: [String]]
}

@MainActor
final class SavedLookbookFavoritesStore: ObservableObject {
    static let shared = SavedLookbookFavoritesStore()

    @Published private(set) var folders: [LookbookSaveFolder] = []

    private var photoById: [String: SavedLookbookPhoto] = [:]
    private var folderPosts: [String: [String]] = [:]

    private let legacyStorageKey = "saved_lookbook_photo_favorites_v1"
    private let storageKey = "saved_lookbook_photo_favorites_v2"

    private init() {
        load()
    }

    /// Unique posts saved in any folder, newest first by `savedAt`.
    var photos: [SavedLookbookPhoto] {
        photoById.values.sorted { $0.savedAt > $1.savedAt }
    }

    func orderedPhotos(in folderId: String) -> [SavedLookbookPhoto] {
        let ids = folderPosts[folderId] ?? []
        return ids.compactMap { photoById[$0] }
    }

    func coverImageURL(for folderId: String) -> String? {
        guard let ids = folderPosts[folderId], let first = ids.first else { return nil }
        return photoById[first]?.imageUrl
    }

    func isSaved(postId: String) -> Bool {
        folderPosts.values.contains { $0.contains(postId) }
    }

    func folderIdsContaining(postId: String) -> [String] {
        folderPosts.compactMap { fid, ids in ids.contains(postId) ? fid : nil }
    }

    @discardableResult
    func ensureDefaultFolderIfEmpty(defaultName: String) -> LookbookSaveFolder? {
        if !folders.isEmpty { return nil }
        let f = LookbookSaveFolder(id: UUID().uuidString, name: defaultName, createdAt: Date())
        folders.append(f)
        folderPosts[f.id] = []
        persist()
        return f
    }

    @discardableResult
    func createFolder(name: String) -> LookbookSaveFolder? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let f = LookbookSaveFolder(id: UUID().uuidString, name: t, createdAt: Date())
        folders.append(f)
        folderPosts[f.id] = []
        persist()
        return f
    }

    func addPost(entry: LookbookEntry, imageUrl: String?, toFolder folderId: String) {
        guard folders.contains(where: { $0.id == folderId }) else { return }
        let pid = entry.apiPostId
        let url = (imageUrl ?? entry.imageUrls.first)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !url.isEmpty else { return }

        let photo: SavedLookbookPhoto = {
            if let existing = photoById[pid] {
                return SavedLookbookPhoto(
                    id: pid,
                    imageUrl: url,
                    posterUsername: entry.posterUsername,
                    caption: entry.caption,
                    savedAt: existing.savedAt,
                    posterProfilePictureUrl: entry.posterProfilePictureUrl,
                    styles: entry.styles,
                    likesCount: entry.likesCount,
                    isLiked: entry.isLiked,
                    commentsCount: entry.commentsCount
                )
            }
            return SavedLookbookPhoto(
                id: pid,
                imageUrl: url,
                posterUsername: entry.posterUsername,
                caption: entry.caption,
                savedAt: Date(),
                posterProfilePictureUrl: entry.posterProfilePictureUrl,
                styles: entry.styles,
                likesCount: entry.likesCount,
                isLiked: entry.isLiked,
                commentsCount: entry.commentsCount
            )
        }()
        photoById[pid] = photo

        var ids = folderPosts[folderId] ?? []
        ids.removeAll { $0 == pid }
        ids.insert(pid, at: 0)
        folderPosts[folderId] = ids
        persist()
    }

    func removePost(postId: String, fromFolder folderId: String) {
        guard var ids = folderPosts[folderId] else { return }
        ids.removeAll { $0 == postId }
        folderPosts[folderId] = ids
        if !folderPosts.values.contains(where: { $0.contains(postId) }) {
            photoById.removeValue(forKey: postId)
        }
        persist()
    }

    func removeFromAllFolders(postId: String) {
        for fid in Array(folderPosts.keys) {
            removePost(postId: postId, fromFolder: fid)
        }
    }

    func remove(id: String) {
        removeFromAllFolders(postId: id)
    }

    /// Keeps saved-folder captions in sync after the owner edits the post on the server.
    func updateCaptionForSavedPost(postId: String, caption: String?) {
        let norm = LookbookPostIdFormatting.graphQLUUIDString(from: postId).lowercased()
        guard !norm.isEmpty else { return }
        guard let key = photoById.keys.first(where: {
            LookbookPostIdFormatting.graphQLUUIDString(from: $0).lowercased() == norm
        }) else { return }
        var photo = photoById[key]!
        photo.caption = caption
        photoById[key] = photo
        persist()
    }

    /// Deletes folders by id, removes their post lists, and drops photos that are no longer referenced in any folder.
    @discardableResult
    func deleteFolders(withIds ids: [String]) -> Int {
        let idSet = Set(ids.filter { !$0.isEmpty })
        guard !idSet.isEmpty else { return 0 }
        folders.removeAll { idSet.contains($0.id) }
        for fid in idSet {
            let postsInFolder = folderPosts.removeValue(forKey: fid) ?? []
            for pid in postsInFolder {
                let stillReferenced = folderPosts.values.contains { $0.contains(pid) }
                if !stillReferenced {
                    photoById.removeValue(forKey: pid)
                }
            }
        }
        persist()
        return idSet.count
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(LookbookFavoritesV2Payload.self, from: data) {
            folders = decoded.folders
            photoById = decoded.photoById
            folderPosts = decoded.folderPosts
            return
        }
        if let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
           let legacy = try? JSONDecoder().decode([SavedLookbookPhoto].self, from: legacyData) {
            let folder = LookbookSaveFolder(id: UUID().uuidString, name: "Saved", createdAt: Date())
            folders = [folder]
            photoById = Dictionary(uniqueKeysWithValues: legacy.map { ($0.id, $0) })
            folderPosts = [folder.id: legacy.map(\.id)]
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            persist()
            return
        }
        folders = []
        photoById = [:]
        folderPosts = [:]
    }

    private func persist() {
        let payload = LookbookFavoritesV2Payload(folders: folders, photoById: photoById, folderPosts: folderPosts)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        objectWillChange.send()
    }
}
