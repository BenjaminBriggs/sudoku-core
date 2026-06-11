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
