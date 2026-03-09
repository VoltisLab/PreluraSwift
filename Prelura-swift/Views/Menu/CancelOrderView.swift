import SwiftUI

struct CancelOrderView: View {
    var body: some View {
        ScrollView {
            Text("Cancel this order. Content coming soon.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Cancel Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
