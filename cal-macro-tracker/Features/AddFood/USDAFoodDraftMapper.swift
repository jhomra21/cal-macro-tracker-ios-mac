import Foundation

enum USDAFoodDraftMapper {
    static func makeDraft(from food: USDAProxyFood) -> FoodDraft {
        FoodDraft(
            importedData: FoodDraftImportedData(
                name: food.name,
                brand: food.brand,
                source: .searchLookup,
                barcode: food.barcode,
                externalProductID: food.id,
                sourceName: food.sourceName,
                sourceURL: food.sourceURL,
                servingDescription: food.servingDescription,
                gramsPerServing: food.gramsPerServing,
                caloriesPerServing: food.caloriesPerServing,
                proteinPerServing: food.proteinPerServing,
                fatPerServing: food.fatPerServing,
                carbsPerServing: food.carbsPerServing
            )
        )
    }
}
