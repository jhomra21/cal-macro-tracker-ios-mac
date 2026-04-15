import Foundation

enum FoodDraftValidationError: LocalizedError {
    case missingName
    case missingServingDescription
    case invalidGramsPerServing
    case negativeCalories
    case negativeProtein
    case negativeFat
    case negativeCarbs
    case invalidQuantity
    case gramsPerServingRequiredForGramLogging

    var errorDescription: String? {
        switch self {
        case .missingName:
            "Enter a food name."
        case .missingServingDescription:
            "Enter a serving description."
        case .invalidGramsPerServing:
            "Grams per serving must be greater than zero when provided."
        case .negativeCalories:
            "Calories cannot be negative."
        case .negativeProtein:
            "Protein cannot be negative."
        case .negativeFat:
            "Fat cannot be negative."
        case .negativeCarbs:
            "Carbs cannot be negative."
        case .invalidQuantity:
            "Enter an amount greater than zero."
        case .gramsPerServingRequiredForGramLogging:
            "Add grams per serving to log by grams."
        }
    }
}

enum ReusableFoodPersistenceMode: Equatable {
    case none
    case userRequested
    case autoCreateFromCommonEdits
    case autoUpdateExistingExternalFood

    var shouldPersistReusableFood: Bool {
        self != .none
    }
}

struct FoodDraft: Identifiable, Hashable {
    static let defaultServingDescription = "1 serving"

    var id: UUID = UUID()
    var foodItemID: UUID?
    var name: String = ""
    var brand: String = ""
    var source: FoodSource = .custom
    var barcode: String = ""
    var externalProductID: String = ""
    var sourceName: String = ""
    var sourceURL: String = ""
    var servingDescription: String = FoodDraft.defaultServingDescription
    var gramsPerServing: Double?
    var caloriesPerServing: Double = 0
    var proteinPerServing: Double = 0
    var fatPerServing: Double = 0
    var carbsPerServing: Double = 0
    var saveAsCustomFood: Bool = true

    init() {}

    init(foodItem: FoodItem, saveAsCustomFood: Bool = false) {
        self.init(
            importedData: FoodDraftImportedData(
                name: foodItem.name,
                brand: foodItem.brand,
                source: foodItem.sourceKind,
                barcode: foodItem.barcode,
                externalProductID: foodItem.externalProductID,
                sourceName: foodItem.sourceName,
                sourceURL: foodItem.sourceURL,
                servingDescription: foodItem.servingDescription,
                gramsPerServing: foodItem.gramsPerServing,
                caloriesPerServing: foodItem.caloriesPerServing,
                proteinPerServing: foodItem.proteinPerServing,
                fatPerServing: foodItem.fatPerServing,
                carbsPerServing: foodItem.carbsPerServing
            ),
            foodItemID: foodItem.id,
            saveAsCustomFood: saveAsCustomFood
        )
    }

    init(logEntry: LogEntry, saveAsCustomFood: Bool = false) {
        self.init(
            importedData: FoodDraftImportedData(
                name: logEntry.foodName,
                brand: logEntry.brand,
                source: logEntry.sourceKind,
                servingDescription: logEntry.servingDescription,
                gramsPerServing: logEntry.gramsPerServing,
                caloriesPerServing: logEntry.caloriesPerServing,
                proteinPerServing: logEntry.proteinPerServing,
                fatPerServing: logEntry.fatPerServing,
                carbsPerServing: logEntry.carbsPerServing
            ),
            saveAsCustomFood: saveAsCustomFood
        )
    }

    init(importedData: FoodDraftImportedData, saveAsCustomFood: Bool = true) {
        self.init(importedData: importedData, foodItemID: nil, saveAsCustomFood: saveAsCustomFood)
    }

    private init(importedData: FoodDraftImportedData, foodItemID: UUID?, saveAsCustomFood: Bool) {
        self.id = UUID()
        self.foodItemID = foodItemID
        self.name = importedData.name
        self.brand = importedData.brand ?? ""
        self.source = importedData.source
        self.barcode = importedData.barcode ?? ""
        self.externalProductID = importedData.externalProductID ?? ""
        self.sourceName = importedData.sourceName ?? ""
        self.sourceURL = importedData.sourceURL ?? ""
        self.servingDescription = importedData.servingDescription
        self.gramsPerServing = importedData.gramsPerServing
        self.caloriesPerServing = importedData.caloriesPerServing
        self.proteinPerServing = importedData.proteinPerServing
        self.fatPerServing = importedData.fatPerServing
        self.carbsPerServing = importedData.carbsPerServing
        self.saveAsCustomFood = saveAsCustomFood
    }

    var brandOrNil: String? {
        FoodDraft.trimmedText(from: brand)
    }

    var barcodeOrNil: String? {
        FoodDraft.trimmedText(from: barcode)
    }

    var externalProductIDOrNil: String? {
        FoodDraft.trimmedText(from: externalProductID)
    }

    var sourceNameOrNil: String? {
        FoodDraft.trimmedText(from: sourceName)
    }

    var sourceURLOrNil: String? {
        FoodDraft.trimmedText(from: sourceURL)
    }

    var canLogByGrams: Bool {
        guard let gramsPerServing else { return false }
        return gramsPerServing > 0
    }

    var canSaveReusableFood: Bool {
        validationErrorForSaving() == nil
    }

    func hasMeaningfulChanges(comparedTo other: FoodDraft) -> Bool {
        let normalizedDraft = normalized()
        let normalizedOther = other.normalized()

        return normalizedDraft.name != normalizedOther.name
            || normalizedDraft.brand != normalizedOther.brand
            || normalizedDraft.servingDescription != normalizedOther.servingDescription
            || normalizedDraft.gramsPerServing != normalizedOther.gramsPerServing
            || normalizedDraft.caloriesPerServing != normalizedOther.caloriesPerServing
            || normalizedDraft.proteinPerServing != normalizedOther.proteinPerServing
            || normalizedDraft.fatPerServing != normalizedOther.fatPerServing
            || normalizedDraft.carbsPerServing != normalizedOther.carbsPerServing
    }

    static func reusableFoodPersistenceMode(initialDraft: FoodDraft, currentDraft: FoodDraft) -> ReusableFoodPersistenceMode {
        let normalizedInitialDraft = initialDraft.normalized()
        let normalizedCurrentDraft = currentDraft.normalized()

        if normalizedCurrentDraft.saveAsCustomFood {
            return .userRequested
        }

        guard normalizedCurrentDraft.hasMeaningfulChanges(comparedTo: normalizedInitialDraft) else {
            return .none
        }

        switch normalizedInitialDraft.source {
        case .common:
            return .autoCreateFromCommonEdits
        case .custom:
            return .none
        case .barcodeLookup, .labelScan, .searchLookup:
            return normalizedInitialDraft.foodItemID == nil ? .none : .autoUpdateExistingExternalFood
        }
    }

    func canLog(quantityMode: QuantityMode, quantityAmount: Double) -> Bool {
        validationErrorForLogging(quantityMode: quantityMode, quantityAmount: quantityAmount) == nil
    }

    func validationErrorForSaving() -> FoodDraftValidationError? {
        let draft = normalized()

        if draft.name.isEmpty {
            return .missingName
        }

        if draft.servingDescription.isEmpty {
            return .missingServingDescription
        }

        if let gramsPerServing = draft.gramsPerServing, gramsPerServing <= 0 {
            return .invalidGramsPerServing
        }

        if draft.caloriesPerServing < 0 {
            return .negativeCalories
        }

        if draft.proteinPerServing < 0 {
            return .negativeProtein
        }

        if draft.fatPerServing < 0 {
            return .negativeFat
        }

        if draft.carbsPerServing < 0 {
            return .negativeCarbs
        }

        return nil
    }

    func validationErrorForLogging(quantityMode: QuantityMode, quantityAmount: Double) -> FoodDraftValidationError? {
        if let validationError = validationErrorForSaving() {
            return validationError
        }

        guard quantityAmount > 0 else {
            return .invalidQuantity
        }

        if quantityMode == .grams, canLogByGrams == false {
            return .gramsPerServingRequiredForGramLogging
        }

        return nil
    }

    func normalized() -> FoodDraft {
        var draft = self
        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.brand = brandOrNil ?? ""
        draft.barcode = barcodeOrNil ?? ""
        draft.externalProductID = externalProductIDOrNil ?? ""
        draft.sourceName = sourceNameOrNil ?? ""
        draft.sourceURL = sourceURLOrNil ?? ""
        draft.servingDescription = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return draft
    }

    func makeReusableFoodItem(sourceOverride: FoodSource? = nil) -> FoodItem {
        let draft = normalized()

        return FoodItem(
            name: draft.name,
            brand: draft.brandOrNil,
            source: sourceOverride ?? draft.source,
            barcode: draft.barcodeOrNil,
            externalProductID: draft.externalProductIDOrNil,
            sourceName: draft.sourceNameOrNil,
            sourceURL: draft.sourceURLOrNil,
            servingDescription: draft.servingDescription,
            gramsPerServing: draft.gramsPerServing,
            caloriesPerServing: draft.caloriesPerServing,
            proteinPerServing: draft.proteinPerServing,
            fatPerServing: draft.fatPerServing,
            carbsPerServing: draft.carbsPerServing
        )
    }

    private static func trimmedText(from value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
