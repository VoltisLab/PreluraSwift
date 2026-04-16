import SwiftUI

/// In-app mystery box art: primary gradient, shipping box only, animated “?” on the box (not the uploaded listing JPEG).
struct MysteryBoxAnimatedMediaView: View {
    @State private var questionPulse = false

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
                ZStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: side * 0.28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    Text("?")
                        .font(.system(size: side * 0.11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: -side * 0.018)
                        .opacity(questionPulse ? 1 : 0.38)
                        .scaleEffect(questionPulse ? 1.08 : 0.9)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                questionPulse = false
                withAnimation(.easeInOut(duration: 0.88).repeatForever(autoreverses: true)) {
                    questionPulse = true
                }
            }
        }
    }
}
