//
//  SplashView.swift
//  Prelura-swift
//
//  Splash: black background; video plays inside text (text used as mask, no fill). Text animates in and out.
//

import SwiftUI
import AVKit

/// Placeholder text for splash (video shows inside this text shape).
private let kSplashText = "PRELURA"

/// Splash screen: black background; video plays only inside the text (text as mask, unfilled). Text animates in and out.
struct SplashView: View {
    var onFinish: () -> Void

    @State private var phase: Phase = .hidden
    @State private var videoURL: URL?

    private enum Phase {
        case hidden
        case visible
        case exiting
    }

    private let logoInDuration: Double = 0.5
    private let holdDuration: Double = 1.2
    private let logoOutDuration: Double = 0.4

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            videoInsideTextLayer
        }
        .ignoresSafeArea()
        .onAppear {
            loadVideo()
            startAnimation()
        }
    }

    /// Video layer masked by text so the video plays only inside the letter shapes (text is not filled with color).
    @ViewBuilder
    private var videoInsideTextLayer: some View {
        if let url = videoURL {
            LoopingVideoPlayerView(url: url)
                .mask(splashTextMask)
                .scaleEffect(phase == .hidden ? 0.8 : (phase == .exiting ? 1.1 : 1.0))
                .opacity(phase == .hidden ? 0 : (phase == .exiting ? 0 : 1))
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var splashTextMask: some View {
        Text(kSplashText)
            .font(.system(size: 72, weight: .bold))
            .tracking(4)
    }

    private func loadVideo() {
        if let url = Bundle.main.url(forResource: "splash", withExtension: "mp4", subdirectory: nil) {
            videoURL = url
        } else if let url = Bundle.main.url(forResource: "Splash", withExtension: "mp4", subdirectory: nil) {
            videoURL = url
        } else {
            videoURL = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil)?.first
        }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: logoInDuration)) {
            phase = .visible
        }
        let total = logoInDuration + holdDuration + logoOutDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + logoInDuration + holdDuration) {
            withAnimation(.easeIn(duration: logoOutDuration)) {
                phase = .exiting
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            onFinish()
        }
    }
}

// MARK: - Looping video for splash (muted, aspect fill)
private struct LoopingVideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let view = SplashPlayerView()
        view.setupPlayer(url: url)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class SplashPlayerView: UIView {
    private var playerLooper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }

    func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        (layer as? AVPlayerLayer)?.player = queuePlayer
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
        queuePlayer.play()
    }
}

#Preview {
    SplashView(onFinish: {})
}
