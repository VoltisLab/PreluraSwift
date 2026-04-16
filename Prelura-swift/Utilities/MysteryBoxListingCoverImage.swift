import UIKit

/// Raster cover used when creating a mystery box listing (server still expects product images).
enum MysteryBoxListingCoverImage {
    /// Brand purple (#AB28B2) — matches `Theme.primaryColor`.
    private static let accent = UIColor(red: 171 / 255, green: 40 / 255, blue: 178 / 255, alpha: 1)
    private static let accentFillAlpha: CGFloat = 0.16

    static func makeJPEGData(compressionQuality: CGFloat = 0.85) -> Data? {
        makeImage()?.jpegData(compressionQuality: compressionQuality)
    }

    static func makeImage() -> UIImage? {
        let size = CGSize(width: 900, height: 1170)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            // Cardboard field
            UIColor(red: 0.52, green: 0.38, blue: 0.26, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Packing tape
            UIColor(red: 0.88, green: 0.82, blue: 0.64, alpha: 0.88).setFill()
            c.saveGState()
            c.translateBy(x: size.width * 0.5, y: size.height * 0.46)
            c.rotate(by: .pi / 14)
            c.fill(CGRect(x: -size.width, y: -18, width: size.width * 2, height: 36))
            c.restoreGState()

            // Outer 1px grey frame (banner border)
            let outerInset: CGFloat = 24
            let outerRect = CGRect(
                x: outerInset,
                y: outerInset,
                width: size.width - outerInset * 2,
                height: size.height - outerInset * 2
            )
            c.setStrokeColor(UIColor(white: 0.55, alpha: 1).cgColor)
            c.setLineWidth(1)
            c.stroke(outerRect)

            // Center "box" panel: accent tint + cardboard feel
            let boxW: CGFloat = min(420, size.width * 0.52)
            let boxH: CGFloat = boxW * 0.92
            let boxRect = CGRect(
                x: (size.width - boxW) / 2,
                y: (size.height - boxH) / 2 - 20,
                width: boxW,
                height: boxH
            )
            let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: boxW * 0.08).cgPath
            c.addPath(boxPath)
            c.setFillColor(accent.withAlphaComponent(accentFillAlpha).cgColor)
            c.fillPath()
            c.addPath(boxPath)
            c.setStrokeColor(UIColor(white: 0.5, alpha: 0.55).cgColor)
            c.setLineWidth(1)
            c.strokePath()

            // Inner lid line
            let lidY = boxRect.minY + boxH * 0.28
            c.setStrokeColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            c.setLineWidth(1)
            c.move(to: CGPoint(x: boxRect.minX + boxW * 0.08, y: lidY))
            c.addLine(to: CGPoint(x: boxRect.maxX - boxW * 0.08, y: lidY))
            c.strokePath()

            // Large box symbol
            let symCfg = UIImage.SymbolConfiguration(pointSize: boxW * 0.42, weight: .semibold)
            if let boxImg = UIImage(systemName: "shippingbox.fill", withConfiguration: symCfg)?.withTintColor(
                .white.withAlphaComponent(0.92),
                renderingMode: .alwaysOriginal
            ) {
                let symSize = boxImg.size
                let symOrigin = CGPoint(
                    x: boxRect.midX - symSize.width / 2,
                    y: boxRect.midY - symSize.height / 2 - boxH * 0.04
                )
                boxImg.draw(at: symOrigin)
            }

            // Question mark inside the box area
            let q = "?" as NSString
            let qFont = UIFont.systemFont(ofSize: boxW * 0.28, weight: .heavy)
            let qAttrs: [NSAttributedString.Key: Any] = [
                .font: qFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.42),
            ]
            let qSize = q.size(withAttributes: qAttrs)
            q.draw(
                at: CGPoint(
                    x: boxRect.midX - qSize.width / 2,
                    y: boxRect.midY - qSize.height / 2 + boxH * 0.1
                ),
                withAttributes: qAttrs
            )

            let ribbon = "MYSTERY BOX" as NSString
            let ribbonAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            ]
            let ribbonSize = ribbon.size(withAttributes: ribbonAttrs)
            ribbon.draw(
                at: CGPoint(x: (size.width - ribbonSize.width) / 2, y: size.height * 0.76),
                withAttributes: ribbonAttrs
            )
        }
    }
}
