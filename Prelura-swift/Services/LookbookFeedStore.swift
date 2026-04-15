//
//  LookbookFeedStore.swift
//  Prelura-swift
//
//  Shared store for lookbook uploads that appear in the Discover feed.
//

import Foundation

enum LookbookFeedStore {
    private static let defaults = UserDefaults.standard
    private static let feedKey = "lookbook_feed_records"

    /// Append an uploaded record to the feed (called from LookbooksUploadView after successful upload).
    static func append(_ record: LookbookUploadRecord) {
        var list = load()
        list.append(record)
        save(list)
    }

    /// Updates caption on a stored upload record when it matches `postId` (normalized UUID string).
    static func updateCaption(forPostId postId: String, caption: String?) {
        let key = LookbookPostIdFormatting.graphQLUUIDString(from: postId).lowercased()
        guard !key.isEmpty else { return }
        var newestFirst = load()
        guard let idx = newestFirst.firstIndex(where: {
            LookbookPostIdFormatting.graphQLUUIDString(from: $0.id).lowercased() == key
        }) else { return }
        var rec = newestFirst[idx]
        rec.caption = caption
        newestFirst[idx] = rec
        save(newestFirst)
    }

    /// Merges edit results into a matching upload record, or appends one so styles/tags stay available on this device.
    static func upsertAfterEdit(
        postId: String,
        serverPrimaryImageUrl: String,
        caption: String?,
        tags: [LookbookTagData],
        styles: [String]?,
        productSnapshots: [String: LookbookProductSnapshot]?,
        imageUrls: [String]?
    ) {
        let key = LookbookPostIdFormatting.graphQLUUIDString(from: postId).lowercased()
        guard !key.isEmpty else { return }
        var newestFirst = load()
        if let idx = newestFirst.firstIndex(where: {
            LookbookPostIdFormatting.graphQLUUIDString(from: $0.id).lowercased() == key
        }) {
            var rec = newestFirst[idx]
            rec.caption = caption
            rec.tags = tags
            if let s = styles { rec.styles = s.isEmpty ? nil : s }
            rec.productSnapshots = productSnapshots
            if let urls = imageUrls, urls.count > 1 {
                rec.imageUrls = urls
            }
            newestFirst[idx] = rec
            save(newestFirst)
            return
        }
        let trimmedFirst = imageUrls?.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let primary = trimmedFirst.isEmpty ? serverPrimaryImageUrl : trimmedFirst
        let rec = LookbookUploadRecord(
            id: postId,
            imagePath: primary,
            imageUrls: (imageUrls?.count ?? 0) > 1 ? imageUrls : nil,
            tags: tags,
            caption: caption,
            styles: styles,
            productSnapshots: productSnapshots
        )
        append(rec)
    }

    /// All uploaded records to show in the lookbook feed, newest first.
    static func load() -> [LookbookUploadRecord] {
        guard let data = defaults.data(forKey: feedKey),
              let list = try? JSONDecoder().decode([LookbookUploadRecord].self, from: data) else { return [] }
        return list.reversed() // newest first
    }

    private static func save(_ list: [LookbookUploadRecord]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: feedKey)
    }
}
