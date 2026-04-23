//
//  LookbookSettingsView.swift
//  Prelura-swift
//
//  Lookbook-specific settings (reached from the Lookbook hub or main Settings).
//

import SwiftUI

struct LookbookSettingsView: View {
    /// Shared store (settings may open from Profile without a parent `environmentObject`).
    @ObservedObject private var hideLikeCountsStore = LookbookHideLikeCountsStore.shared
    @ObservedObject private var immersiveScrollFeelStore = LookbookImmersiveScrollFeelStore.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LookbookMyItemsScreenView()
                } label: {
                    Text(L10n.string("My items"))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                }
            } header: {
                Text(L10n.string("My posts"))
            }

            Section {
                Toggle(isOn: Binding(
                    get: { hideLikeCountsStore.hideAllLikeCountsGlobally },
                    set: { hideLikeCountsStore.setHideAllLikeCountsGlobally($0) }
                )) {
                    Text(L10n.string("Hide all like counts"))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .tint(Theme.primaryColor)

                Button {
                    immersiveScrollFeelStore.cycleToNext()
                } label: {
                    HStack {
                        Text(L10n.string("Scroll"))
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.primaryText)
                        Spacer()
                        Text(immersiveScrollFeelStore.feel.displayTitle)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(L10n.string("Lookbook"))
            } footer: {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(L10n.string("When this is on, like counts are hidden on all lookbook posts. On your own posts, open the more options menu on a post and choose Show likes to show the count for that post only."))
                    Text(L10n.string("Scroll: Smooth uses a free-scrolling feed; Sticky snaps each post into place. Fullscreen Lookbook: Smooth pages by post; Sticky uses a looser view-aligned glide."))
                }
                .font(Theme.Typography.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Lookbook settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
