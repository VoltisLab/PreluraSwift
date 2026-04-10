//
//  SplashView.swift
//  Prelura-swift
//
//  Splash: black background, WH monogram SVG then WEARHOUSE sub-mark (staggered fade/scale); "by Voltis Labs" at bottom.
//

import SwiftUI

/// Splash screen: centered Wearhouse mark from asset SVGs (main WH, then sub wordmark).
struct SplashView: View {
    var onFinish: () -> Void

    @State private var phase: Phase = .hidden
    @State private var footerVisible = false

    private enum Phase {
        case hidden
        case mainVisible
        case allVisible
        case exiting
    }

    /// First beat: WH monogram (matches prior single-logo in duration).
    private let mainInDuration: Double = 0.6
    /// Pause before sub-mark animates in.
    private let subStagger: Double = 0.18
    /// Second beat: WEARHOUSE sub-logo.
    private let subInDuration: Double = 0.55
    private let holdDuration: Double = 1.2
    private let logoOutDuration: Double = 0.5

    /// Horizontal cap for the WH monogram (vector scales down proportionally).
    private let splashMarkMaxWidth: CGFloat = 215.6 * 1.1 // +10% from prior 215.6

    /// `WearhouseSplashMain.svg` viewBox (409×218).
    private let whMonogramViewBoxSize: CGSize = CGSize(width: 409, height: 218)
    /// `WearhouseSplashSub.svg` viewBox (246×22).
    private let subWordmarkViewBoxSize: CGSize = CGSize(width: 246, height: 22)

    /// Rendered WH height at `splashMarkMaxWidth` (fit, same aspect as viewBox).
    private var splashMainRenderedHeight: CGFloat {
        splashMarkMaxWidth * (whMonogramViewBoxSize.height / whMonogramViewBoxSize.width)
    }

    /// WEARHOUSE sub-mark: **height = WH height ÷ 10** (WH : sub = 10 : 1).
    private var splashSubMarkMaxHeight: CGFloat {
        splashMainRenderedHeight / 10
    }

    /// Vertical gap between monogram and sub-logo (~proportion of combined Figma frame).
    private let splashMarkToSubSpacing: CGFloat = 26

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: splashMarkToSubSpacing) {
                    Image("WearhouseSplashMain")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(
                            whMonogramViewBoxSize.width / whMonogramViewBoxSize.height,
                            contentMode: .fit
                        )
                        .frame(maxWidth: splashMarkMaxWidth)
                        .scaleEffect(mainScale)
                        .opacity(mainOpacity)

                    Image("WearhouseSplashSub")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(
                            subWordmarkViewBoxSize.width / subWordmarkViewBoxSize.height,
                            contentMode: .fit
                        )
                        .frame(maxHeight: splashSubMarkMaxHeight)
                        .scaleEffect(subScale)
                        .opacity(subOpacity)
                }
                Spacer()
                Text("by Voltis Labs")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(footerVisible ? 1 : 0)
                    .scaleEffect(footerVisible ? 1 : 0.92)
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimation()
        }
    }

    private var mainOpacity: Double {
        switch phase {
        case .hidden: return 0
        case .mainVisible, .allVisible: return 1
        case .exiting: return 0
        }
    }

    private var mainScale: CGFloat {
        switch phase {
        case .hidden: return 0.92
        case .mainVisible, .allVisible: return 1.0
        case .exiting: return 1.04
        }
    }

    private var subOpacity: Double {
        switch phase {
        case .hidden, .mainVisible: return 0
        case .allVisible: return 1
        case .exiting: return 0
        }
    }

    private var subScale: CGFloat {
        switch phase {
        case .hidden, .mainVisible: return 0.92
        case .allVisible: return 1.0
        case .exiting: return 1.04
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: mainInDuration)) {
            phase = .mainVisible
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + mainInDuration + subStagger) {
            withAnimation(.easeInOut(duration: subInDuration)) {
                phase = .allVisible
            }
        }
        let allInDone = mainInDuration + subStagger + subInDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + allInDone) {
            withAnimation(.easeInOut(duration: mainInDuration)) {
                footerVisible = true
            }
        }
        let totalBeforeExit = allInDone + holdDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalBeforeExit) {
            withAnimation(.easeInOut(duration: logoOutDuration)) {
                phase = .exiting
                footerVisible = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + totalBeforeExit + logoOutDuration) {
            onFinish()
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}
