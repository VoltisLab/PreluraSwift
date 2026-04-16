import SwiftUI

/// In-app mystery box art: primary gradient, shipping box only, animated “?” on the box (not the uploaded listing JPEG).
struct MysteryBoxAnimatedMediaView: View {
    @State private var questionPulse = false
    @State private var boxSpin = false
    @State private var boxBounce = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(
                    colors: [
                        Theme.primaryColor,
                        Theme.primaryColor.opacity(0.72),
                        Theme.primaryColor.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                MysteryBoxPseudo3D(side: side, questionPulse: questionPulse)
                .rotation3DEffect(
                    .degrees(boxSpin ? 360 : 0),
                    axis: (x: 0.1, y: 1, z: 0.06),
                    perspective: 0.6
                )
                .offset(y: boxBounce ? -side * 0.018 : side * 0.018)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                questionPulse = false
                boxSpin = false
                boxBounce = false
                withAnimation(.easeInOut(duration: 0.88).repeatForever(autoreverses: true)) {
                    questionPulse = true
                }
                withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
                    boxSpin = true
                }
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    boxBounce = true
                }
            }
        }
    }
}

private struct MysteryBoxPseudo3D: View {
    let side: CGFloat
    let questionPulse: Bool

    var body: some View {
        ZStack {
            PolygonShape(points: [
                CGPoint(x: 0.5, y: 0.04),
                CGPoint(x: 0.9, y: 0.24),
                CGPoint(x: 0.5, y: 0.46),
                CGPoint(x: 0.1, y: 0.24),
            ])
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.95), .white.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            PolygonShape(points: [
                CGPoint(x: 0.1, y: 0.24),
                CGPoint(x: 0.5, y: 0.46),
                CGPoint(x: 0.5, y: 0.95),
                CGPoint(x: 0.1, y: 0.72),
            ])
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.86), .white.opacity(0.66)],
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
                    colors: [.white.opacity(0.92), .white.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: side * 0.33, height: side * 0.33)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .overlay {
            Text("?")
                .font(.system(size: side * 0.11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -side * 0.02)
                .opacity(questionPulse ? 1 : 0.38)
                .scaleEffect(questionPulse ? 1.08 : 0.9)
        }
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
