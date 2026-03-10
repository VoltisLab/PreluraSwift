import SwiftUI

// MARK: - Home

struct HomeNavigation: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator

    var body: some View {
        NavigationStack {
            HomeView(tabCoordinator: tabCoordinator)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item, authService: authService)
                    case .conversation, .menu:
                        EmptyView()
                    case .reviews(let username, let rating):
                        ReviewsView(username: username, rating: rating)
                    }
                }
        }
    }
}

// MARK: - Discover

struct DiscoverNavigation: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator

    var body: some View {
        NavigationStack {
            DiscoverView(tabCoordinator: tabCoordinator)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .itemDetail(let item):
                        ItemDetailView(item: item, authService: authService)
                    case .conversation, .menu:
                        EmptyView()
                    case .reviews(let username, let rating):
                        ReviewsView(username: username, rating: rating)
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
    @ObservedObject var tabCoordinator: TabCoordinator

    var body: some View {
        NavigationStack {
            ChatListView(tabCoordinator: tabCoordinator)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .conversation(let conversation):
                        ChatDetailView(conversation: conversation)
                    case .itemDetail, .menu:
                        EmptyView()
                    case .reviews(let username, let rating):
                        ReviewsView(username: username, rating: rating)
                    }
                }
        }
    }
}

// MARK: - Profile

struct ProfileNavigation: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var tabCoordinator: TabCoordinator

    var body: some View {
        NavigationStack {
            ProfileView(tabCoordinator: tabCoordinator)
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
                    case .reviews(let username, let rating):
                        ReviewsView(username: username, rating: rating)
                    case .conversation:
                        EmptyView()
                    }
                }
        }
    }
}
