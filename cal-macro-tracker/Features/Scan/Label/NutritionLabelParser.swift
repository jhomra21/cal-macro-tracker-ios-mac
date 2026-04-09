import Foundation

struct NutritionLabelParseResult {
    let draft: FoodDraft
    let notes: [String]
}

enum NutritionLabelParser {
    private struct DetectedNutrients {
        let calories: Double?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
    }

    private struct ParsedLabelText {
        let lines: [String]
        let nutritionBlockStartIndex: Int
        let nutritionLines: [String]

        init(recognizedText: NutritionLabelRecognizedText) {
            self.lines = recognizedText.lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            self.nutritionBlockStartIndex =
                lines.firstIndex { line in
                    isNutritionBlockLine(line)
                } ?? lines.count
            if nutritionBlockStartIndex < lines.count {
                self.nutritionLines = Array(lines[nutritionBlockStartIndex...])
            } else {
                self.nutritionLines = []
            }
        }
    }

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

    private static func firstMatch(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Double(text[valueRange])
    }

    private static func servingGrams(in text: String) -> Double? {
        firstMatch(in: text, pattern: "\\((\\d+(?:\\.\\d+)?)\\s*g\\)")
            ?? firstMatch(in: text, pattern: "\\b(\\d+(?:\\.\\d+)?)\\s*g\\b")
    }

    private static func servingSizeValue(from line: String) -> String? {
        firstTextMatch(in: line, pattern: "\\bserving\\s*size\\b[:\\s-]*(.+)$")
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

    private static func firstTextMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let matchedText = text[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return matchedText.isEmpty ? nil : matchedText
    }

    private static func isPotentialProductName(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        guard line.rangeOfCharacter(from: .letters) != nil else { return false }
        return isPackagingCopyLine(line) == false
    }

    private static func isServingSizeLine(_ line: String) -> Bool {
        containsPattern("\\bserving\\s*size\\b", in: line)
    }

    private static func isServingSizeContinuation(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        return line.rangeOfCharacter(from: .letters) != nil || line.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private static func isNutrientValueContinuation(_ line: String) -> Bool {
        guard isNutritionBlockLine(line) == false else { return false }
        return containsPattern("^\\s*[<~]?\\s*\\d", in: line)
    }

    private static func isNutritionBlockLine(_ line: String) -> Bool {
        isNutritionHeader(line) || isNutritionMetadata(line) || isLikelyNutrientLine(line)
    }

    private static func isNutritionHeader(_ line: String) -> Bool {
        containsPattern("\\bnutrition\\b", in: line) || containsPattern("\\bfacts\\b", in: line)
    }

    private static func isNutritionMetadata(_ line: String) -> Bool {
        containsPattern("\\bserving\\s*size\\b", in: line)
            || containsPattern("\\bservings?\\s+per\\s+container\\b", in: line)
            || containsPattern("\\bamount\\s+per\\s+serving\\b", in: line)
            || containsPattern("%\\s*daily\\s+value", in: line)
    }

    private static func isLikelyNutrientLine(_ line: String) -> Bool {
        let startsWithNutrientLabel =
            containsPattern("^\\s*calories\\b", in: line)
            || containsPattern("^\\s*protein\\b", in: line)
            || containsPattern("^\\s*total\\s+fat\\b", in: line)
            || containsPattern("^\\s*fat\\b", in: line)
            || containsPattern("^\\s*total\\s+carbohydrates?\\b", in: line)
            || containsPattern("^\\s*carbohydrates?\\b", in: line)
            || containsPattern("^\\s*carbs?\\b", in: line)
            || containsPattern("^\\s*sodium\\b", in: line)
            || containsPattern("^\\s*cholesterol\\b", in: line)
            || containsPattern("^\\s*fiber\\b", in: line)
            || containsPattern("^\\s*sugars?\\b", in: line)
            || containsPattern("^\\s*potassium\\b", in: line)
            || containsPattern("^\\s*calcium\\b", in: line)
            || containsPattern("^\\s*iron\\b", in: line)

        guard startsWithNutrientLabel else { return false }

        return containsPattern("\\d", in: line) || isPlainNutrientLabelLine(line)
    }

    private static func isPlainNutrientLabelLine(_ line: String) -> Bool {
        containsPattern(
            "^\\s*(?:calories|protein|total\\s+fat|fat|total\\s+carbohydrates?|carbohydrates?|carbs?|sodium|cholesterol|fiber|sugars?|potassium|calcium|iron)\\s*[:*]*\\s*$",
            in: line
        )
    }

    private static func isPackagingCopyLine(_ line: String) -> Bool {
        containsPattern("^\\s*net\\s+wt\\b", in: line)
            || containsPattern("^\\s*keep\\s+(?:frozen|refrigerated|cold)\\b", in: line)
            || containsPattern("^\\s*(?:perishable|shake\\s+well|best\\s+by|sell\\s+by|distributed\\s+by|ingredients\\b)", in: line)
    }

    private static func containsPattern(_ pattern: String, in line: String) -> Bool {
        line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func notes(
        for draft: FoodDraft,
        servingDescriptionDetected: Bool,
        detectedNutrients: DetectedNutrients
    ) -> [String] {
        var notes: [String] = []

        if draft.name.isEmpty {
            notes.append("OCR could not confidently detect the food name. Add it before saving.")
        }

        if servingDescriptionDetected == false {
            notes.append("Serving size was not confidently detected. Review the label details before saving.")
        }

        if draft.gramsPerServing == nil {
            notes.append("Serving grams were not confidently detected. Gram-based logging will stay disabled until you add them.")
        }

        if detectedNutrients.calories == nil {
            notes.append("Calories were not confidently detected. Review the label values before saving.")
        }

        let missingMacroNames = missingMacroNames(from: detectedNutrients)
        if missingMacroNames.isEmpty == false {
            let missingMacrosMessage =
                "\(joinedList(missingMacroNames)) "
                + "\(missingMacroVerb(for: missingMacroNames.count)) "
                + "not confidently detected. Review the label values before saving."
            notes.append(missingMacrosMessage)
        }

        return notes
    }

    private static func missingMacroNames(from nutrients: DetectedNutrients) -> [String] {
        var missingNames: [String] = []

        if nutrients.protein == nil {
            missingNames.append("Protein")
        }

        if nutrients.fat == nil {
            missingNames.append("fat")
        }

        if nutrients.carbs == nil {
            missingNames.append("carbs")
        }

        return missingNames
    }

    private static func joinedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            let prefix = values.dropLast().joined(separator: ", ")
            return "\(prefix), and \(values[values.count - 1])"
        }
    }

    private static func missingMacroVerb(for count: Int) -> String {
        count == 1 ? "was" : "were"
    }
}
