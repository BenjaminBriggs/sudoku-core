//
//  AnyConstraint.swift
//  SudokuCore
//
import Foundation

/// Type-erased, Codable wrapper around any `Constraint`.
///
/// Encodes as `{"type": <typeID>, "payload": {…}}`. Decoding requires the
/// concrete type to have been registered with `ConstraintRegistry`.
public struct AnyConstraint: Sendable, Hashable {
    /// The wrapped constraint. Cast to a concrete type to read its data
    /// (e.g. `constraint.base as? KillerCage`).
    public let base: any Constraint

    private let typeID: String
    private let encodeBody: @Sendable (Encoder) throws -> Void
    private let isEqualTo: @Sendable (any Constraint) -> Bool
    private let hashInto: @Sendable (inout Hasher) -> Void

    public init<C: Constraint>(_ constraint: C) {
        precondition(
            constraint.cells.allSatisfy { (0..<9).contains($0.row) && (0..<9).contains($0.column) },
            "Constraint \"\(C.typeID)\" declares cells outside the 9×9 grid"
        )
        self.base = constraint
        self.typeID = C.typeID
        self.encodeBody = { encoder in try constraint.encode(to: encoder) }
        self.isEqualTo = { other in (other as? C) == constraint }
        self.hashInto = { hasher in hasher.combine(constraint) }
    }

    public static func == (lhs: AnyConstraint, rhs: AnyConstraint) -> Bool {
        lhs.isEqualTo(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        hashInto(&hasher)
    }
}

extension AnyConstraint {
    /// Set to `true` in a decoder's `userInfo` to preserve unregistered
    /// constraint types as inert `UnknownConstraint`s instead of throwing.
    /// Use for forward compatibility (data authored by newer clients); the
    /// preserved constraint enforces nothing but re-encodes verbatim.
    ///
    /// Strict decoding (the default) throws `ConstraintDecodingError.unknownType`
    /// for any type not registered with `ConstraintRegistry` — register variant
    /// modules (e.g. `KillerSudoku.register()`) before decoding puzzles.
    public static let lenientDecodingUserInfoKey = CodingUserInfoKey(
        rawValue: "SudokuCore.AnyConstraint.lenientDecoding")!

    /// Wraps an `UnknownConstraint`, keeping its original type key for encoding.
    init(preserving unknown: UnknownConstraint) {
        self.base = unknown
        self.typeID = unknown.originalTypeID
        self.encodeBody = { encoder in try unknown.encode(to: encoder) }
        self.isEqualTo = { other in (other as? UnknownConstraint) == unknown }
        self.hashInto = { hasher in hasher.combine(unknown) }
    }
}

extension AnyConstraint: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeID = try container.decode(String.self, forKey: .type)
        guard let decode = ConstraintRegistry.decoder(for: typeID) else {
            if decoder.userInfo[Self.lenientDecodingUserInfoKey] as? Bool == true {
                let payload = try JSONValue(from: container.superDecoder(forKey: .payload))
                self = AnyConstraint(
                    preserving: UnknownConstraint(originalTypeID: typeID, payload: payload))
                return
            }
            throw ConstraintDecodingError.unknownType(typeID)
        }
        self = try decode(container.superDecoder(forKey: .payload))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeID, forKey: .type)
        try encodeBody(container.superEncoder(forKey: .payload))
    }
}
