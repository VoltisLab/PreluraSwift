import UIKit

/// Raster cover when creating a mystery box listing (server still expects product images). Matches in-app purple direction; listing screens use `MysteryBoxAnimatedMediaView` for motion.
enum MysteryBoxListingCoverImage {
    private static let accent = UIColor(red: 171 / 255, green: 40 / 255, blue: 178 / 255, alpha: 1)

    static func makeJPEGData(compressionQuality: CGFloat = 0.85) -> Data? {
        makeImage()?.jpegData(compressionQuality: compressionQuality)
    }

    static func makeImage() -> UIImage? {
        let size = CGSize(width: 900, height: 1170)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [accent.cgColor, accent.withAlphaComponent(0.55).cgColor]
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                c.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            } else {
                accent.setFill()
                c.fill(CGRect(origin: .zero, size: size))
            }

            let side = min(size.width, size.height)
            let symCfg = UIImage.SymbolConfiguration(pointSize: side * 0.22, weight: .semibold)
            if let boxImg = UIImage(systemName: "shippingbox.fill", withConfiguration: symCfg)?.withTintColor(
                .white.withAlphaComponent(0.92),
                renderingMode: .alwaysOriginal
            ) {
                let symSize = boxImg.size
                let symOrigin = CGPoint(
                    x: (size.width - symSize.width) / 2,
                    y: (size.height - symSize.height) / 2 - size.height * 0.02
                )
                boxImg.draw(at: symOrigin)
            }

            let q = "?" as NSString
            let qFont = UIFont.systemFont(ofSize: side * 0.095, weight: .heavy)
            let qAttrs: [NSAttributedString.Key: Any] = [
                .font: qFont,
                .foregroundColor: UIColor(red: 0.38, green: 0.1, blue: 0.52, alpha: 0.92),
            ]
            let qSize = q.size(withAttributes: qAttrs)
            let stampCenter = CGPoint(x: size.width * 0.46, y: size.height * 0.52)
            c.saveGState()
            c.translateBy(x: stampCenter.x, y: stampCenter.y)
            // Skew + slight scale so the glyph reads as printed on the tilted left face of the box.
            c.concatenate(CGAffineTransform(a: 0.88, b: 0.1, c: -0.38, d: 0.94, tx: 0, ty: 0))
            q.draw(at: CGPoint(x: -qSize.width / 2, y: -qSize.height / 2), withAttributes: qAttrs)
            c.restoreGState()
        }
    }
}
