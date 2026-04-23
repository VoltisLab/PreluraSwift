import SwiftUI

@main
struct BarcaFanApp: App {
    @State private var themeStore = KitThemeStore()
    @State private var newsFeedModel = NewsFeedViewModel()
    @State private var matchesViewModel = MatchesViewModel()
    @State private var tabRouter = AppTabRouter()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(themeStore)
                .environment(newsFeedModel)
                .environment(matchesViewModel)
                .environment(tabRouter)
        }
    }
}
