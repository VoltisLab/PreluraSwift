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
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            AppearanceRootView()
                .environmentObject(authService)
        }
    }
}

/// Applies preferredColorScheme from stored preference and syncs Theme.effectiveColorScheme for light/dark across all screens.
struct AppearanceRootView: View {
    @EnvironmentObject var authService: AuthService
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
        .onAppear { syncThemeScheme() }
        .onChange(of: appearanceMode) { _, _ in syncThemeScheme() }
        .onChange(of: colorScheme) { _, _ in syncThemeScheme() }
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

            SellNavigation()
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
