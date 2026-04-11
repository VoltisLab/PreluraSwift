import SwiftUI

/// In-app **WebView** for a page on `Constants.publicWebsiteBaseURL` (help articles, etc.).
struct HostedWebArticleView: View {
    let title: String
    let urlString: String
    @State private var isLoading = true

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                ZStack(alignment: .top) {
                    WebView(url: url, isLoading: $isLoading)
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.Colors.background)
                    }
                }
            } else {
                legalFallback(title: title, message: "Unable to load this page.")
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Shared helpers
private func legalFallback(title: String, message: String) -> some View {
    ScrollView {
        Text(message)
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
    }
}
