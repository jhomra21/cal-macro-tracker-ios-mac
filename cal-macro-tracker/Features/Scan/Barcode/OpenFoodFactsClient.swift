import Foundation

enum OpenFoodFactsIdentity {
    nonisolated static func barcodeAliases(for barcode: String?) -> [String] {
        guard let barcode = trimmedText(from: barcode) else {
            return []
        }

        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: barcode)) {
            if barcode.count == 12 {
                return [barcode, "0\(barcode)"]
            }

            if barcode.count == 13, barcode.hasPrefix("0") {
                return [String(barcode.dropFirst()), barcode]
            }
        }

        return [barcode]
    }

    nonisolated static func qualifiedExternalProductID(for barcode: String?) -> String? {
        qualifiedExternalProductID(forRawIdentifier: barcodeAliases(for: barcode).first)
    }

    nonisolated static func qualifiedExternalProductIDAliases(for barcode: String?) -> [String] {
        var seen = Set<String>()
        return barcodeAliases(for: barcode)
            .compactMap { qualifiedExternalProductID(forRawIdentifier: $0) }
            .filter { seen.insert($0).inserted }
    }

    nonisolated static func qualifiedExternalProductID(forRawIdentifier identifier: String?) -> String? {
        guard let identifier = trimmedText(from: identifier) else {
            return nil
        }

        return "openfoodfacts:\(identifier)"
    }

    nonisolated static func trimmedText(from value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }
}

struct OpenFoodFactsProduct: Decodable, Identifiable, Hashable {
    let externalProductID: String?

    var id: String {
        externalProductIDOrNil
            ?? OpenFoodFactsIdentity.qualifiedExternalProductID(for: code)
            ?? [productName, brands, url].compactMap(OpenFoodFactsIdentity.trimmedText).joined(separator: "|")
    }

    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let servingQuantityUnit: String?
    let quantity: String?
    let nutriments: Nutriments?
    let url: String?

    var cacheLookupExternalProductIDs: [String] {
        var seen = Set<String>()
        return ([externalProductIDOrNil] + OpenFoodFactsIdentity.qualifiedExternalProductIDAliases(for: code))
            .compactMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func resolvedExternalProductID(preferredBarcode: String? = nil) -> String? {
        OpenFoodFactsIdentity.qualifiedExternalProductID(for: preferredBarcode) ?? cacheLookupExternalProductIDs.first
    }

    var normalizedBarcode: String? {
        OpenFoodFactsIdentity.barcodeAliases(for: code).first
    }

    struct Nutriments: Decodable, Hashable {
        let caloriesPerServing: Double?
        let proteinPerServing: Double?
        let fatPerServing: Double?
        let carbsPerServing: Double?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let fatPer100g: Double?
        let carbsPer100g: Double?

        private enum CodingKeys: String, CodingKey {
            case caloriesPerServing = "energy-kcal_serving"
            case proteinPerServing = "proteins_serving"
            case fatPerServing = "fat_serving"
            case carbsPerServing = "carbohydrates_serving"
            case caloriesPer100g = "energy-kcal_100g"
            case proteinPer100g = "proteins_100g"
            case fatPer100g = "fat_100g"
            case carbsPer100g = "carbohydrates_100g"
        }

        static let empty = Self(
            caloriesPerServing: nil,
            proteinPerServing: nil,
            fatPerServing: nil,
            carbsPerServing: nil,
            caloriesPer100g: nil,
            proteinPer100g: nil,
            fatPer100g: nil,
            carbsPer100g: nil
        )
    }

    private enum CodingKeys: String, CodingKey {
        case externalProductID
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
        case quantity
        case nutriments
        case url
    }

    private var externalProductIDOrNil: String? {
        OpenFoodFactsIdentity.trimmedText(from: externalProductID)
    }

    var nutrition: Nutriments {
        nutriments ?? .empty
    }
}

struct OpenFoodFactsResponse: Decodable {
    let product: OpenFoodFactsProduct?
}

enum OpenFoodFactsClientError: LocalizedError {
    case invalidBarcode
    case invalidResponse
    case requestFailed(statusCode: Int)
    case productNotFound

    var isRetryable: Bool {
        switch self {
        case .invalidBarcode, .productNotFound:
            return false
        case .invalidResponse:
            return true
        case let .requestFailed(statusCode):
            return statusCode >= 500
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "The scanned barcode is invalid."
        case .invalidResponse:
            return "The food lookup service returned an invalid response."
        case let .requestFailed(statusCode):
            if statusCode == 503 {
                return "Open Food Facts is temporarily unavailable. You can still use on-device results or manual entry."
            }

            return "The food lookup service returned an error (\(statusCode))."
        case .productNotFound:
            return "No product was found for that barcode."
        }
    }
}

struct OpenFoodFactsClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProduct(barcode: String) async throws -> OpenFoodFactsProduct {
        let normalizedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBarcode.isEmpty else {
            throw OpenFoodFactsClientError.invalidBarcode
        }

        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(normalizedBarcode).json")!
        let decodedResponse: OpenFoodFactsResponse = try await sendRequest(url: url)

        guard let product = decodedResponse.product else {
            throw OpenFoodFactsClientError.productNotFound
        }

        return product
    }

    private func sendRequest<Response: Decodable>(url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("cal-macro-tracker/1.0 (juan-test.cal-macro-tracker)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenFoodFactsClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}
