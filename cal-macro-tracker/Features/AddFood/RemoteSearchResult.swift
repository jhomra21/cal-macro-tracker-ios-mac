import Foundation

enum RemoteSearchProvider: String, Hashable, Decodable {
    case openFoodFacts
    case usda

    var displayName: String {
        switch self {
        case .openFoodFacts:
            return "Open Food Facts"
        case .usda:
            return "USDA FoodData Central"
        }
    }
}

enum RemoteSearchResult: Identifiable, Hashable {
    case openFoodFacts(OpenFoodFactsProduct)
    case usda(USDAProxyFood)

    var id: String {
        switch self {
        case let .openFoodFacts(product):
            return "\(provider.rawValue):\(product.id)"
        case let .usda(food):
            return food.id
        }
    }

    var provider: RemoteSearchProvider {
        switch self {
        case .openFoodFacts:
            return .openFoodFacts
        case .usda:
            return .usda
        }
    }

    var name: String {
        switch self {
        case let .openFoodFacts(product):
            return product.productName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unnamed product"
        case let .usda(food):
            return food.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unnamed product"
        }
    }

    var brand: String? {
        switch self {
        case let .openFoodFacts(product):
            return product.brands?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        case let .usda(food):
            return food.brand?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    var cacheLookupExternalProductIDs: [String] {
        switch self {
        case let .openFoodFacts(product):
            return product.cacheLookupExternalProductIDs
        case let .usda(food):
            return [food.id]
        }
    }

    var barcode: String? {
        switch self {
        case let .openFoodFacts(product):
            return product.normalizedBarcode
        case let .usda(food):
            return food.barcode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    var reviewNotes: [String] {
        switch self {
        case .openFoodFacts:
            return ["Selected from online packaged food search."]
        case .usda:
            return ["Selected from USDA packaged food search."]
        }
    }

    var summary: String {
        switch self {
        case let .openFoodFacts(product):
            let servingText =
                product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? product.quantity?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? "Packaged food"
            let nutriments = product.nutrition

            if let calories = nutriments.caloriesPerServing {
                return "\(provider.displayName) • \(calories.roundedForDisplay) kcal • \(servingText)"
            }

            if let calories = nutriments.caloriesPer100g {
                return "\(provider.displayName) • \(calories.roundedForDisplay) kcal per 100 g • \(servingText)"
            }

            return "\(provider.displayName) • \(servingText)"
        case let .usda(food):
            return "\(provider.displayName) • \(food.caloriesPerServing.roundedForDisplay) kcal • \(food.servingDescription)"
        }
    }

    func makeDraft() throws -> FoodDraft {
        switch self {
        case let .openFoodFacts(product):
            return try BarcodeLookupMapper.makeDraft(from: product, source: .searchLookup)
        case let .usda(food):
            return USDAFoodDraftMapper.makeDraft(from: food)
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
