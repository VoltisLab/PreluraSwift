import UIKit

/// Raster cover used when creating a mystery box listing (server still expects product images).
enum MysteryBoxListingCoverImage {
    static func makeJPEGData(compressionQuality: CGFloat = 0.85) -> Data? {
        makeImage()?.jpegData(compressionQuality: compressionQuality)
    }

    static func makeImage() -> UIImage? {
        let size = CGSize(width: 900, height: 1170)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.52, green: 0.38, blue: 0.26, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: size))

            UIColor(red: 0.88, green: 0.82, blue: 0.64, alpha: 0.88).setFill()
            c.saveGState()
            c.translateBy(x: size.width * 0.5, y: size.height * 0.48)
            c.rotate(by: .pi / 14)
            c.fill(CGRect(x: -size.width, y: -20, width: size.width * 2, height: 40))
            c.restoreGState()

            UIColor.black.withAlphaComponent(0.1).setStroke()
            c.setLineWidth(2)
            c.stroke(CGRect(x: 36, y: 36, width: size.width - 72, height: size.height - 72))

            let markAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 200, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.2),
            ]
            let mark = "?" as NSString
            let markSize = mark.size(withAttributes: markAttrs)
            mark.draw(
                at: CGPoint(x: (size.width - markSize.width) / 2, y: (size.height - markSize.height) / 2 - 36),
                withAttributes: markAttrs
            )

            let ribbon = "MYSTERY BOX" as NSString
            let ribbonAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            ]
            let ribbonSize = ribbon.size(withAttributes: ribbonAttrs)
            ribbon.draw(
                at: CGPoint(x: (size.width - ribbonSize.width) / 2, y: size.height * 0.7),
                withAttributes: ribbonAttrs
            )
        }
    }
}
