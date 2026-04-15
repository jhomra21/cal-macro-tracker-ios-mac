import Foundation

struct FoodDraftImportedData: Hashable {
    var name: String
    var brand: String? = nil
    var source: FoodSource
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
}
