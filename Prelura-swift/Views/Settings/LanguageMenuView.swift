//
//  LanguageMenuView.swift
//  Prelura-swift
//
//  App language: English or Cypriot (Greek). Selection is stored and applied app-wide.
//

import SwiftUI

struct LanguageMenuView: View {
    @AppStorage(kAppLanguage) private var appLanguage: String = "en"

    private let options: [(id: String, titleKey: String)] = [
        ("en", "English"),
        ("el", "Cypriot")
    ]

    var body: some View {
        List {
            Section {
                ForEach(options, id: \.id) { option in
                    Button {
                        appLanguage = option.id
                    } label: {
                        HStack {
                            Text(L10n.string(option.titleKey))
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                            if appLanguage == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.primaryColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(L10n.string("Cypriot displays the app in Greek."))
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.Colors.background)
        .navigationTitle(L10n.string("Language"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        LanguageMenuView()
    }
}
