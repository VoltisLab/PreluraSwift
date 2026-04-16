import Combine
import Foundation

/// Local preferences for hiding like **counts** on the lookbook feed (heart stays tappable).
/// - Global “hide all”: every post hides counts except posts in the show override set.
/// - Global off: only posts in the per-post hide set hide counts (legacy behaviour).
@MainActor
final class LookbookHideLikeCountsStore: ObservableObject {
    static let shared = LookbookHideLikeCountsStore()

    /// Per-post hide when global “hide all” is **off**.
    private let perPostHideKey = "lookbook_feed_hide_like_count_post_ids"
    /// When **on**, like counts are hidden for all posts except those in `showOverrideKey`.
    private let hideAllGloballyKey = "lookbook_hide_all_like_counts"
    /// Post ids that **show** the like count while global hide-all is on.
    private let showOverrideKey = "lookbook_show_like_count_post_ids"

    /// Bumped when storage changes so `EnvironmentObject` subscribers refresh.
    @Published private(set) var revision: UInt64 = 0

    private init() {}

    /// When true, all lookbook posts hide like counts unless the post id is in the show-override list.
    var hideAllLikeCountsGlobally: Bool {
        _ = revision
        return UserDefaults.standard.bool(forKey: hideAllGloballyKey)
    }

    func setHideAllLikeCountsGlobally(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: hideAllGloballyKey)
        revision &+= 1
    }

    func hidesLikeCount(forPostKey rawKey: String) -> Bool {
        _ = revision
        let k = normalizedKey(rawKey)
        guard !k.isEmpty else { return false }
        if UserDefaults.standard.bool(forKey: hideAllGloballyKey) {
            let showOverrides = stringSet(forKey: showOverrideKey)
            return !showOverrides.contains(k)
        }
        let hideSet = stringSet(forKey: perPostHideKey)
        return hideSet.contains(k)
    }

    /// `hide == true` means the numeric like count should be hidden for this post (subject to global vs per-post rules).
    func setHideLikeCount(_ hide: Bool, forPostKey rawKey: String) {
        let k = normalizedKey(rawKey)
        guard !k.isEmpty else { return }
        if UserDefaults.standard.bool(forKey: hideAllGloballyKey) {
            var showOverrides = stringSet(forKey: showOverrideKey)
            if hide {
                showOverrides.remove(k)
            } else {
                showOverrides.insert(k)
            }
            saveStringSet(showOverrides, forKey: showOverrideKey)
        } else {
            var hideSet = stringSet(forKey: perPostHideKey)
            if hide {
                hideSet.insert(k)
            } else {
                hideSet.remove(k)
            }
            saveStringSet(hideSet, forKey: perPostHideKey)
        }
        revision &+= 1
    }

    private func stringSet(forKey key: String) -> Set<String> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).map { $0.lowercased() })
    }

    private func saveStringSet(_ set: Set<String>, forKey key: String) {
        UserDefaults.standard.set(Array(set).sorted(), forKey: key)
    }

    private func normalizedKey(_ rawKey: String) -> String {
        let t = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return LookbookPostIdFormatting.graphQLUUIDString(from: t).lowercased()
    }
}
