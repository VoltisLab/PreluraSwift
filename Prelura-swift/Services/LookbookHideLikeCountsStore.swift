import Combine
import Foundation

/// Per-post preference (local only): hide the like **count** on lookbook feed rows — heart remains tappable.
@MainActor
final class LookbookHideLikeCountsStore: ObservableObject {
    static let shared = LookbookHideLikeCountsStore()

    private let storageKey = "lookbook_feed_hide_like_count_post_ids"
    /// Bumped when storage changes so `EnvironmentObject` subscribers refresh.
    @Published private(set) var revision: UInt64 = 0

    private init() {}

    func hidesLikeCount(forPostKey rawKey: String) -> Bool {
        _ = revision
        let k = normalizedKey(rawKey)
        guard !k.isEmpty else { return false }
        let set = Set((UserDefaults.standard.stringArray(forKey: storageKey) ?? []).map { $0.lowercased() })
        return set.contains(k)
    }

    func setHideLikeCount(_ hide: Bool, forPostKey rawKey: String) {
        let k = normalizedKey(rawKey)
        guard !k.isEmpty else { return }
        var arr = (UserDefaults.standard.stringArray(forKey: storageKey) ?? []).map { $0.lowercased() }
        var set = Set(arr)
        if hide {
            set.insert(k)
        } else {
            set.remove(k)
        }
        arr = Array(set).sorted()
        UserDefaults.standard.set(arr, forKey: storageKey)
        revision &+= 1
    }

    private func normalizedKey(_ rawKey: String) -> String {
        let t = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return LookbookPostIdFormatting.graphQLUUIDString(from: t).lowercased()
    }
}
