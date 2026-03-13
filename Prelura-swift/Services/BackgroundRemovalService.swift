//
//  BackgroundRemovalService.swift
//  Prelura-swift
//
//  Uses Vision VNGeneratePersonSegmentationRequest and Core Image blendWithMask
//  to remove background and composite subject onto a theme background.
//

import Foundation
import Vision
import CoreImage
import UIKit

enum BackgroundRemovalError: Error {
    case noPersonInImage
    case segmentationFailed
    case compositeFailed
}

/// Theme background for shop photos (no custom upload – app-provided only).
struct ThemeBackground: Identifiable {
    let id: String
    let name: String
    let colorTop: UIColor
    let colorBottom: UIColor?

    init(id: String, name: String, color: UIColor) {
        self.id = id
        self.name = name
        self.colorTop = color
        self.colorBottom = nil
    }

    init(id: String, name: String, gradientTop: UIColor, gradientBottom: UIColor) {
        self.id = id
        self.name = name
        self.colorTop = gradientTop
        self.colorBottom = gradientBottom
    }

    func ciImage(size: CGSize) -> CIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            if let bottom = colorBottom {
                let colors = [colorTop.cgColor, bottom.cgColor]
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) else { return }
                ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            } else {
                colorTop.setFill()
                ctx.cgContext.fill(rect)
            }
        }
        return CIImage(image: image)
    }
}

extension ThemeBackground {
    static let all: [ThemeBackground] = [
        ThemeBackground(id: "white", name: "Clean White", color: UIColor(white: 0.98, alpha: 1)),
        ThemeBackground(id: "grey", name: "Soft Grey", color: UIColor(white: 0.94, alpha: 1)),
        ThemeBackground(id: "beige", name: "Warm Beige", color: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)),
        ThemeBackground(id: "coolgrey", name: "Cool Grey", color: UIColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1)),
        ThemeBackground(id: "mint", name: "Light Mint", gradientTop: UIColor(red: 0.85, green: 0.97, blue: 0.92, alpha: 1), gradientBottom: UIColor(red: 0.75, green: 0.95, blue: 0.88, alpha: 1)),
        ThemeBackground(id: "lavender", name: "Soft Lavender", gradientTop: UIColor(red: 0.95, green: 0.92, blue: 0.98, alpha: 1), gradientBottom: UIColor(red: 0.90, green: 0.85, blue: 0.96, alpha: 1)),
        ThemeBackground(id: "blush", name: "Blush", gradientTop: UIColor(red: 1, green: 0.95, blue: 0.95, alpha: 1), gradientBottom: UIColor(red: 0.98, green: 0.90, blue: 0.92, alpha: 1)),
        ThemeBackground(id: "sky", name: "Soft Sky", gradientTop: UIColor(red: 0.88, green: 0.94, blue: 1, alpha: 1), gradientBottom: UIColor(red: 0.80, green: 0.90, blue: 0.98, alpha: 1)),
    ]
}

@MainActor
final class BackgroundRemovalService {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Removes background from image using person segmentation, then composites onto the theme background.
    /// Works best with photos containing a person (e.g. clothing on model). If no person is detected, returns original composited on theme.
    func removeBackground(from image: UIImage, theme: ThemeBackground) async throws -> UIImage {
        guard let inputCIImage = CIImage(image: image) else { throw BackgroundRemovalError.compositeFailed }
        let size = inputCIImage.extent.size
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(ciImage: inputCIImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            return try compositeFullImage(inputCIImage, theme: theme, size: size)
        }

        let maskBuffer = result.pixelBuffer
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)

        guard let background = theme.ciImage(size: size) else {
            return try compositeFullImage(inputCIImage, theme: theme, size: size)
        }

        let maskExt = maskImage.extent
        let scaleX = size.width / maskExt.width
        let scaleY = size.height / maskExt.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(translationX: -maskExt.minX, y: -maskExt.minY).scaledBy(x: scaleX, y: scaleY))
        let blend = CIFilter(name: "CIBlendWithMask")
        blend?.setValue(inputCIImage, forKey: kCIInputImageKey)
        blend?.setValue(background, forKey: kCIInputBackgroundImageKey)
        blend?.setValue(scaledMask, forKey: kCIInputMaskImageKey)

        guard let output = blend?.outputImage else {
            return try compositeFullImage(inputCIImage, theme: theme, size: size)
        }

        let cropRect = output.extent
        guard let cgImage = context.createCGImage(output, from: cropRect) else {
            throw BackgroundRemovalError.compositeFailed
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func compositeFullImage(_ input: CIImage, theme: ThemeBackground, size: CGSize) throws -> UIImage {
        guard let background = theme.ciImage(size: size) else { throw BackgroundRemovalError.compositeFailed }
        let blend = CIFilter(name: "CISourceOverCompositing")
        blend?.setValue(input, forKey: kCIInputImageKey)
        blend?.setValue(background, forKey: kCIInputBackgroundImageKey)
        // CISourceOverCompositing: backgroundImage = bottom, inputImage = on top
        guard let output = blend?.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            throw BackgroundRemovalError.compositeFailed
        }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }
}
