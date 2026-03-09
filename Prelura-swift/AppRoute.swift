import SwiftUI

/// Central router for navigation. Only root screens live in the tab’s NavigationStack; everything else is pushed via these routes.
enum AppRoute: Hashable {
    case itemDetail(Item)
    case conversation(Conversation)
    case menu(MenuContext)
}

/// Context passed when pushing Menu (profile menu with listing counts and flags).
struct MenuContext: Hashable {
    var listingCount: Int
    var isMultiBuyEnabled: Bool
    var isVacationMode: Bool
    var isStaff: Bool
}
