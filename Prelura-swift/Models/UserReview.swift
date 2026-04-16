import Foundation

/// A single review for a user (matches Flutter UserReviewModel / backend ReviewUserType).
struct UserReview: Identifiable {
    let id: String
    /// 1.0…5.0 in 0.5 steps (matches backend `Float` / GraphQL `Float`).
    let rating: Double
    let comment: String
    /// Optional “What went well?” tags from `rateUser(highlights:)`.
    let highlights: [String]
    let isAutoReview: Bool
    let dateCreated: Date
    let reviewerUsername: String
    let reviewerProfilePictureUrl: String?

    /// Platform automatic review (post-sale, etc.): show as **Wearhouse** with brand avatar, not the backend reviewer row.
    var isPlatformAutomaticReview: Bool {
        if isAutoReview { return true }
        let t = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.caseInsensitiveCompare("Sale completed successfully") == .orderedSame
    }
}
