import Foundation

struct FoodDraftImportedData: Hashable {
    var name: String
    var brand: String? = nil
    var source: FoodSource
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current
    var barcode: String? = nil
    var externalProductID: String? = nil
    var sourceName: String? = nil
    var sourceURL: String? = nil
    var servingDescription: String
    var gramsPerServing: Double? = nil
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double? = nil
    var fiberPerServing: Double? = nil
    var sugarsPerServing: Double? = nil
    var addedSugarsPerServing: Double? = nil
    var sodiumPerServing: Double? = nil
    var cholesterolPerServing: Double? = nil
}
