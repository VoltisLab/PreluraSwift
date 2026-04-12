import SwiftUI
import UIKit

/// One SF Symbol star with fractional fill (0…1). Flat monochrome rendering (no symbol shadow / emboss).
struct SingleStarPortionView: View {
    var fill: CGFloat
    var starSize: CGFloat = 16
    var filledColor: Color = Color(red: 1, green: 0.8, blue: 0)
    var emptyColor: Color = Color.primary.opacity(0.2)

    var body: some View {
        let font = Font.system(size: starSize * 0.92, weight: .regular, design: .default)
        let w = starSize * max(0, min(1, fill))
        ZStack(alignment: .leading) {
            Image(systemName: "star")
                .font(font)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(emptyColor)
            Image(systemName: "star.fill")
                .font(font)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(filledColor)
                .frame(width: starSize, height: starSize)
                .mask(
                    Rectangle()
                        .frame(width: w, height: starSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                )
        }
        .compositingGroup()
        .frame(width: starSize, height: starSize)
    }
}

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
                SingleStarPortionView(
                    fill: portion,
                    starSize: starSize,
                    filledColor: filledColor,
                    emptyColor: emptyColor
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        String(format: "%.1f out of 5 stars", clamped)
    }
}

/// Five stars in **0.5** steps. Each star is tappable: cycles **full → half → empty** for that star (stars after it clear). Map to API ints with `Int(rating.rounded())` when submitting.
struct InteractiveStarRatingControl: View {
    @Binding var rating: Double
    var starSize: CGFloat = 34
    var spacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { index in
                    starButton(starIndex: index)
                }
            }
            .frame(maxWidth: .infinity)

            Text(L10n.orderReviewRatingSubtitle(for: rating))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rating")
        .accessibilityValue(L10n.orderReviewRatingSubtitle(for: rating))
        .accessibilityAdjustableAction { direction in
            let step = 0.5
            switch direction {
            case .increment:
                rating = min(5, rating + step)
            case .decrement:
                rating = max(0, rating - step)
            @unknown default:
                break
            }
        }
    }

    private func starButton(starIndex: Int) -> some View {
        let fill = starFillPortion(starIndex: starIndex, rating: rating)
        return Button {
            cycleRating(starIndex: starIndex)
        } label: {
            SingleStarPortionView(fill: fill, starSize: starSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Canonical fill (0, 0.5, or 1) for `starIndex` given a half-step `rating`.
    private func starFillPortion(starIndex: Int, rating: Double) -> CGFloat {
        let r = min(5, max(0, halfStepNormalized(rating)))
        let remainder = r - Double(starIndex)
        if remainder >= 1 { return 1 }
        if remainder >= 0.5 { return 0.5 }
        return 0
    }

    /// Tap star `k`: cycle that star through full → half → empty; stars before `k` stay full; stars after clear.
    private func cycleRating(starIndex k: Int) {
        let r = halfStepNormalized(rating)
        let sequence: [Double] = [Double(k) + 1, Double(k) + 0.5, Double(k)]
        let epsilon = 0.001
        if let i = sequence.firstIndex(where: { abs($0 - r) < epsilon }) {
            applyRating(sequence[(i + 1) % sequence.count])
            return
        }
        applyRating(sequence[0])
    }

    private func applyRating(_ next: Double) {
        let clamped = min(5, max(0, halfStepNormalized(next)))
        let cur = halfStepNormalized(rating)
        guard abs(clamped - cur) > 0.001 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        rating = clamped
    }

    private func halfStepNormalized(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }
}
