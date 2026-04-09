struct NutritionLabelRecognizedText {
    let lines: [String]
}

#if os(iOS)
import UIKit
import Vision

struct NutritionLabelTextRecognizer {
    private struct RecognizedLine {
        let text: String
        let topEdge: CGFloat
        let leadingEdge: CGFloat
    }

    private let rowTolerance: CGFloat = 0.02

    func recognizeText(in image: UIImage) async throws -> NutritionLabelRecognizedText {
        let visionImage = try ScanImageLoading.makeVisionImage(from: image)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: visionImage.cgImage, orientation: visionImage.orientation)
        try handler.perform([request])

        let lines = orderedLines(from: request.results ?? [])

        return NutritionLabelRecognizedText(lines: lines)
    }

    private func orderedLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        observations
            .compactMap(recognizedLine(from:))
            .sorted(by: areInReadingOrder(_:_:))
            .map(\.text)
    }

    private func recognizedLine(from observation: VNRecognizedTextObservation) -> RecognizedLine? {
        guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
            text.isEmpty == false
        else {
            return nil
        }

        return RecognizedLine(
            text: text,
            topEdge: observation.boundingBox.maxY,
            leadingEdge: observation.boundingBox.minX
        )
    }

    private func areInReadingOrder(_ lhs: RecognizedLine, _ rhs: RecognizedLine) -> Bool {
        if abs(lhs.topEdge - rhs.topEdge) > rowTolerance {
            return lhs.topEdge > rhs.topEdge
        }

        return lhs.leadingEdge < rhs.leadingEdge
    }
}
#else
import Foundation

struct NutritionLabelTextRecognizer {
    func recognizeText(in imageData: Data) async throws -> NutritionLabelRecognizedText {
        throw NSError(
            domain: "NutritionLabelTextRecognizer", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Nutrition label text recognition is only available on iPhone builds."])
    }
}
#endif
