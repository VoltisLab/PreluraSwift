import SwiftUI

/// Curved tail under the card; tip points to the tag anchor. Sides use quadratic curves (speech-bubble style).
private struct LookbookFeedTagCurvedTail: Shape {
    /// X position of tip in the shape's coordinate space (same as parent width units).
    var tipX: CGFloat

    func path(in rect: CGRect) -> Path {
        let h = rect.height
        let w = rect.width
        let tx = min(max(tipX, 10), w - 10)
        let baseHalf: CGFloat = 14
        let bl = CGPoint(x: tx - baseHalf, y: 0)
        let br = CGPoint(x: tx + baseHalf, y: 0)
        let tip = CGPoint(x: tx, y: h)
        var p = Path()
        p.move(to: bl)
        p.addQuadCurve(to: tip, control: CGPoint(x: bl.x + (tip.x - bl.x) * 0.45, y: h * 0.55))
        p.addQuadCurve(to: br, control: CGPoint(x: br.x + (tip.x - br.x) * 0.45, y: h * 0.55))
        p.closeSubpath()
        return p
    }
}

/// Product title callout for the lookbook feed: full title (wraps), no orange pin - tail aims at the saved anchor.
struct LookbookFeedProductTagCallout: View {
    let snapshot: LookbookProductSnapshot
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let anchorX: CGFloat
    let anchorY: CGFloat
    let onTap: () -> Void

    @State private var cardSize: CGSize = .zero

    private let margin: CGFloat = 8
    private let tailHeight: CGFloat = 12
    private let thumbSize: CGFloat = 36

    private var maxCardWidth: CGFloat {
        min(300, max(120, imageWidth - margin * 2))
    }

    private var bubbleFill: Color { Color(white: 0.12).opacity(0.94) }

    private func bubbleLeftX(cardWidth: CGFloat) -> CGFloat {
        let cw = min(cardWidth, maxCardWidth)
        let ideal = anchorX - cw / 2
        return min(max(ideal, margin), imageWidth - margin - cw)
    }

    private var tipXInBubbleSpace: CGFloat {
        let left = bubbleLeftX(cardWidth: cardSize.width > 0 ? cardSize.width : maxCardWidth)
        let cw = cardSize.width > 0 ? cardSize.width : maxCardWidth
        return min(max(anchorX - left, 12), cw - 12)
    }

    private var topY: CGFloat {
        let ch = cardSize.height > 0 ? cardSize.height : 48
        return anchorY - ch - tailHeight
    }

    private var bubbleLeft: CGFloat {
        bubbleLeftX(cardWidth: cardSize.width > 0 ? cardSize.width : maxCardWidth)
    }

    var body: some View {
        Button(action: {
            HapticManager.tap()
            onTap()
        }) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    lookbookFeedTagThumb
                    Text(snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: maxCardWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(bubbleFill)
                )
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: LookbookFeedTagCardSizeKey.self, value: g.size)
                    }
                )

                LookbookFeedTagCurvedTail(tipX: tipXInBubbleSpace)
                    .fill(bubbleFill)
                    .frame(width: cardSize.width > 0 ? cardSize.width : maxCardWidth, height: tailHeight)
            }
            .frame(width: cardSize.width > 0 ? cardSize.width : nil, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(snapshot.title)
        .onPreferenceChange(LookbookFeedTagCardSizeKey.self) { cardSize = $0 }
        .offset(x: bubbleLeft, y: topY)
        .frame(width: imageWidth, height: imageHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private var lookbookFeedTagThumb: some View {
        Group {
            if let url = lookbookFeedProductTagCalloutImageURL(snapshot) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure, .empty:
                        lookbookFeedTagThumbPlaceholder
                    @unknown default:
                        lookbookFeedTagThumbPlaceholder
                    }
                }
            } else {
                lookbookFeedTagThumbPlaceholder
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var lookbookFeedTagThumbPlaceholder: some View {
        Rectangle()
            .fill(Theme.Colors.secondaryBackground)
            .overlay(Image(systemName: "photo").font(.caption).foregroundStyle(Theme.Colors.secondaryText))
    }
}

private func lookbookFeedProductTagCalloutImageURL(_ snapshot: LookbookProductSnapshot) -> URL? {
    let raw = snapshot.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !raw.isEmpty, let u = URL(string: raw), u.scheme != nil else { return nil }
    return u
}

private struct LookbookFeedTagCardSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
