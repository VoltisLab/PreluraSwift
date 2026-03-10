//
//  Prelura_swiftApp.swift
//  Prelura-swift
//
//  Created by User on 09/03/2026.
//

import SwiftUI

/// Storage key for appearance: "system" | "light" | "dark"
let kAppearanceMode = "appearance_mode"

@main
struct Prelura_swiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppearanceRootView()
                .environmentObject(authService)
                .environmentObject(appRouter)
                .onOpenURL { url in
                    Task { @MainActor in
                        appRouter.handle(url: url)
                    }
                }
        }
    }
}

/// Applies preferredColorScheme from stored preference and syncs Theme.effectiveColorScheme for light/dark across all screens.
struct AppearanceRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appRouter: AppRouter
    @AppStorage(kAppearanceMode) private var appearanceMode: String = "system"
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var effectiveScheme: ColorScheme {
        resolvedScheme ?? colorScheme
    }

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(resolvedScheme)
        .tint(Theme.primaryColor)
        .onAppear { syncThemeScheme() }
        .onChange(of: appearanceMode) { _, _ in syncThemeScheme() }
        .onChange(of: colorScheme) { _, _ in syncThemeScheme() }
        .fullScreenCover(item: $appRouter.pendingItem) { item in
            DeepLinkOverlayView(item: item, onDismiss: { appRouter.clearPending() })
                .environmentObject(authService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .preluraNotificationTapped)) { notification in
            guard let payload = notification.userInfo?[kNotificationTapPayloadKey] as? [AnyHashable: Any] else { return }
            Task { @MainActor in
                appRouter.handle(notificationPayload: payload)
            }
        }
    }

    private func syncThemeScheme() {
        Theme.effectiveColorScheme = effectiveScheme
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        if authService.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// Root tab controller: TabView at root, each tab has its own NavigationStack. Pushed screens hide the tab bar automatically.
struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeNavigation()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            DiscoverNavigation()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(1)

            SellNavigation(selectedTab: $selectedTab)
                .tabItem { Label("Sell", systemImage: "plus") }
                .tag(2)

            InboxNavigation()
                .tabItem { Label("Inbox", systemImage: "envelope") }
                .tag(3)

            ProfileNavigation()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .accentColor(Theme.primaryColor)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}
