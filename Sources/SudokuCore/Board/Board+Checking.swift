//
//  Checking.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation

extension Board {
    public var isValid: Bool {
        Validator.hasNoConflicts(in: cells.solution)
    }
}

// Helpers
extension Board {
    /// Return the set of digits used in a given row
    private func rowDigits(_ row: Int) -> Set<Int> {
        cells
            .filter { $0.position.row == row }
            .compactMap { $0.value }
            .reduce(into: Set<Int>()) { $0.insert($1) }
    }

    /// Return the set of digits used in a given column
    private func columnDigits(_ column: Int) -> Set<Int> {
        cells
            .filter { $0.position.column == column }
            .compactMap { $0.value }
            .reduce(into: Set<Int>()) { $0.insert($1) }
    }

    /// Return the set of digits used in the 3×3 house that contains (row, col)
    private func houseDigits(position: Puzzle.Index) -> Set<Int> {
        var digits = Set<Int>()

        for position in position.houseIndices {
            if let v = cell(at: position).value {
                digits.insert(v)
            }
        }
        return digits
    }
}
