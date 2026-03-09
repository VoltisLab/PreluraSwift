import SwiftUI

struct InboxShimmerView: View {
    var body: some View {
        List {
            ForEach(0..<8) { _ in
                InboxRowShimmer()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: UIScreen.main.bounds.height)
        .ignoresSafeArea(edges: .all)
        .background(Theme.Colors.background)
        .scrollContentBackground(.hidden)
        .shimmer()
    }
}

struct InboxRowShimmer: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar shimmer
            Circle()
                .fill(Theme.Colors.secondaryBackground)
                .frame(width: 50, height: 50)
            
            // Content shimmer
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 100, height: 16)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.secondaryBackground)
                        .frame(width: 50, height: 12)
                }
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 80, height: 12)
            }
            
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
