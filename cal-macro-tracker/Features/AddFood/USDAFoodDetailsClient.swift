import Foundation

enum USDAFoodDetailsClientError: LocalizedError {
    case unavailableConfiguration
    case invalidFoodID
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .unavailableConfiguration:
            return "USDA food details are not configured for this build yet."
        case .invalidFoodID:
            return "The USDA food identifier is invalid."
        case .invalidResponse:
            return "The USDA food details service returned an invalid response."
        case let .requestFailed(_, message):
            return message ?? "The USDA food details service returned an error."
        }
    }
}

private struct USDAFoodDetailsErrorResponse: Decodable {
    let error: String
}

struct USDAFoodDetailsClient {
    private let jsonClient: HTTPJSONClient

    init(session: URLSession = .shared) {
        jsonClient = HTTPJSONClient(session: session)
    }

    func fetchFood(id: Int) async throws -> USDAProxyFood {
        guard id > 0 else {
            throw USDAFoodDetailsClientError.invalidFoodID
        }

        guard let baseURL = RemoteFoodSearchConfiguration.packagedFoodSearchBaseURL else {
            throw USDAFoodDetailsClientError.unavailableConfiguration
        }

        let url = baseURL.appendingPathComponent("v1/usda/foods/\(id)")
        let request = jsonClient.makeRequest(url: url, acceptJSON: true)
        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            (data, httpResponse) = try await jsonClient.data(for: request)
        } catch HTTPJSONClientError.invalidResponse {
            throw USDAFoodDetailsClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = jsonClient.decodeIfPresent(USDAFoodDetailsErrorResponse.self, from: data)
            throw USDAFoodDetailsClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.error
            )
        }

        return try jsonClient.decode(USDAProxyFood.self, from: data)
    }
}
