import Foundation

enum AnthropicError: Error, LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:          return "ANTHROPIC_API_KEY not set in environment"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodingError(let e):   return "Decode error: \(e)"
        }
    }
}

final class AnthropicClient {
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue(apiKey,        forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",  forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try enc.encode(request)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicError.httpError(http.statusCode, body)
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try dec.decode(MessagesResponse.self, from: data)
        } catch {
            throw AnthropicError.decodingError(error)
        }
    }
}
