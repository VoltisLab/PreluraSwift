import Combine
import Foundation
import UIKit

/// How vertical paging feels in the fullscreen Lookbook feed (`UICollectionView` immersive pager).
enum LookbookImmersiveScrollFeel: String, CaseIterable {
    /// Strong snap between posts (`UIScrollView.DecelerationRate.fast`).
    case sticky
    /// Longer coast between posts (slower deceleration than `.normal`) so one flick can cross many posts.
    case smooth

    var decelerationRate: UIScrollView.DecelerationRate {
        switch self {
        case .sticky: return .fast
        // Higher raw value = less friction vs `.normal` (0.998); keeps momentum closer to a typical feed.
        case .smooth: return UIScrollView.DecelerationRate(rawValue: 0.999)
        }
    }

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

    @Published private(set) var revision: UInt64 = 0

    private init() {}

    var feel: LookbookImmersiveScrollFeel {
        _ = revision
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? LookbookImmersiveScrollFeel.sticky.rawValue
        return LookbookImmersiveScrollFeel(rawValue: raw) ?? .sticky
    }

    /// Cycles **Sticky** ↔ **Smooth** (settings row tap).
    func cycleToNext() {
        let next: LookbookImmersiveScrollFeel = feel == .sticky ? .smooth : .sticky
        UserDefaults.standard.set(next.rawValue, forKey: storageKey)
        revision &+= 1
    }
}
