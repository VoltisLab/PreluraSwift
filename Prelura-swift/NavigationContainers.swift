import SwiftUI

// MARK: - Home

struct HomeNavigation: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item, authService: authService)
                    case .conversation, .menu:
                        EmptyView()
                    }
                }
        }
    }
}

// MARK: - Discover

struct DiscoverNavigation: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            DiscoverView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item, authService: authService)
                    case .conversation, .menu:
                        EmptyView()
                    }
                }
        }
    }
}

// MARK: - Sell

struct SellNavigation: View {
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            SellView(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Inbox

struct InboxNavigation: View {
    var body: some View {
        NavigationStack {
            ChatListView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .conversation(let conversation):
                        ChatDetailView(conversation: conversation)
                    case .itemDetail, .menu:
                        EmptyView()
                    }
                }
        }
    }
}

// MARK: - Profile

struct ProfileNavigation: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        NavigationStack {
            ProfileView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item, authService: authService)
                    case .menu(let context):
                        MenuView(
                            listingCount: context.listingCount,
                            isMultiBuyEnabled: context.isMultiBuyEnabled,
                            isVacationMode: context.isVacationMode,
                            isStaff: context.isStaff
                        )
                    case .conversation:
                        EmptyView()
                    }
                }
        }
    }
}
