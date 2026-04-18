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

    private static func loadDotEnv() -> [String: String] {
        func ancestors(of path: String) -> [String] {
            var dirs: [String] = []
            var url = URL(fileURLWithPath: path, isDirectory: true)
            for _ in 0..<5 {
                dirs.append(url.path)
                let parent = url.deletingLastPathComponent()
                if parent.path == url.path { break }
                url = parent
            }
            return dirs
        }

        var seen = Set<String>()
        var candidates: [String] = []
        let roots = [
            FileManager.default.currentDirectoryPath,
            Bundle.main.executableURL?.deletingLastPathComponent().path ?? ""
        ]
        for root in roots where !root.isEmpty {
            for dir in ancestors(of: root) {
                if seen.insert(dir).inserted { candidates.append(dir) }
            }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if seen.insert(home + "/.config/whisk").inserted {
            candidates.append(home + "/.config/whisk")
        }

        var vars: [String: String] = [:]
        for dir in candidates {
            let path = dir + "/.env"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                vars[key] = value
            }
            return vars
        }
        return vars
    }

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let dotEnv = Self.loadDotEnv()
        let apiKey = dotEnv["ANTHROPIC_API_KEY"]
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? ""
        guard !apiKey.isEmpty else {
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

        if let body = req.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("[Lio] Request body length: \(bodyStr.count) chars")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Lio] HTTP \(http.statusCode): \(body)")
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
