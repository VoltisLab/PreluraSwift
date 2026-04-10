//
//  LookbookSettingsView.swift
//  Prelura-swift
//
//  Lookbook-specific settings (reached from the Lookbook hub or main Settings).
//

import SwiftUI

struct LookbookSettingsView: View {
    var body: some View {
        List {
            Section {
                Text(L10n.string("Lookbook settings footer"))
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.vertical, 4)
            } header: {
                Text(L10n.string("Lookbook"))
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Lookbook settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
