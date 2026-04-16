import SwiftUI

/// Silver-toned highlight that travels around a rounded rectangle, matching `PlanSilverTierCard`.
struct AnimatedSilverTravelingBorder: View {
    var outerCornerRadius: CGFloat
    var lineWidth: CGFloat = 1.25
    /// Inset of the stroke from the view edge (Plan card uses `2`).
    var strokeInset: CGFloat = 2

    private var strokedCornerRadius: CGFloat {
        max(2, outerCornerRadius - strokeInset)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { ctx in
            let angle = ctx.date.timeIntervalSinceReferenceDate * 22
            RoundedRectangle(cornerRadius: strokedCornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Self.silverA.opacity(0.95), Self.silverB,
                            Self.silverC.opacity(0.75), Self.silverA.opacity(0.55),
                        ]),
                        center: .center,
                        angle: .degrees(angle.truncatingRemainder(dividingBy: 360))
                    ),
                    lineWidth: lineWidth
                )
                .padding(strokeInset)
        }
    }

    private static let silverA = Color(red: 0.92, green: 0.94, blue: 0.98)
    private static let silverB = Color(red: 0.55, green: 0.62, blue: 0.72)
    private static let silverC = Color(red: 0.22, green: 0.26, blue: 0.34)
}
