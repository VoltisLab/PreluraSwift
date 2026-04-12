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
    case feedNetworkBanner
    case networkErrorTLS
    case lookbookSandbox
    case likeButtonOnly
    case glassMaterials
    case glassEffectTransition
    case haptics
    case animatedScreen
    case blackScreens
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
        case .feedNetworkBanner: return "Feed network banner"
        case .networkErrorTLS: return "Network error mapping (TLS)"
        case .lookbookSandbox: return "Lookbook feed sandbox"
        case .likeButtonOnly: return "Like button only"
        case .glassMaterials: return "Glass materials"
        case .glassEffectTransition: return "Glass effect transition"
        case .haptics: return L10n.string("Haptics")
        case .animatedScreen: return "Animated screen"
        case .blackScreens: return "Black screens"
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
        case .feedNetworkBanner: return "wifi.exclamationmark"
        case .networkErrorTLS: return "lock.trianglebadge.exclamationmark"
        case .lookbookSandbox: return "rectangle.stack"
        case .likeButtonOnly: return "heart"
        case .glassMaterials: return "drop.fill"
        case .glassEffectTransition: return "arrow.triangle.2.circlepath"
        case .haptics: return "waveform"
        case .animatedScreen: return "waveform.path.ecg"
        case .blackScreens: return "square.fill"
        case .dashboard: return "chart.bar.doc.horizontal"
        case .orderScreen: return "doc.text"
        case .shopTools: return "wrench.and.screwdriver"
        }
    }
}

/// Debug menu screen – submenu for debug tools and component showcase.
struct DebugMenuView: View {
    @State private var searchText: String = ""
    @State private var isDebugSearchPresented: Bool = false

    private var filteredDebugItems: [DebugMenuItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(DebugMenuItem.allCases) }
        return DebugMenuItem.allCases.filter { $0.title.lowercased().contains(q) }
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
        .searchable(
            text: $searchText,
            isPresented: $isDebugSearchPresented,
            prompt: Text(L10n.string("Search debug tools"))
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.selection()
                    isDebugSearchPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(minWidth: Theme.AppBar.buttonSize, minHeight: Theme.AppBar.buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Search debug tools"))
            }
        }
    }

    @ViewBuilder
    private func debugDestination(for item: DebugMenuItem) -> some View {
        switch item {
        case .appearanceTheme: DebugAppearanceThemeView()
        case .pushDiagnostics: PushDiagnosticsView()
        case .messagePushTrace: MessageChatPushTraceDebugView()
        case .chatLiveUpdate: ChatThreadLiveUpdateDebugView()
        case .webSocketTest: WebSocketConnectionDebugView()
        case .messageDeliveryTest: MessageDeliveryDebugView()
        case .notificationMatrix: NotificationTypeMatrixDebugView()
        case .orderChatMock: OrderChatMockDebugView()
        case .profileCards: ProfileCardsComponentsView()
        case .feedNetworkBanner: FeedNetworkBannerDebugView()
        case .networkErrorTLS: NetworkErrorPresentationDebugView()
        case .lookbookSandbox: DebugLookbookFeedSandboxView()
        case .likeButtonOnly: DebugLikeButtonOnlyView()
        case .glassMaterials: GlassMaterialsView()
        case .glassEffectTransition: GlassEffectTransitionView()
        case .haptics: HapticsDebugView()
        case .animatedScreen: AnimatedScreenDebugView()
        case .blackScreens: BlackScreensMenuView()
        case .dashboard: DashboardView()
        case .orderScreen: OrderScreenDebugView()
        case .shopTools: ShopToolsView()
        }
    }
}
