import SwiftUI

/// In-app mystery box art: primary gradient, shipping box only, animated “?” on the box (not the uploaded listing JPEG).
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

                VStack(spacing: side * 0.035) {
                    VStack(spacing: side * 0.008) {
                        Text("MYSTERY")
                        Text("BOX")
                    }
                    .font(.system(size: side * 0.09, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)

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
