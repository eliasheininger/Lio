import Foundation

/// Lightweight type-erased Codable wrapper for arbitrary JSON.
/// Needed for Claude tool `input` fields which contain arbitrary JSON objects.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                          { value = NSNull() }
        else if let b = try? c.decode(Bool.self)  { value = b }
        else if let i = try? c.decode(Int.self)   { value = i }
        else if let d = try? c.decode(Double.self){ value = d }
        else if let s = try? c.decode(String.self){ value = s }
        else if let a = try? c.decode([AnyCodable].self) {
            value = a.map(\.value)
        } else if let o = try? c.decode([String: AnyCodable].self) {
            value = o.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull:             try c.encodeNil()
        case let b as Bool:         try c.encode(b)
        case let i as Int:          try c.encode(i)
        case let d as Double:       try c.encode(d)
        case let s as String:       try c.encode(s)
        case let a as [Any]:
            try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]:
            try c.encode(o.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value,
                .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

extension AnyCodable: ExpressibleByNilLiteral   { init(nilLiteral: ())    { value = NSNull() } }
extension AnyCodable: ExpressibleByBooleanLiteral{ init(booleanLiteral v: Bool)  { value = v } }
extension AnyCodable: ExpressibleByIntegerLiteral{ init(integerLiteral v: Int)   { value = v } }
extension AnyCodable: ExpressibleByFloatLiteral  { init(floatLiteral v: Double)  { value = v } }
extension AnyCodable: ExpressibleByStringLiteral { init(stringLiteral v: String) { value = v } }
