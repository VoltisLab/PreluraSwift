import Combine
import Foundation

/// How vertical scrolling feels in Lookbook: main **list** feed and the fullscreen immersive pager.
enum LookbookImmersiveScrollFeel: String, CaseIterable {
    /// List: `scrollTargetLayout` + `.viewAligned(limitBehavior: .always)`. Immersive: `.viewAligned`.
    case sticky
    /// List: no snap (plain scroll). Immersive: `.paging`.
    case smooth

    var displayTitle: String {
        switch self {
        case .sticky: return L10n.string("Sticky")
        case .smooth: return L10n.string("Smooth")
        }
    }
}

@MainActor
final class LookbookImmersiveScrollFeelStore: ObservableObject {
    static let shared = LookbookImmersiveScrollFeelStore()

    private let storageKey = "lookbook_immersive_scroll_feel"

    /// Published so every `@ObservedObject` view reliably refreshes (a computed `feel` + side `revision` was easy for SwiftUI to miss for scroll internals).
    @Published private(set) var feel: LookbookImmersiveScrollFeel

    private init() {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? LookbookImmersiveScrollFeel.sticky.rawValue
        feel = LookbookImmersiveScrollFeel(rawValue: raw) ?? .sticky
    }

    /// Cycles **Sticky** ↔ **Smooth** (settings row tap).
    func cycleToNext() {
        let next: LookbookImmersiveScrollFeel = feel == .sticky ? .smooth : .sticky
        UserDefaults.standard.set(next.rawValue, forKey: storageKey)
        feel = next
    }
}
