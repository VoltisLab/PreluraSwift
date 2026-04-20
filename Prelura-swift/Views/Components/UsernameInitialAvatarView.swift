import SwiftUI

/// Default member avatar: brand circle + first character of username (matches `UserProfileView` / chat list).
struct UsernameInitialAvatarView: View {
    let username: String
    var size: CGFloat

    private var initial: String {
        let t = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = t.first else { return "?" }
        return String(c).uppercased()
    }

    private var letterPointSize: CGFloat {
        min(34, max(12, size * 0.34))
    }

    var body: some View {
        Circle()
            .fill(Theme.primaryColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: letterPointSize, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
