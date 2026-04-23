import SwiftUI

// MARK: - Rows (data-driven for filtering)

private enum DebugMenuItem: String, CaseIterable, Identifiable {
    case appearanceTheme
    case pushDiagnostics
    case messagePushTrace
    case chatLiveUpdate
    case webSocketTest
    case messageDeliveryTest
    case notificationMatrix
    case orderChatMock
    case profileCards
    case snackbarsGallery
    case appBannersGallery
    case networkErrorTLS
    case lookbookSandbox
    case likeButtonOnly
    case glassMaterials
    case glassEffectTransition
    case haptics
    case animatedScreen
    case blackScreens
    case notificationIconLab
    case dashboard
    case orderScreen
    case shopTools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearanceTheme: return "Theme (Appearance copy)"
        case .pushDiagnostics: return "Push diagnostics"
        case .messagePushTrace: return "Message push trace"
        case .chatLiveUpdate: return "Chat live update trace"
        case .webSocketTest: return "WebSocket test"
        case .messageDeliveryTest: return "Message delivery test"
        case .notificationMatrix: return "Notification matrix"
        case .orderChatMock: return "Order"
        case .profileCards: return "Profile cards, and components"
        case .snackbarsGallery: return "Snackbars gallery"
        case .appBannersGallery: return "Banners gallery (excl. Discover)"
        case .networkErrorTLS: return "Network error mapping (TLS)"
        case .lookbookSandbox: return "Lookbook feed sandbox"
        case .likeButtonOnly: return "Like button only"
        case .glassMaterials: return "Glass materials"
        case .glassEffectTransition: return "Glass effect transition"
        case .haptics: return L10n.string("Haptics")
        case .animatedScreen: return "Animated screen"
        case .blackScreens: return "Black screens"
        case .notificationIconLab: return "Notification icons (admin + retail)"
        case .dashboard: return "Dashboard"
        case .orderScreen: return "Order screen"
        case .shopTools: return L10n.string("Shop tools")
        }
    }

    var icon: String {
        switch self {
        case .appearanceTheme: return "paintbrush"
        case .pushDiagnostics: return "bell.badge"
        case .messagePushTrace: return "bubble.left.and.text.bubble.right"
        case .chatLiveUpdate: return "arrow.triangle.branch"
        case .webSocketTest: return "network"
        case .messageDeliveryTest: return "paperplane"
        case .notificationMatrix: return "list.bullet.rectangle.portrait"
        case .orderChatMock: return "bubble.left.and.bubble.right"
        case .profileCards: return "square.stack.3d.up"
        case .snackbarsGallery: return "capsule.portrait.fill"
        case .appBannersGallery: return "rectangle.stack.fill"
        case .networkErrorTLS: return "lock.trianglebadge.exclamationmark"
        case .lookbookSandbox: return "rectangle.stack"
        case .likeButtonOnly: return "heart"
        case .glassMaterials: return "drop.fill"
        case .glassEffectTransition: return "arrow.triangle.2.circlepath"
        case .haptics: return "waveform"
        case .animatedScreen: return "waveform.path.ecg"
        case .blackScreens: return "square.fill"
        case .notificationIconLab: return "bell.badge.fill"
        case .dashboard: return "chart.bar.doc.horizontal"
        case .orderScreen: return "doc.text"
        case .shopTools: return "wrench.and.screwdriver"
        }
    }
}

/// Debug menu screen – submenu for debug tools and component showcase.
struct DebugMenuView: View {
    @State private var searchText: String = ""

    /// "Message delivery test" is DEBUG-only (sends real DMs); keep other tools in Release/TestFlight).
    private static var debugMenuItemsForCurrentBuild: [DebugMenuItem] {
        #if DEBUG
        Array(DebugMenuItem.allCases)
        #else
        DebugMenuItem.allCases.filter { $0 != .messageDeliveryTest }
        #endif
    }

    private var filteredDebugItems: [DebugMenuItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = Self.debugMenuItemsForCurrentBuild
        guard !q.isEmpty else { return base }
        return base.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        List {
            Section {
                Text("Build: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            } header: {
                Text("Info")
            }
            Section {
                if filteredDebugItems.isEmpty {
                    Text(L10n.string("No matching tools"))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                } else {
                    ForEach(filteredDebugItems) { item in
                        NavigationLink {
                            debugDestination(for: item)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: item.icon)
                                    .font(.body)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                Text(item.title)
                                    .foregroundStyle(Theme.Colors.primaryText)
                            }
                        }
                    }
                }
            } header: {
                Text("Tools")
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .appStandardSearchable(
            text: $searchText,
            prompt: Text(L10n.string("Search debug tools"))
        )
    }

    @ViewBuilder
    private func debugDestination(for item: DebugMenuItem) -> some View {
        switch item {
        case .appearanceTheme: DebugAppearanceThemeView()
        case .pushDiagnostics: PushDiagnosticsView()
        case .messagePushTrace: MessageChatPushTraceDebugView()
        case .chatLiveUpdate: ChatThreadLiveUpdateDebugView()
        case .webSocketTest: WebSocketConnectionDebugView()
        case .messageDeliveryTest:
            #if DEBUG
            MessageDeliveryDebugView()
            #else
            Text(L10n.string("This tool is only available in debug builds."))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding()
            #endif
        case .notificationMatrix: NotificationTypeMatrixDebugView()
        case .orderChatMock: OrderChatMockDebugView()
        case .profileCards: ProfileCardsComponentsView()
        case .snackbarsGallery: SnackbarsDebugGalleryView()
        case .appBannersGallery: AppBannersDebugGalleryView()
        case .networkErrorTLS: NetworkErrorPresentationDebugView()
        case .lookbookSandbox: DebugLookbookFeedSandboxView()
        case .likeButtonOnly: DebugLikeButtonOnlyView()
        case .glassMaterials: GlassMaterialsView()
        case .glassEffectTransition: GlassEffectTransitionView()
        case .haptics: HapticsDebugView()
        case .animatedScreen: AnimatedScreenDebugView()
        case .blackScreens: BlackScreensMenuView()
        case .notificationIconLab: NotificationIconDebugView()
        case .dashboard: DashboardView()
        case .orderScreen: OrderScreenDebugView()
        case .shopTools: ShopToolsView()
        }
    }
}
