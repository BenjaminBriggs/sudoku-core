//
//  Constraint.swift
//  SudokuCore
//
import Foundation

/// An additive rule layered on top of the classic 9×9 sudoku rules.
///
/// Constraints are the unit of variant extension: killer cages, thermometers,
/// or one-off bespoke rules all conform to this. A constraint can report
/// definite rule breaches and remove candidates the rule forbids. Rules that
/// cannot be encoded are enforced by solution-checking only (see `Board`).
public protocol Constraint: Sendable, Codable, Hashable {
    /// Stable discriminator used as the Codable type key. Never change once shipped.
    static var typeID: String { get }

    /// Cells this constraint involves — for app rendering and debugging.
    var cells: [Puzzle.Index] { get }

    /// Definite rule breaches in the current state.
    func violations(in state: BoardState) -> [ConstraintViolation]

    /// Remove candidates this constraint rules out. Runs after classic pruning,
    /// repeatedly until candidates stabilize (so eliminations made by other
    /// constraints become visible in `state` on later passes).
    ///
    /// Contract: only *removals* within this constraint's declared `cells` take
    /// effect — the engine ignores mutations to other cells and any added
    /// candidates.
    func prune(candidates: inout PencilMarks, in state: BoardState)
}

/// A definite breach of a constraint, for the app to surface.
public struct ConstraintViolation: Sendable, Hashable {
    public let constraintTypeID: String
    public let cells: [Puzzle.Index]
    /// Index of the breached constraint in the puzzle's/board's `constraints`
    /// array. Set by the engine; nil when the violation was produced directly
    /// by a `Constraint` outside engine reporting.
    public let constraintIndex: Int?

    public init(constraintTypeID: String, cells: [Puzzle.Index], constraintIndex: Int? = nil) {
        self.constraintTypeID = constraintTypeID
        self.cells = cells
        self.constraintIndex = constraintIndex
    }

    /// Copy of this violation annotated with its source constraint's index.
    func indexed(_ index: Int) -> ConstraintViolation {
        ConstraintViolation(
            constraintTypeID: constraintTypeID, cells: cells, constraintIndex: index)
    }
}

public enum ConstraintDecodingError: Error, CustomStringConvertible {
    /// The payload's `type` has no registered `Constraint` implementation.
    /// Register the variant module (e.g. `KillerSudoku.register()`) before decoding.
    case unknownType(String)

    public var description: String {
        switch self {
        case .unknownType(let id):
            return
                "No Constraint registered for type \"\(id)\". Call the variant module's register() before decoding."
        }
    }
}
