import Foundation

struct USDAProxyFood: Decodable, Identifiable, Hashable {
    let id: String
    let fdcId: Int
    let name: String
    let brand: String?
    let servingDescription: String
    let gramsPerServing: Double?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let carbsPerServing: Double
    let sourceName: String
    let sourceURL: String
    let barcode: String?
}
