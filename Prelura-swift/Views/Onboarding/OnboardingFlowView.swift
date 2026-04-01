import SwiftUI

/// Welcome onboarding (4 pages) then Try Cart intro (3 gradient pages), then dismiss.
struct OnboardingFlowView: View {
    var onComplete: () -> Void

    @State private var showTryCartIntro = false

    var body: some View {
        Group {
            if showTryCartIntro {
                TryCartOnboardingView(onComplete: onComplete)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                OnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showTryCartIntro = true
                    }
                })
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    OnboardingFlowView(onComplete: {})
}
