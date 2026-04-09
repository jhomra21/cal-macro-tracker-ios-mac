#if os(iOS)
import UIKit
import Vision

enum BarcodeScanConfiguration {
    static let packagedFoodSymbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce]
}

enum BarcodeImageScannerError: LocalizedError {
    case noBarcodeFound

    var errorDescription: String? {
        switch self {
        case .noBarcodeFound:
            "No barcode was found in that image."
        }
    }
}

struct BarcodeImageScanner {
    func scanBarcode(from image: UIImage) async throws -> String {
        let visionImage = try ScanImageLoading.makeVisionImage(from: image)
        let request = VNDetectBarcodesRequest()
        request.symbologies = BarcodeScanConfiguration.packagedFoodSymbologies

        let handler = VNImageRequestHandler(cgImage: visionImage.cgImage, orientation: visionImage.orientation)
        try handler.perform([request])

        guard
            let barcode = request.results?
                .compactMap({ $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty })
        else {
            throw BarcodeImageScannerError.noBarcodeFound
        }

        return barcode
    }
}
#endif
