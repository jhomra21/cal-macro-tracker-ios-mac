import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var brand: String?
    var source: String
    var barcode: String?
    var externalProductID: String?
    var sourceName: String?
    var sourceURL: String?
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var secondaryNutrientBackfillStateRaw: String?
    var searchableText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        source: FoodSource,
        barcode: String? = nil,
        externalProductID: String? = nil,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        servingDescription: String,
        gramsPerServing: Double? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double,
        saturatedFatPerServing: Double? = nil,
        fiberPerServing: Double? = nil,
        sugarsPerServing: Double? = nil,
        addedSugarsPerServing: Double? = nil,
        sodiumPerServing: Double? = nil,
        cholesterolPerServing: Double? = nil,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current,
        aliases: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source.rawValue
        self.barcode = barcode
        self.externalProductID = externalProductID
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.saturatedFatPerServing = saturatedFatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarsPerServing = sugarsPerServing
        self.addedSugarsPerServing = addedSugarsPerServing
        self.sodiumPerServing = sodiumPerServing
        self.cholesterolPerServing = cholesterolPerServing
        self.secondaryNutrientBackfillStateRaw = secondaryNutrientBackfillState?.rawValue
        self.searchableText = FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: aliases)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceKind: FoodSource {
        FoodSource(rawValue: source) ?? .custom
    }

    var isMissingAllSecondaryNutrients: Bool {
        saturatedFatPerServing == nil
            && fiberPerServing == nil
            && sugarsPerServing == nil
            && addedSugarsPerServing == nil
            && sodiumPerServing == nil
            && cholesterolPerServing == nil
    }

    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? {
        get {
            guard let secondaryNutrientBackfillStateRaw else { return nil }
            return SecondaryNutrientBackfillState(rawValue: secondaryNutrientBackfillStateRaw)
        }
        set {
            secondaryNutrientBackfillStateRaw = newValue?.rawValue
        }
    }

    var expectedSearchableText: String {
        FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: [])
    }

    var needsSearchableTextRepair: Bool {
        searchableText != expectedSearchableText
    }

    func normalizeForPersistence() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        servingDescription = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        brand = FoodItem.trimmedText(from: brand)
        barcode = FoodItem.trimmedText(from: barcode)
        externalProductID = FoodItem.trimmedText(from: externalProductID)
        sourceName = FoodItem.trimmedText(from: sourceName)
        sourceURL = FoodItem.trimmedText(from: sourceURL)

        updateSearchableText()
    }

    func updateSearchableText(with aliases: [String] = [], updateTimestamp: Bool = true) {
        searchableText = FoodItem.makeSearchableText(name: name, brand: brand, barcode: barcode, aliases: aliases)
        if updateTimestamp {
            updatedAt = .now
        }
    }

    private static func makeSearchableText(name: String, brand: String?, barcode: String?, aliases: [String]) -> String {
        var seen = Set<String>()
        return ([name, brand, barcode] + aliases)
            .compactMap(normalizedSearchValue)
            .filter { seen.insert($0).inserted }
            .joined(separator: " ")
    }

    private static func normalizedSearchValue(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    private static func trimmedText(from value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }
}
