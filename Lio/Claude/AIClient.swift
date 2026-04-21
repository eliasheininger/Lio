import Foundation

enum AIClientError: Error, LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:          return "OPENROUTER_API_KEY not set in .env"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodingError(let e):   return "Decode error: \(e)"
        }
    }
}

final class AIClient {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    private static func loadDotEnv() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates: [String] = []

        if Bundle.main.bundlePath.hasSuffix(".app") {
            // Running as .app — only check inside the bundle (never crosses into
            // Desktop / Documents, which would trigger macOS privacy prompts).
            if let execDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
                candidates.append(execDir)
            }
        } else {
            // Development (swift run) — walk up from CWD and executable to find .env.
            func ancestors(of path: String) -> [String] {
                var dirs: [String] = []
                var url = URL(fileURLWithPath: path, isDirectory: true)
                for _ in 0..<6 {
                    dirs.append(url.path)
                    let parent = url.deletingLastPathComponent()
                    if parent.path == url.path { break }
                    url = parent
                }
                return dirs
            }
            var seen = Set<String>()
            for root in [FileManager.default.currentDirectoryPath,
                         Bundle.main.executableURL?.deletingLastPathComponent().path ?? ""]
            where !root.isEmpty {
                for dir in ancestors(of: root) {
                    if seen.insert(dir).inserted { candidates.append(dir) }
                }
            }
        }

        // Always check a stable user config location.
        candidates.append(home + "/.config/Lio")

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

    static func resolveModel() -> String {
        let env = loadDotEnv()
        return env["OPENROUTER_MODEL"]
            ?? ProcessInfo.processInfo.environment["OPENROUTER_MODEL"]
            ?? "anthropic/claude-sonnet-4-6"
    }

    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let dotEnv = Self.loadDotEnv()
        let udKey = UserDefaults.standard.string(forKey: "openrouter_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = !udKey.isEmpty ? udKey
            : (dotEnv["OPENROUTER_API_KEY"]
            ?? ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
            ?? "")
        guard !apiKey.isEmpty else {
            throw AIClientError.missingAPIKey
        }

        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            throw AIClientError.httpError(http.statusCode, body)
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try dec.decode(MessagesResponse.self, from: data)
        } catch {
            throw AIClientError.decodingError(error)
        }
    }
}
