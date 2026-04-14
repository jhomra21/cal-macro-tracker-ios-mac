#if os(iOS)
import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct ScanVisionImage {
    let cgImage: CGImage
    let orientation: CGImagePropertyOrientation
}

struct ScanImageLoading {
    static func loadUIImage(from item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw NSError(
                domain: "ScanImageLoading",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load the selected image."]
            )
        }

        return try loadUIImage(from: data)
    }

    static func loadUIImage(from data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ScanImageLoading", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load the selected image."])
        }

        return image
    }

    static func makeVisionImage(from image: UIImage) throws -> ScanVisionImage {
        ScanVisionImage(
            cgImage: try makeCGImage(from: image),
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
    }
    static func makeCGImage(from image: UIImage) throws -> CGImage {
        if let cgImage = image.cgImage {
            return cgImage
        }

        guard let ciImage = image.ciImage else {
            throw NSError(
                domain: "ScanImageLoading", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare the selected image for scanning."])
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw NSError(
                domain: "ScanImageLoading", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare the selected image for scanning."])
        }

        return cgImage
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
#endif
