//
//  GridSymmetry.swift
//  SudokuCore
//
//  The symmetries setters give a puzzle's clue layout.
//
import Foundation

/// A symmetry of the clue layout: which cells hold clues, not which digits.
public enum GridSymmetry: String, CaseIterable, Codable, Sendable {
    /// A half turn about the centre cell: (r, c) pairs with (8 − r, 8 − c).
    case rotational
    /// A reflection across the middle column: (r, c) pairs with (r, 8 − c).
    case mirror
    /// A reflection across the leading diagonal: (r, c) pairs with (c, r).
    case diagonal

    /// The cell `position` pairs with under this symmetry. It may be `position` itself.
    public func partner(of position: Puzzle.Index) -> Puzzle.Index {
        switch self {
        case .rotational:
            Puzzle.Index(row: 8 - position.row, column: 8 - position.column)
        case .mirror:
            Puzzle.Index(row: position.row, column: 8 - position.column)
        case .diagonal:
            Puzzle.Index(row: position.column, column: position.row)
        }
    }

    /// Whether every clue's partner is also a clue.
    public func holds(for grid: [[Int]]) -> Bool {
        Puzzle.Index.allIndices.allSatisfy { position in
            let partner = partner(of: position)
            return (grid[position.row][position.column] != 0) == (grid[partner.row][partner.column] != 0)
        }
    }

    /// The symmetries the grid's clue layout has, in declaration order.
    public static func symmetries(of grid: [[Int]]) -> [GridSymmetry] {
        allCases.filter { $0.holds(for: grid) }
    }
}
