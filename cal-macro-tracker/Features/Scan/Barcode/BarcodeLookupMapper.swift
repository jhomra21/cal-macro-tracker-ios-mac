import Foundation

enum BarcodeLookupMapperError: LocalizedError {
    case missingNutrition

    var errorDescription: String? {
        switch self {
        case .missingNutrition:
            "The selected product does not include enough nutrition data to prefill a food entry."
        }
    }
}

struct BarcodeLookupMapper {
    private struct NutritionBasis {
        let servingDescription: String
        let gramsPerServing: Double?
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    static func makeDraft(from product: OpenFoodFactsProduct, barcode: String) throws -> FoodDraft {
        try makeDraft(from: product, source: .barcodeLookup, barcode: barcode)
    }

    static func makeDraft(from product: OpenFoodFactsProduct, source: FoodSource, barcode: String? = nil) throws -> FoodDraft {
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nutritionBasis = try nutritionBasis(for: product)
        let resolvedBarcode = OpenFoodFactsIdentity.barcodeAliases(for: barcode ?? product.code).first ?? ""

        var draft = FoodDraft()
        draft.name = name
        draft.brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        draft.source = source
        draft.barcode = resolvedBarcode
        draft.externalProductID = product.resolvedExternalProductID(preferredBarcode: resolvedBarcode) ?? ""
        draft.sourceName = "Open Food Facts"
        draft.sourceURL = product.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        draft.servingDescription = nutritionBasis.servingDescription
        draft.gramsPerServing = nutritionBasis.gramsPerServing
        draft.caloriesPerServing = nutritionBasis.calories
        draft.proteinPerServing = nutritionBasis.protein
        draft.fatPerServing = nutritionBasis.fat
        draft.carbsPerServing = nutritionBasis.carbs
        draft.saveAsCustomFood = true
        return draft
    }

    private static func nutritionBasis(for product: OpenFoodFactsProduct) throws -> NutritionBasis {
        if let servingNutrition = servingNutrition(for: product) {
            return servingNutrition
        }

        if let scaledServingNutrition = scaledServingNutritionFrom100g(for: product) {
            return scaledServingNutrition
        }

        if let nutritionPer100g = nutritionPer100g(for: product) {
            return nutritionPer100g
        }

        throw BarcodeLookupMapperError.missingNutrition
    }

    private static func servingNutrition(for product: OpenFoodFactsProduct) -> NutritionBasis? {
        let nutriments = product.nutrition
        guard let calories = nutriments.caloriesPerServing,
            let protein = nutriments.proteinPerServing,
            let fat = nutriments.fatPerServing,
            let carbs = nutriments.carbsPerServing
        else {
            return nil
        }

        return NutritionBasis(
            servingDescription: servingDescription(for: product),
            gramsPerServing: gramsPerServing(for: product),
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }

    private static func scaledServingNutritionFrom100g(for product: OpenFoodFactsProduct) -> NutritionBasis? {
        let nutriments = product.nutrition
        guard let caloriesPer100g = nutriments.caloriesPer100g,
            let proteinPer100g = nutriments.proteinPer100g,
            let fatPer100g = nutriments.fatPer100g,
            let carbsPer100g = nutriments.carbsPer100g,
            let servingGrams = gramsPerServing(for: product)
        else {
            return nil
        }

        let multiplier = servingGrams / 100
        return NutritionBasis(
            servingDescription: servingDescription(for: product),
            gramsPerServing: servingGrams,
            calories: caloriesPer100g * multiplier,
            protein: proteinPer100g * multiplier,
            fat: fatPer100g * multiplier,
            carbs: carbsPer100g * multiplier
        )
    }

    private static func nutritionPer100g(for product: OpenFoodFactsProduct) -> NutritionBasis? {
        let nutriments = product.nutrition
        guard let calories = nutriments.caloriesPer100g,
            let protein = nutriments.proteinPer100g,
            let fat = nutriments.fatPer100g,
            let carbs = nutriments.carbsPer100g
        else {
            return nil
        }

        return NutritionBasis(
            servingDescription: "100 g",
            gramsPerServing: 100,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }

    private static func servingDescription(for product: OpenFoodFactsProduct) -> String {
        if let servingSize = product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines), !servingSize.isEmpty {
            return servingSize
        }

        if let servingQuantity = product.servingQuantity, let servingQuantityUnit = product.servingQuantityUnit,
            !servingQuantityUnit.isEmpty
        {
            return "\(servingQuantity.roundedForDisplay) \(servingQuantityUnit)"
        }

        return "100 g"
    }

    private static func gramsPerServing(for product: OpenFoodFactsProduct) -> Double? {
        guard let servingQuantity = product.servingQuantity,
            let servingQuantityUnit = product.servingQuantityUnit?.lowercased(),
            servingQuantityUnit == "g"
        else {
            return nil
        }

        return servingQuantity
    }
}
