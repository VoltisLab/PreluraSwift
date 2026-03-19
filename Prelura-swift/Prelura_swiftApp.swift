//
//  Prelura_swiftApp.swift
//  Prelura-swift
//
//  Created by User on 09/03/2026.
//

import SwiftUI
import UIKit

/// Storage key for appearance: "system" | "light" | "dark"
let kAppearanceMode = "appearance_mode"

/// When the user is logged in and we have an APNs device token, send it via updateProfile(fcmToken:) so the backend can deliver push notifications (same as Flutter).
private func registerPushTokenIfNeeded(authService: AuthService) {
    guard authService.isAuthenticated, let token = UserDefaults.standard.string(forKey: kDeviceTokenKey), !token.isEmpty else { return }
    Task { @MainActor in
        let userService = UserService()
        userService.updateAuthToken(authService.authToken)
        _ = try? await userService.updateProfile(fcmToken: token)
    }
}

@main
struct Prelura_swiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var appRouter = AppRouter()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView(onFinish: { showSplash = false })
                } else {
                    AppearanceRootView()
                }
            }
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
/// When system or in-app appearance changes, we sync Theme immediately and force a full view refresh so all elements (colors, tab bar, etc.) update correctly and the app doesn't become buggy.
struct AppearanceRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appRouter: AppRouter
    @AppStorage(kAppearanceMode) private var appearanceMode: String = "system"
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(kAppLanguage) private var appLanguage: String = "en"
    /// Identity for content so language/scheme changes refresh the UI. Updated asynchronously on language change to avoid heavy teardown in same run loop (prevents crash when switching to Greek).
    @State private var contentIdentity: String = ""

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
        content
            .id(contentIdentity.isEmpty ? "initial" : contentIdentity)
            .preferredColorScheme(resolvedScheme)
            .tint(Theme.primaryColor)
            .onAppear {
                syncThemeScheme()
                if appLanguage != "en" && appLanguage != "el" {
                    appLanguage = "en"
                }
                if contentIdentity.isEmpty {
                    contentIdentity = "\(appLanguage)_\(effectiveScheme)"
                }
            }
            .onChange(of: appearanceMode) { _, _ in
                syncThemeScheme()
                contentIdentity = "\(appLanguage)_\(effectiveScheme)"
            }
            .onChange(of: colorScheme) { _, _ in syncThemeScheme() }
            // Language is applied only on next app launch (see LanguageMenuView). We do not update contentIdentity here to avoid tearing down the entire view tree in-place, which can cause crashes when switching to Greek.
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
            .onAppear { registerPushTokenIfNeeded(authService: authService) }
            .onChange(of: authService.isAuthenticated) { _, _ in registerPushTokenIfNeeded(authService: authService) }
            .onReceive(NotificationCenter.default.publisher(for: .preluraDeviceTokenDidUpdate)) { _ in
                registerPushTokenIfNeeded(authService: authService)
            }
    }

    @ViewBuilder
    private var content: some View {
        let _ = syncThemeScheme()
        Group {
            if authService.isAuthenticated || authService.isGuestMode {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { authService.shouldShowOnboardingAfterLogin },
                set: { if !$0 { authService.markOnboardingCompleted() } }
            )
        ) {
            OnboardingView(onComplete: {
                withAnimation(.easeInOut(duration: 0.35)) {
                    authService.markOnboardingCompleted()
                }
            })
        }
        .animation(.easeInOut(duration: 0.35), value: authService.shouldShowOnboardingAfterLogin)
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

// Root tab controller: TabView at root with custom tab bar for tap-to-refresh. Each tab has its own NavigationStack.
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var tabCoordinator = TabCoordinator()
    @StateObject private var discoverViewModel = DiscoverViewModel(authService: nil)
    @StateObject private var inboxViewModel = InboxViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(kAppearanceMode) private var appearanceMode: String = "system"

    private var isDark: Bool {
        switch appearanceMode {
        case "light": return false
        case "dark": return true
        default: return colorScheme == .dark
        }
    }

    var body: some View {
        TabView(selection: Binding(
            get: { tabCoordinator.selectedTab },
            set: { tabCoordinator.handleTabTap($0) }
        )) {
            HomeNavigation(tabCoordinator: tabCoordinator)
                .environmentObject(tabCoordinator)
                .environment(\.optionalTabCoordinator, tabCoordinator)
                .tabItem { Label(L10n.string("Home"), systemImage: "house.fill") }
                .tag(0)

            DiscoverNavigation(tabCoordinator: tabCoordinator, discoverViewModel: discoverViewModel)
                .environmentObject(tabCoordinator)
                .environment(\.optionalTabCoordinator, tabCoordinator)
                .tabItem { Label(L10n.string("Discover"), systemImage: "magnifyingglass") }
                .tag(1)

            SellNavigation(selectedTab: Binding(
                get: { tabCoordinator.selectedTab },
                set: { tabCoordinator.selectTab($0) }
            ))
            .tabItem { Label(L10n.string("Sell"), systemImage: "plus") }
            .tag(2)

            InboxNavigation(tabCoordinator: tabCoordinator, inboxViewModel: inboxViewModel)
                .environmentObject(tabCoordinator)
                .environment(\.optionalTabCoordinator, tabCoordinator)
                .tabItem { Label(L10n.string("Inbox"), systemImage: "envelope") }
                .tag(3)

            ProfileNavigation(tabCoordinator: tabCoordinator)
                .environmentObject(tabCoordinator)
                .environment(\.optionalTabCoordinator, tabCoordinator)
                .tabItem { Label(L10n.string("Profile"), systemImage: "person.fill") }
                .tag(4)
        }
        .accentColor(Theme.primaryColor)
        .onAppear {
            applyTabBarAppearance()
            discoverViewModel.updateAuthToken(authService.authToken)
            inboxViewModel.updateAuthToken(authService.authToken)
            if authService.isAuthenticated {
                if discoverViewModel.discoverItems.isEmpty { discoverViewModel.refresh() }
                inboxViewModel.prefetch()
            }
        }
        .onChange(of: appearanceMode) { _, _ in applyTabBarAppearance() }
        .onChange(of: colorScheme) { _, _ in applyTabBarAppearance() }
        .onChange(of: authService.authToken) { _, token in
            discoverViewModel.updateAuthToken(token)
            inboxViewModel.updateAuthToken(token)
            if authService.isAuthenticated {
                if discoverViewModel.discoverItems.isEmpty { discoverViewModel.refresh() }
                inboxViewModel.prefetch()
            }
        }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        if isDark {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(red: 12/255, green: 12/255, blue: 12/255, alpha: 1) // #0C0C0C
        } else {
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground
        }
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
