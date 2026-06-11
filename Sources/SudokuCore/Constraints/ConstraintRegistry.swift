//
//  ConstraintRegistry.swift
//  SudokuCore
//
import Foundation
import Synchronization

/// Maps `Constraint.typeID` strings to decoders so `AnyConstraint` can decode
/// heterogeneous constraint arrays. Variant modules register their types once
/// at startup (e.g. `KillerSudoku.register()`). Thread-safe.
public enum ConstraintRegistry {
    private static let decoders = Mutex<[String: @Sendable (Decoder) throws -> AnyConstraint]>([:])
    private static let registeredTypes = Mutex<[String: ObjectIdentifier]>([:])

    /// Register a constraint type for decoding. Re-registering the same type is
    /// a no-op; registering a different type under an existing id is a programmer error.
    public static func register<C: Constraint>(_ type: C.Type) {
        let identity = ObjectIdentifier(type)
        registeredTypes.withLock { types in
            if let existing = types[C.typeID] {
                precondition(
                    existing == identity,
                    "Constraint typeID \"\(C.typeID)\" is already registered by a different type"
                )
                return
            }
            types[C.typeID] = identity
        }
        decoders.withLock { table in
            table[C.typeID] = { decoder in AnyConstraint(try C(from: decoder)) }
        }
    }

    static func decoder(for typeID: String) -> (@Sendable (Decoder) throws -> AnyConstraint)? {
        decoders.withLock { $0[typeID] }
    }
}
