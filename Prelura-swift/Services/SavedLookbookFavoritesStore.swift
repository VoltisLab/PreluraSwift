import Combine
import Foundation

/// A lookbook photo the user bookmarked from the feed (stored locally; syncs across Favourites → Photos).
struct SavedLookbookPhoto: Codable, Identifiable, Equatable {
    let id: String
    var imageUrl: String
    var posterUsername: String
    var caption: String?
    let savedAt: Date
}

@MainActor
final class SavedLookbookFavoritesStore: ObservableObject {
    static let shared = SavedLookbookFavoritesStore()

    @Published private(set) var photos: [SavedLookbookPhoto] = []

    private let storageKey = "saved_lookbook_photo_favorites_v1"

    private init() {
        load()
    }

    func isSaved(postId: String) -> Bool {
        photos.contains { $0.id == postId }
    }

    /// Adds or removes the photo for this post; returns whether it is saved after the action.
    @discardableResult
    func toggle(entry: LookbookEntry, imageUrl: String?) -> Bool {
        let id = entry.id.uuidString
        let url = (imageUrl ?? entry.imageUrls.first)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !url.isEmpty else { return isSaved(postId: id) }
        if let idx = photos.firstIndex(where: { $0.id == id }) {
            photos.remove(at: idx)
            persist()
            return false
        }
        let photo = SavedLookbookPhoto(
            id: id,
            imageUrl: url,
            posterUsername: entry.posterUsername,
            caption: entry.caption,
            savedAt: Date()
        )
        photos.insert(photo, at: 0)
        persist()
        return true
    }

    func remove(id: String) {
        photos.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            photos = []
            return
        }
        do {
            photos = try JSONDecoder().decode([SavedLookbookPhoto].self, from: data)
        } catch {
            photos = []
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(photos) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
