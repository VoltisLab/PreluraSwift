//
//  SplashView.swift
//  Prelura-swift
//
//  Splash: white (light) / black (dark) background, WH.svg then WEARHOUSE.svg; "by Voltis Labs" at bottom.
//

import SwiftUI

/// Splash screen: `WearhouseSplashMain` = WH.svg, `WearhouseSplashSub` = WEARHOUSE.svg (vector colours from assets).
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase = .hidden
    @State private var footerVisible = false

    private enum Phase {
        case hidden
        case mainVisible
        case allVisible
        case exiting
    }

    private let mainInDuration: Double = 0.6
    private let subStagger: Double = 0.18
    private let subInDuration: Double = 0.55
    private let holdDuration: Double = 1.2
    private let logoOutDuration: Double = 0.5

    /// `WH.svg` viewBox (137×73).
    private let whViewBoxSize: CGSize = CGSize(width: 137, height: 73)
    /// `WEARHOUSE.svg` viewBox (323×26).
    private let wearhouseViewBoxSize: CGSize = CGSize(width: 323, height: 26)

    /// Cap for the WH mark width.
    private let splashWHMaxWidth: CGFloat = 100

    /// WEARHOUSE wordmark width cap — **not** derived from `splashWHMaxWidth` so resizing the monogram does not shrink the wordmark.
    private let splashWordmarkMaxWidth: CGFloat = 228

    /// Vertical gap between WH and wordmark.
    private let splashMarkToSubSpacing: CGFloat = 42

    private var splashBackground: Color {
        colorScheme == .light ? .white : .black
    }

    private var splashFooterColor: Color {
        colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.7)
    }

    var body: some View {
        ZStack {
            splashBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: splashMarkToSubSpacing) {
                    Image("WearhouseSplashMain")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(
                            whViewBoxSize.width / whViewBoxSize.height,
                            contentMode: .fit
                        )
                        .frame(maxWidth: splashWHMaxWidth)
                        .scaleEffect(mainScale)
                        .opacity(mainOpacity)

                    Image("WearhouseSplashSub")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(
                            wearhouseViewBoxSize.width / wearhouseViewBoxSize.height,
                            contentMode: .fit
                        )
                        .frame(maxWidth: splashWordmarkMaxWidth)
                        .scaleEffect(subScale)
                        .opacity(subOpacity)
                }
                Spacer()
                Text("by Voltis Labs")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(splashFooterColor)
                    .opacity(footerVisible ? 1 : 0)
                    .scaleEffect(footerVisible ? 1 : 0.92)
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            StartupTiming.mark("SplashView.onAppear (animation starting)")
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
