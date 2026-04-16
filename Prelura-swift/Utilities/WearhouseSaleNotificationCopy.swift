import Foundation

/// Single source for seller “sale” copy (chat banner, bell list, push normalization).
enum WearhouseSaleNotificationCopy {
    static let sellerSaleMessage = "You made a sale! 🎉"

    /// True when `message` is a legacy or alternate server string we should replace with ``sellerSaleMessage`` in UI or foreground push.
    static func shouldNormalizeSellerSaleMessage(_ message: String) -> Bool {
        let t = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if t == sellerSaleMessage { return false }
        let lower = t.lowercased()
        if lower.contains("you made a sale") { return true }
        if lower.contains("congratulations") && lower.contains("sale") { return true }
        return false
    }
}
