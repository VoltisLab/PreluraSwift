import SwiftUI

/// Opens the **How to use** article on the marketing site (`Constants.helpHowToUseWearhouseURL`).
struct HowToUseWearhouseView: View {
    var body: some View {
        HostedWebArticleView(
            title: L10n.string("How to use Wearhouse"),
            urlString: Constants.helpHowToUseWearhouseURL
        )
    }
}
