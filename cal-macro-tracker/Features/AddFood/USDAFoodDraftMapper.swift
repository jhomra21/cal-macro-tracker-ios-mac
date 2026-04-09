import Foundation

enum USDAFoodDraftMapper {
    static func makeDraft(from food: USDAProxyFood) -> FoodDraft {
        var draft = FoodDraft()
        draft.name = food.name
        draft.brand = food.brand ?? ""
        draft.source = .searchLookup
        draft.barcode = food.barcode ?? ""
        draft.externalProductID = food.id
        draft.sourceName = food.sourceName
        draft.sourceURL = food.sourceURL
        draft.servingDescription = food.servingDescription
        draft.gramsPerServing = food.gramsPerServing
        draft.caloriesPerServing = food.caloriesPerServing
        draft.proteinPerServing = food.proteinPerServing
        draft.fatPerServing = food.fatPerServing
        draft.carbsPerServing = food.carbsPerServing
        draft.saveAsCustomFood = true
        return draft
    }
}
