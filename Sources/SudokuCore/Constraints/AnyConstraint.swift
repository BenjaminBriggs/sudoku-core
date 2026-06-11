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

extension AnyConstraint: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeID = try container.decode(String.self, forKey: .type)
        guard let decode = ConstraintRegistry.decoder(for: typeID) else {
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
