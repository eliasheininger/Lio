import Foundation

// MARK: - Request

struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let tools: [ToolSchema]
    let messages: [Message]
}

struct Message: Encodable {
    let role: String          // "user" | "assistant"
    let content: MessageContent
}

/// Either a plain string (user text) or an array of typed blocks (assistant/tool_result).
enum MessageContent: Encodable {
    case text(String)
    case blocks([ContentBlock])

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let s):    try c.encode(s)
        case .blocks(let bs): try c.encode(bs)
        }
    }
}

enum ContentBlock: Encodable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let b):       try b.encode(to: encoder)
        case .toolUse(let b):    try b.encode(to: encoder)
        case .toolResult(let b): try b.encode(to: encoder)
        }
    }
}

struct TextBlock: Encodable {
    let type = "text"
    let text: String
}

struct ToolUseBlock: Encodable {
    let type = "tool_use"
    let id: String
    let name: String
    let input: [String: AnyCodable]
}

struct ToolResultBlock: Encodable {
    let type = "tool_result"
    let toolUseId: String
    let content: String
}

struct ToolSchema: Encodable {
    let name: String
    let description: String
    let inputSchema: InputSchema
}

struct InputSchema: Encodable {
    let type = "object"
    let properties: [String: PropertySchema]
    let required: [String]
}

struct PropertySchema: Encodable {
    let type: String
    let description: String
}

// MARK: - Response

struct MessagesResponse: Decodable {
    let content: [ResponseBlock]
    let stopReason: String?
}

enum ResponseBlock: Decodable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: AnyCodable])
    case unknown

    private enum CodingKeys: String, CodingKey { case type, text, id, name, input }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try c.decode(String.self, forKey: .text))
        case "tool_use":
            let id    = try c.decode(String.self, forKey: .id)
            let name  = try c.decode(String.self, forKey: .name)
            let input = try c.decode([String: AnyCodable].self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        default:
            self = .unknown
        }
    }
}
