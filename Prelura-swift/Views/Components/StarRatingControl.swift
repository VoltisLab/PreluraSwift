import SwiftUI
import UIKit

/// Read-only row of five stars with **fractional** fill per star (e.g. 3.7 → three full + 70% of the fourth).
struct FractionalStarRatingDisplay: View {
    let rating: Double
    var starSize: CGFloat = 16
    var spacing: CGFloat = 2
    /// Gold/amber (matches review lists).
    var filledColor: Color = Color(red: 1, green: 0.8, blue: 0)
    var emptyColor: Color = Color.primary.opacity(0.2)

    private var clamped: Double { min(5, max(0, rating)) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { i in
                let portion = CGFloat(min(1, max(0, clamped - Double(i))))
                starCell(fill: portion)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        String(format: "%.1f out of 5 stars", clamped)
    }

    @ViewBuilder
    private func starCell(fill: CGFloat) -> some View {
        let font = Font.system(size: starSize * 0.92)
        let w = starSize * max(0, min(1, fill))
        ZStack(alignment: .leading) {
            Image(systemName: "star")
                .font(font)
                .foregroundStyle(emptyColor)
            Image(systemName: "star.fill")
                .font(font)
                .foregroundStyle(filledColor)
                .frame(width: starSize, height: starSize)
                .mask(
                    Rectangle()
                        .frame(width: w, height: starSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                )
        }
        .frame(width: starSize, height: starSize)
    }
}

/// Tappable / draggable 1…5 stars in **0.5** steps. Map to API ints with `Int(rating.rounded())` when submitting.
struct InteractiveStarRatingControl: View {
    @Binding var rating: Double
    var starSize: CGFloat = 34
    var spacing: CGFloat = 6

    private var rowWidth: CGFloat { starSize * 5 + spacing * 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ZStack {
                FractionalStarRatingDisplay(
                    rating: rating,
                    starSize: starSize,
                    spacing: spacing
                )
                .accessibilityHidden(true)
                Color.clear
                    .frame(width: rowWidth, height: starSize)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                updateRating(x: gesture.location.x)
                            }
                    )
            }
            .frame(maxWidth: .infinity)

            Text(ratingSubtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rating")
        .accessibilityValue(ratingSubtitle)
        .accessibilityAdjustableAction { direction in
            let step = 0.5
            switch direction {
            case .increment:
                rating = min(5, rating + step)
            case .decrement:
                rating = max(1, rating - step)
            @unknown default:
                break
            }
        }
    }

    private var ratingSubtitle: String {
        if rating == floor(rating) {
            return "\(Int(rating)) out of 5"
        }
        return String(format: "%.1f out of 5", rating)
    }

    private func updateRating(x: CGFloat) {
        guard rowWidth > 0 else { return }
        let t = min(1, max(0, x / rowWidth))
        let linear = 1 + t * 4
        let snapped = (linear * 2).rounded() / 2
        let next = min(5, max(1, snapped))
        if next != rating {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            rating = next
        }
    }
}
