import Foundation

struct LoggedFoodNutrients {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var saturatedFat: Double?
    var fiber: Double?
    var sugars: Double?
    var addedSugars: Double?
    var sodium: Double?
    var cholesterol: Double?

    static let zero = LoggedFoodNutrients(
        calories: 0,
        protein: 0,
        fat: 0,
        carbs: 0,
        saturatedFat: nil,
        fiber: nil,
        sugars: nil,
        addedSugars: nil,
        sodium: nil,
        cholesterol: nil
    )

    var macroSnapshot: NutritionSnapshot {
        NutritionSnapshot(
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }
}

struct NutritionMath {
    static func consumedNutrients(for food: FoodDraft, mode: QuantityMode, amount: Double) -> LoggedFoodNutrients {
        guard amount > 0 else { return .zero }

        switch mode {
        case .servings:
            return scaledNutrients(for: food, multiplier: amount)
        case .grams:
            guard let gramsPerServing = food.gramsPerServing, gramsPerServing > 0 else {
                return .zero
            }

            return scaledNutrients(for: food, multiplier: amount / gramsPerServing)
        }
    }

    static func consumedNutrition(for food: FoodDraft, mode: QuantityMode, amount: Double) -> NutritionSnapshot {
        consumedNutrients(for: food, mode: mode, amount: amount).macroSnapshot
    }

    private static func scaledNutrients(for food: FoodDraft, multiplier: Double) -> LoggedFoodNutrients {
        LoggedFoodNutrients(
            calories: food.caloriesPerServing * multiplier,
            protein: food.proteinPerServing * multiplier,
            fat: food.fatPerServing * multiplier,
            carbs: food.carbsPerServing * multiplier,
            saturatedFat: scaled(food.saturatedFatPerServing, by: multiplier),
            fiber: scaled(food.fiberPerServing, by: multiplier),
            sugars: scaled(food.sugarsPerServing, by: multiplier),
            addedSugars: scaled(food.addedSugarsPerServing, by: multiplier),
            sodium: scaled(food.sodiumPerServing, by: multiplier),
            cholesterol: scaled(food.cholesterolPerServing, by: multiplier)
        )
    }

    private static func scaled(_ value: Double?, by multiplier: Double) -> Double? {
        guard let value else { return nil }
        return value * multiplier
    }
}
