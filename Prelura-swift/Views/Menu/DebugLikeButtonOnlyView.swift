import SwiftUI

/// Single control surface: uses `DebugSandboxLikeButton` (not `LikeButtonView` or production lookbook).
struct DebugLikeButtonOnlyView: View {
    @State private var liked = false
    @State private var count = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Only this control. Uses a plain SwiftUI `Button` (not `LikeButtonView`).")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            DebugSandboxLikeButton(isLiked: liked, likeCount: count) {
                liked.toggle()
                count += liked ? 1 : -1
            }

            Text("Liked: \(liked ? "yes" : "no")")
                .font(.caption.monospaced())
                .foregroundStyle(Theme.Colors.tertiaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
        .background(Theme.Colors.background)
        .navigationTitle("Like button only")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugLikeButtonOnlyView()
    }
}
#endif
