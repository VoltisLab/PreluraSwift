import SwiftUI
import UIKit

/// Inbox tab label for `TabView`: envelope + unread count placed along a 45° line from the icon’s top-trailing corner (outward).
struct InboxTabBarItemLabel: View {
    let unreadCount: Int
    /// Offset along the diagonal (equal +x and −y ⇒ 45° in view coordinates).
    private static let diagonalOut: CGFloat = 7

    var body: some View {
        Label {
            Text(L10n.string("Inbox"))
        } icon: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "envelope")
                    .font(.system(size: 22, weight: .medium))
                if unreadCount > 0 {
                    inboxUnreadBadge(count: unreadCount)
                        .offset(x: Self.diagonalOut, y: -Self.diagonalOut)
                }
            }
        }
    }

    /// Same opaque treatment as `NotificationToolbarBellVisual` so tab bar materials do not wash out the red.
    private static let opaqueBadgeRed = Color(UIColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1))

    private func inboxUnreadBadge(count: Int) -> some View {
        let label = count > 99 ? "99+" : "\(count)"
        return Text(label)
            .font(.system(size: label.count >= 3 ? 9 : 10, weight: .bold))
            .foregroundStyle(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, count >= 10 ? 5 : 4)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(Self.opaqueBadgeRed))
            .compositingGroup()
    }
}

/// Custom tab bar overlay that can animate in from the bottom when the navbar reappears.
struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    let tabItems: [(tag: Int, label: String, icon: String)] = [
        (0, "Home", "house.fill"),
        (1, "Discover", "magnifyingglass"),
        (2, "Sell", "plus"),
        (3, "Inbox", "envelope"),
        (4, "Profile", "person.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.tag) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = item.tag
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .medium))
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == item.tag ? Theme.primaryColor : Color(uiColor: .secondaryLabel))
                }
                .buttonStyle(PlainTappableButtonStyle())
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(uiColor: UIColor.systemBackground.withAlphaComponent(0.9)))
        .ignoresSafeArea(edges: .bottom)
    }
}
