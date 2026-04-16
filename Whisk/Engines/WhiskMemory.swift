import Foundation

// MARK: - Model

struct WhiskMemory: Codable {
    /// What the user asked Whisk to do last time.
    var lastTask: String
    /// The frontmost app when the last task completed.
    var frontmostApp: String
    /// One-sentence description of the resulting UI state — injected as context for the next command.
    var contextNote: String
}

// MARK: - Store

final class WhiskMemoryStore {
    static let shared = WhiskMemoryStore()
    private init() {}

    private let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/whisk")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory.json")
    }()

    func load() -> WhiskMemory? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WhiskMemory.self, from: data)
    }

    func save(_ memory: WhiskMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
