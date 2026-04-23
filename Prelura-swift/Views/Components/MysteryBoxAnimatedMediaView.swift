import SwiftUI

/// Isometric “box” faces on brand (purple / white) — no kraft brown, so small tiles don’t look like a second raster asset.
private enum MysteryBoxGloss {
    static let topA = Color.white.opacity(0.52)
    static let topB = Color.white.opacity(0.22)
    static let leftA = Color(red: 0.78, green: 0.58, blue: 0.95)
    static let leftB = Color(red: 0.42, green: 0.18, blue: 0.62)
    static let rightA = Color(red: 0.88, green: 0.68, blue: 0.98)
    static let rightB = Color(red: 0.52, green: 0.28, blue: 0.78)
}

/// In-app mystery box art: primary gradient, glossy isometric box, animated “?” on the left face.
struct MysteryBoxAnimatedMediaView: View {
    @State private var questionPulse = false
    @State private var boxBounce = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(
                    colors: [
                        Theme.primaryColor.opacity(0.96),
                        Color(red: 0.43, green: 0.14, blue: 0.64),
                        Color(red: 0.95, green: 0.37, blue: 0.83)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: side * 0.85, height: side * 0.85)
                    .offset(x: side * 0.24, y: -side * 0.3)
                    .blur(radius: side * 0.07)
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: side * 0.72, height: side * 0.72)
                    .offset(x: -side * 0.34, y: side * 0.34)
                    .blur(radius: side * 0.08)

                VStack(spacing: side * 0.03) {
                    VStack(spacing: side * 0.004) {
                        Text("MYSTERY")
                        Text("BOX")
                    }
                    .font(.system(size: side * 0.125, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 2)

                    MysteryBoxPseudo3D(side: side, questionPulse: questionPulse)
                        .offset(y: boxBounce ? -side * 0.016 : side * 0.016)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                questionPulse = false
                boxBounce = false
                withAnimation(.easeInOut(duration: 0.88).repeatForever(autoreverses: true)) {
                    questionPulse = true
                }
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    boxBounce = true
                }
            }
        }
    }
}

/// Normalized points for the visible **left** face of the isometric box (same geometry as the filled left quadrilateral).
private enum MysteryBoxIsoLeftFace {
    static let points: [CGPoint] = [
        CGPoint(x: 0.1, y: 0.24),
        CGPoint(x: 0.5, y: 0.46),
        CGPoint(x: 0.5, y: 0.95),
        CGPoint(x: 0.1, y: 0.72),
    ]
}

private struct MysteryBoxPseudo3D: View {
    let side: CGFloat
    let questionPulse: Bool

    var body: some View {
        let boxSize = side * 0.33
        ZStack {
            PolygonShape(points: [
                CGPoint(x: 0.5, y: 0.04),
                CGPoint(x: 0.9, y: 0.24),
                CGPoint(x: 0.5, y: 0.46),
                CGPoint(x: 0.1, y: 0.24),
            ])
            .fill(
                LinearGradient(
                    colors: [MysteryBoxGloss.topA, MysteryBoxGloss.topB],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            PolygonShape(points: MysteryBoxIsoLeftFace.points)
            .fill(
                LinearGradient(
                    colors: [MysteryBoxGloss.leftA, MysteryBoxGloss.leftB],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            PolygonShape(points: [
                CGPoint(x: 0.9, y: 0.24),
                CGPoint(x: 0.5, y: 0.46),
                CGPoint(x: 0.5, y: 0.95),
                CGPoint(x: 0.9, y: 0.72),
            ])
            .fill(
                LinearGradient(
                    colors: [MysteryBoxGloss.rightA, MysteryBoxGloss.rightB],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Text("?")
                .font(.system(size: boxSize * 0.34, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color.white.opacity(0.72),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .rotation3DEffect(.degrees(-56), axis: (0, 1, 0), anchor: .center, perspective: 0.42)
                .rotation3DEffect(.degrees(5), axis: (1, 0, 0), anchor: .center, perspective: 0.42)
                .offset(x: -boxSize * 0.19, y: boxSize * 0.14)
                .mask(PolygonShape(points: MysteryBoxIsoLeftFace.points))
                .opacity(questionPulse ? 1 : 0.4)
                .scaleEffect(questionPulse ? 1.04 : 0.93)
        }
        .frame(width: boxSize, height: boxSize)
        .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
    }
}

private struct PolygonShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}
