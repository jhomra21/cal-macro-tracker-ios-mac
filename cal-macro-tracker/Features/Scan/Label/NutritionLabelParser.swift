import Foundation

struct NutritionLabelParseResult {
    let draft: FoodDraft
    let notes: [String]
}

enum NutritionLabelParser {
    static func parse(recognizedText: NutritionLabelRecognizedText) -> NutritionLabelParseResult {
        let parsedText = ParsedLabelText(recognizedText: recognizedText)
        let detectedServingDescription = servingDescription(from: parsedText)
        let detectedNutrients = detectedNutrients(from: parsedText.nutritionLines)

        var draft = FoodDraft()
        draft.source = .labelScan
        draft.name = inferredName(from: parsedText)
        draft.servingDescription = detectedServingDescription ?? draft.servingDescription
        draft.gramsPerServing = gramsPerServing(from: parsedText)
        draft.caloriesPerServing = detectedNutrients.calories ?? 0
        draft.proteinPerServing = detectedNutrients.protein ?? 0
        draft.fatPerServing = detectedNutrients.fat ?? 0
        draft.carbsPerServing = detectedNutrients.carbs ?? 0
        draft.saveAsCustomFood = true

        return NutritionLabelParseResult(
            draft: draft,
            notes: notes(
                for: draft,
                servingDescriptionDetected: detectedServingDescription != nil,
                detectedNutrients: detectedNutrients
            )
        )
    }

    private static func detectedNutrients(from lines: [String]) -> DetectedNutrients {
        DetectedNutrients(
            calories: nutrientValue(
                matching: ["^\\s*calories\\b(?!\\s+from\\s+fat\\b)[^\\d]*(\\d+(?:\\.\\d+)?)"],
                in: lines
            ),
            protein: nutrientValue(
                matching: ["^\\s*protein\\b[^\\d]*(\\d+(?:\\.\\d+)?)"],
                in: lines
            ),
            fat: nutrientValue(
                matching: [
                    "^\\s*total\\s+fat\\b[^\\d]*(\\d+(?:\\.\\d+)?)",
                    "^\\s*fat\\b[^\\d]*(\\d+(?:\\.\\d+)?)"
                ],
                in: lines
            ),
            carbs: nutrientValue(
                matching: [
                    "^\\s*total\\s+carbohydrates?\\b[^\\d]*(\\d+(?:\\.\\d+)?)",
                    "^\\s*carbohydrates?\\b[^\\d]*(\\d+(?:\\.\\d+)?)",
                    "^\\s*carbs?\\b[^\\d]*(\\d+(?:\\.\\d+)?)"
                ],
                in: lines
            )
        )
    }

    private static func inferredName(from parsedText: ParsedLabelText) -> String {
        let candidates = parsedText.lines[..<parsedText.nutritionBlockStartIndex]
            .filter { line in
                isPotentialProductName(line)
            }
        return candidates.last ?? ""
    }

    private static func servingDescription(from parsedText: ParsedLabelText) -> String? {
        for (index, line) in parsedText.lines.enumerated() {
            guard isServingSizeLine(line) else { continue }

            let continuation = servingSizeContinuation(after: index, in: parsedText.lines)
            if let inlineValue = servingSizeValue(from: line), inlineValue.isEmpty == false {
                if let continuation {
                    return "\(line) \(continuation)"
                }
                return line
            }

            if let continuation {
                return "Serving size \(continuation)"
            }
        }

        return nil
    }

    private static func gramsPerServing(from parsedText: ParsedLabelText) -> Double? {
        for index in parsedText.lines.indices where isServingSizeLine(parsedText.lines[index]) {
            for candidate in servingSizeCandidateTexts(at: index, in: parsedText.lines) {
                if let grams = servingGrams(in: candidate) {
                    return grams
                }
            }
        }

        return nil
    }

    private static func nutrientValue(matching patterns: [String], in lines: [String]) -> Double? {
        for index in lines.indices {
            for candidate in nutrientCandidateTexts(at: index, in: lines) {
                for pattern in patterns {
                    if let value = firstMatch(in: candidate, pattern: pattern) {
                        return value
                    }
                }
            }
        }

        return nil
    }

    private static func servingGrams(in text: String) -> Double? {
        firstMatch(in: text, pattern: "\\((\\d+(?:\\.\\d+)?)\\s*g\\)")
            ?? firstMatch(in: text, pattern: "\\b(\\d+(?:\\.\\d+)?)\\s*g\\b")
    }

    private static func servingSizeContinuation(after index: Int, in lines: [String]) -> String? {
        let nextIndex = lines.index(after: index)
        guard nextIndex < lines.endIndex else { return nil }

        let continuation = lines[nextIndex]
        return isServingSizeContinuation(continuation) ? continuation : nil
    }

    private static func servingSizeCandidateTexts(at index: Int, in lines: [String]) -> [String] {
        let line = lines[index]
        if let continuation = servingSizeContinuation(after: index, in: lines) {
            return [line, "\(line) \(continuation)"]
        }

        return [line]
    }

    private static func nutrientCandidateTexts(at index: Int, in lines: [String]) -> [String] {
        let line = lines[index]
        guard containsPattern("\\d", in: line) == false else { return [line] }

        let nextIndex = lines.index(after: index)
        guard nextIndex < lines.endIndex else { return [line] }

        let nextLine = lines[nextIndex]
        guard isNutrientValueContinuation(nextLine) else { return [line] }

        return ["\(line) \(nextLine)"]
    }
}
