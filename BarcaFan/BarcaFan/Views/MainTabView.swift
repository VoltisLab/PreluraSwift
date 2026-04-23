import SwiftUI

struct MainTabView: View {
    @Environment(KitThemeStore.self) private var themeStore
    @Environment(AppTabRouter.self) private var tabRouter

    var body: some View {
        @Bindable var tabRouter = tabRouter
        let palette = themeStore.current.palette
        ZStack {
            ThemedBackgroundView()
            TabView(selection: $tabRouter.selectedTab) {
                NewsFeedView()
                    .tabItem { Label("News", systemImage: "newspaper.fill") }
                    .tag(0)

                FeatureHubView()
                    .tabItem { Label("Fans", systemImage: "person.3.fill") }
                    .tag(1)

                MatchesView()
                    .tabItem { Label("Matches", systemImage: "sportscourt") }
                    .tag(2)

                ThemePickerView()
                    .tabItem { Label("Themes", systemImage: "paintpalette.fill") }
                    .tag(3)
            }
        }
        .onChange(of: themeStore.current) { _, _ in }
        .onChange(of: themeStore.showBackgroundPatterns) { _, _ in }
        .tint(palette.accent)
    }
}
