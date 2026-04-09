import Foundation

struct NutritionSnapshot: Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    static let zero = NutritionSnapshot(calories: 0, protein: 0, fat: 0, carbs: 0)
}

struct NutritionMath {
    static func totals(for entries: [LogEntry]) -> NutritionSnapshot {
        entries.reduce(into: .zero) { partial, entry in
            partial.calories += entry.caloriesConsumed
            partial.protein += entry.proteinConsumed
            partial.fat += entry.fatConsumed
            partial.carbs += entry.carbsConsumed
        }
    }

    static func consumedNutrition(for food: FoodDraft, mode: QuantityMode, amount: Double) -> NutritionSnapshot {
        guard amount > 0 else { return .zero }

        switch mode {
        case .servings:
            return NutritionSnapshot(
                calories: food.caloriesPerServing * amount,
                protein: food.proteinPerServing * amount,
                fat: food.fatPerServing * amount,
                carbs: food.carbsPerServing * amount
            )
        case .grams:
            guard let gramsPerServing = food.gramsPerServing, gramsPerServing > 0 else {
                return .zero
            }

            let multiplier = amount / gramsPerServing
            return NutritionSnapshot(
                calories: food.caloriesPerServing * multiplier,
                protein: food.proteinPerServing * multiplier,
                fat: food.fatPerServing * multiplier,
                carbs: food.carbsPerServing * multiplier
            )
        }
    }
}
