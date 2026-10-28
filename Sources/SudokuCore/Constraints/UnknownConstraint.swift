//
//  UnknownConstraint.swift
//  SudokuCore
//
import Foundation

/// An opaque stand-in for a constraint type this client doesn't know.
///
/// Produced only by lenient decoding (see `AnyConstraint.lenientDecodingUserInfoKey`)
/// when a puzzle references an unregistered `Constraint` type — e.g. data authored
/// by a newer client. It enforces nothing (no cells, no violations, no pruning)
/// but re-encodes with its original type key and payload verbatim, so the puzzle
/// survives a decode → encode round-trip without data loss.
public struct UnknownConstraint: Constraint {
    /// Placeholder id required by `Constraint`. Never used for encoding —
    /// `AnyConstraint` keeps the original type key. Do not register this type.
    public static let typeID = "core.unknownConstraint"

    /// The type key the authoring client wrote.
    public let originalTypeID: String

    /// The payload, preserved structurally for re-encoding.
    let payload: JSONValue

    public var cells: [Puzzle.Index] { [] }

    /// The authored type key plus a digest of the payload, so puzzles rebuilt
    /// around preserved constraints keep distinct ids without core knowing the
    /// authoring client's identity rule.
    public var identity: String { "\(originalTypeID)-\(payload.digest)" }

    public func violations(in state: BoardState) -> [ConstraintViolation] { [] }

    public func prune(candidates: inout PencilMarks, in state: BoardState) {}

    init(originalTypeID: String, payload: JSONValue) {
        self.originalTypeID = originalTypeID
        self.payload = payload
    }

    /// Required by `Constraint: Codable`; only reachable if someone registers
    /// this type, which the placeholder `typeID` documentation forbids.
    public init(from decoder: Decoder) throws {
        self.originalTypeID = Self.typeID
        self.payload = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try payload.encode(to: encoder)
    }
}

/// Structural JSON value used to preserve unknown constraint payloads.
enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue {
    /// Deterministic text form: object keys sorted, no whitespace.
    var canonical: String {
        switch self {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .string(let value):
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"" + escaped + "\""
        case .array(let values):
            return "[" + values.map(\.canonical).joined(separator: ",") + "]"
        case .object(let members):
            let fields = members.keys.sorted().map { "\"\($0)\":" + members[$0]!.canonical }
            return "{" + fields.joined(separator: ",") + "}"
        }
    }

    /// FNV-1a 64-bit digest of ``canonical``, as 16 hex digits. Stable across
    /// processes and releases, unlike `Hasher`.
    var digest: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
