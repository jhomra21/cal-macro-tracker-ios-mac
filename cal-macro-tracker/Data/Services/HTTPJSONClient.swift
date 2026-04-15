import Foundation

enum HTTPJSONClientError: Error {
    case invalidResponse
}

struct HTTPJSONClient {
    static let userAgent = "cal-macro-tracker/1.0 (juan-test.cal-macro-tracker)"

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func makeRequest(url: URL, acceptJSON: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        if acceptJSON {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPJSONClientError.invalidResponse
        }
        return (data, httpResponse)
    }

    func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        try decoder.decode(Response.self, from: data)
    }

    func decodeIfPresent<Response: Decodable>(_ type: Response.Type, from data: Data) -> Response? {
        try? decoder.decode(Response.self, from: data)
    }
}
