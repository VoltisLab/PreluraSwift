import SwiftUI
import UIKit

/// Merged in the scroll view so long-press reaction UI can place the tray above the bubble (global coordinates).
struct ChatBubbleFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Default quick reactions in the same order as WhatsApp’s tray (👍 ❤️ 😂 😮 😢 🙏 + more).
enum WhatsAppQuickReactions {
    static let primary: [String] = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    /// Extra grid when the user taps ➕ (still common chat reactions).
    static let extended: [String] = [
        "😀", "😃", "😄", "😁", "😆", "🥹", "😅", "🤣", "🥲", "☺️",
        "😊", "😍", "🤩", "😘", "🥰", "😎", "🤔", "😴", "🤯", "😭",
        "👏", "👌", "✌️", "🤝", "💪", "🔥", "✨", "💯", "🎉", "❤️‍🔥",
        "💔", "🙌", "👀", "🤷", "🤦", "💩", "🎊", "⭐", "🏆", "🫶"
    ]
}

/// Full-screen dim + reaction capsule above the bubble; optional delete for own messages.
struct WhatsAppStyleReactionOverlay: View {
    let bubbleFrame: CGRect
    let isOwnMessage: Bool
    let onPickEmoji: (String) -> Void
    let onDelete: (() -> Void)?
    let onDismiss: () -> Void
    @Binding var showMoreEmojis: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeTop = geo.safeAreaInsets.top
            let safeLead = geo.safeAreaInsets.leading
            let safeTrail = geo.safeAreaInsets.trailing
            /// Keep tray inside safe horizontal bounds (fixed 340pt was wider than narrow phones → clipped edges).
            let maxTrayWidth = max(160, w - safeLead - safeTrail - 16)
            let hasFrame = bubbleFrame.width > 1 && bubbleFrame.height > 1
            let half = maxTrayWidth / 2
            let barX = hasFrame
                ? min(max(bubbleFrame.midX, half + 8 + safeLead), w - half - 8 - safeTrail)
                : (w / 2)
            let barY = hasFrame
                ? max(bubbleFrame.minY - 44, safeTop + 72)
                : safeTop + 100

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                VStack(spacing: 14) {
                    reactionCapsule(maxWidth: maxTrayWidth)

                    if isOwnMessage, let onDelete {
                        Button {
                            onDelete()
                            onDismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .medium))
                                Text(L10n.string("Delete"))
                                    .font(.system(size: 17, weight: .regular))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: maxTrayWidth)
                    }
                }
                .frame(maxWidth: maxTrayWidth)
                .position(x: barX, y: barY)
            }
        }
    }

    private func reactionCapsule(maxWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WhatsAppQuickReactions.primary, id: \.self) { emoji in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onPickEmoji(emoji)
                        onDismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 34, height: 40)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showMoreEmojis = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary, .tertiary)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("More reactions"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ExtendedEmojiReactionSheet: View {
    let onPick: (String) -> Void
    let onDismiss: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(WhatsAppQuickReactions.extended, id: \.self) { emoji in
                        Button {
                            onPick(emoji)
                            onDismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.string("Reactions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Done")) { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
