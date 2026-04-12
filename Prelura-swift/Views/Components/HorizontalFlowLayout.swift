import SwiftUI

/// Lays subviews out left-to-right, wrapping to the next row when width exceeds the proposed width (tag / chip rows).
struct HorizontalFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            if x + ideal.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: ideal))
            lineHeight = max(lineHeight, ideal.height)
            x += ideal.width + horizontalSpacing
        }

        let contentWidth = (frames.map(\.maxX).max() ?? 0)
        let contentHeight = y + lineHeight
        let width: CGFloat
        if maxWidth.isFinite, maxWidth < .greatestFiniteMagnitude {
            width = maxWidth
        } else {
            width = contentWidth
        }
        return (CGSize(width: width, height: contentHeight), frames)
    }
}
