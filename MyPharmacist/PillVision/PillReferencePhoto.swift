//
//  PillReferencePhoto.swift
//  MyPharmacist
//

import CoreGraphics
import CoreImage
import UIKit
import Vision

/// Turns a photo of one tablet into the picture scanned pills are compared with: the
/// tablet alone, cut out with Vision's subject lifting, at most `maxSide` pixels.
nonisolated enum PillReferencePhoto {
    enum Failure: Error, Equatable {
        /// Nothing in the photo stands out as a tablet.
        case noPill
        /// The photo couldn't be read at all.
        case unreadable

        /// What to tell the person.
        var message: String {
            switch self {
            case .noPill: "Couldn't find the pill. Put it alone on a plain surface and try again."
            case .unreadable: "Couldn't read this photo. Please try another."
            }
        }
    }

    static let maxSide = 512
    /// Things covering more of the photo than this are what the tablet lies on.
    private static let surfaceShare = 0.5
    private static let context = CIContext()

    static func make(from photo: UIImage) -> Result<CGImage, Failure> {
        guard let image = upright(photo, maxSide: 2048) else { return .failure(.unreadable) }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
        } catch {
            #if targetEnvironment(simulator)
            // Vision's subject lifting doesn't run in the Simulator: keep the middle.
            return middleSquare(of: image).map { .success($0) } ?? .failure(.unreadable)
            #else
            return .failure(.unreadable)
            #endif
        }
        guard let observation = request.results?.first else { return .failure(.noPill) }

        // The tablet: the largest thing that isn't the surface it lies on.
        let labels = PillFinder.labels(of: observation.instanceMask)
        let measured = InstanceBoxes.boxes(labels: labels.values, width: labels.width, height: labels.height)
        guard let instance = measured.filter({ $0.value.area < surfaceShare }).max(by: { $0.value.area < $1.value.area })?.key,
              let masked = try? observation.generateMaskedImage(ofInstances: [instance], from: handler, croppedToInstancesExtent: true)
        else { return .failure(.noPill) }
        let cutOut = CIImage(cvPixelBuffer: masked)
        guard let cgImage = context.createCGImage(cutOut, from: cutOut.extent),
              let scaled = scaled(cgImage, maxSide: maxSide) else { return .failure(.unreadable) }
        return .success(scaled)
    }

    /// The photo drawn upright (camera photos carry their turn separately), at most
    /// `maxSide` on its longer side.
    static func upright(_ photo: UIImage, maxSide: CGFloat) -> CGImage? {
        let scale = min(1, maxSide / max(photo.size.width, photo.size.height, 1))
        let size = CGSize(width: (photo.size.width * scale).rounded(), height: (photo.size.height * scale).rounded())
        guard size.width >= 1, size.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private static func scaled(_ image: CGImage, maxSide: Int) -> CGImage? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    #if targetEnvironment(simulator)
    private static func middleSquare(of image: CGImage) -> CGImage? {
        let side = min(image.width, image.height) / 2
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        return image.cropping(to: rect).flatMap { scaled($0, maxSide: maxSide) }
    }
    #endif
}
