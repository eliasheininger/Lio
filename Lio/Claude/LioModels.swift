import Foundation

// MARK: - Request (OpenAI / OpenRouter chat completions format)

struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String       // prepended as role:"system" message in encoding
    let tools: [ToolSchema]
    let messages: [Message]

    private enum CodingKeys: String, CodingKey {
        case model, messages, tools
        case maxTokens = "max_tokens"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model,      forKey: .model)
        try c.encode(maxTokens,  forKey: .maxTokens)
        try c.encode(tools,      forKey: .tools)
        var all: [Message] = [.system(system)]
        all.append(contentsOf: messages)
        try c.encode(all, forKey: .messages)
    }
}

// MARK: - Messages

enum Message: Encodable {
    /// Initial / follow-up user turn with content blocks (text + images).
    case user([UserBlock])
    /// System prompt (first message).
    case system(String)
    /// Assistant turn — optional text + zero or more tool calls.
    case assistant(text: String?, toolCalls: [AssistantToolCall])
    /// Tool result turn (one per tool call).
    case tool(callId: String, content: String)

    private enum Keys: String, CodingKey {
        case role, content
        case toolCalls  = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .system(let text):
            try c.encode("system", forKey: .role)
            try c.encode(text,     forKey: .content)
        case .user(let blocks):
            try c.encode("user",   forKey: .role)
            try c.encode(blocks,   forKey: .content)
        case .assistant(let text, let calls):
            try c.encode("assistant", forKey: .role)
            if let text, !text.isEmpty { try c.encode(text, forKey: .content) }
            if !calls.isEmpty          { try c.encode(calls, forKey: .toolCalls) }
        case .tool(let callId, let content):
            try c.encode("tool",  forKey: .role)
            try c.encode(callId,  forKey: .toolCallId)
            try c.encode(content, forKey: .content)
        }
    }
}

// MARK: - User content blocks

enum UserBlock: Encodable {
    case text(String)
    case image(mediaType: String, base64: String)

    private enum TextKeys: String, CodingKey { case type, text }
    private enum ImgKeys:  String, CodingKey { case type, imageUrl = "image_url" }
    private struct ImageUrl: Encodable { let url: String }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let t):
            var c = encoder.container(keyedBy: TextKeys.self)
            try c.encode("text", forKey: .type)
            try c.encode(t,      forKey: .text)
        case .image(let mediaType, let base64):
            var c = encoder.container(keyedBy: ImgKeys.self)
            try c.encode("image_url", forKey: .type)
            try c.encode(ImageUrl(url: "data:\(mediaType);base64,\(base64)"), forKey: .imageUrl)
        }
    }
}

// MARK: - Tool call (inside assistant message)

struct AssistantToolCall: Encodable {
    let id: String
    let name: String
    let arguments: String   // JSON-encoded string of the input dict

    private enum Keys: String, CodingKey { case id, type, function }
    private struct FnCall: Encodable { let name: String; let arguments: String }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id,           forKey: .id)
        try c.encode("function",   forKey: .type)
        try c.encode(FnCall(name: name, arguments: arguments), forKey: .function)
    }
}

// MARK: - Tool definitions (OpenAI function format)

struct ToolSchema: Encodable {
    let name: String
    let description: String
    let inputSchema: InputSchema   // becomes "parameters" in the function wrapper

    private enum Keys: String, CodingKey { case type, function }
    private struct FnDef: Encodable {
        let name: String; let description: String; let parameters: InputSchema
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode("function", forKey: .type)
        try c.encode(FnDef(name: name, description: description, parameters: inputSchema),
                     forKey: .function)
    }
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

// MARK: - Response (OpenAI chat completions format)
// Decoded by JSONDecoder with .convertFromSnakeCase — so property names are camelCase
// and the decoder converts JSON snake_case keys automatically. No explicit CodingKeys needed.

struct MessagesResponse: Decodable {
    let content: [ResponseBlock]
    let stopReason: String?     // "stop" | "tool_calls" | nil

    // Intermediate decodable types matching the OpenAI response shape.
    private struct Root: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Msg
            let finishReason: String?   // JSON: "finish_reason" → convertFromSnakeCase ✓

            struct Msg: Decodable {
                let content: String?
                let toolCalls: [TC]?    // JSON: "tool_calls" → convertFromSnakeCase ✓

                struct TC: Decodable {
                    let id: String
                    let function: Fn
                    struct Fn: Decodable { let name: String; let arguments: String }
                }
            }
        }
    }

    init(from decoder: Decoder) throws {
        let root   = try Root(from: decoder)
        let choice = root.choices.first
        let msg    = choice?.message
        stopReason = choice?.finishReason

        var blocks: [ResponseBlock] = []
        if let text = msg?.content, !text.isEmpty {
            blocks.append(.text(text))
        }
        for tc in msg?.toolCalls ?? [] {
            let data  = Data(tc.function.arguments.utf8)
            let input = (try? JSONDecoder().decode([String: AnyCodable].self, from: data)) ?? [:]
            blocks.append(.toolUse(id: tc.id, name: tc.function.name, input: input))
        }
        content = blocks
    }
}

enum ResponseBlock {
    case text(String)
    case toolUse(id: String, name: String, input: [String: AnyCodable])
    case unknown
}
