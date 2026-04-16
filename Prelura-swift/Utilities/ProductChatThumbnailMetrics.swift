import CoreGraphics

/// Portrait product thumb used in chat headers and aligned with the notifications list (`NotificationRowView`).
enum ProductChatThumbnailMetrics {
    /// Same 48×64 @ 0.8 scale as `NotificationRowView` product thumbnail.
    static let width: CGFloat = 48 * 0.8
    static let height: CGFloat = 64 * 0.8
    static let cornerRadius: CGFloat = 8 * 0.8
    /// Width ÷ height ≈ 1/1.3, matching the home feed grid portrait slot.
    static var widthToHeightRatio: CGFloat { width / height }
}
