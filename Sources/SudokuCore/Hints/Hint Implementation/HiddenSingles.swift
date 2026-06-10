//
//  HiddenSingle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Hidden Single Technique
extension HintFinder {
    /// Finds a hidden single: a digit that can only appear in one cell within a unit.
    ///
    /// Checks every row, column, and box. Returns the first hidden single found, or `nil`
    /// if none exists. Skips cells that already have only one pencil mark (those are naked singles).
    /// - Parameter state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` that places the hidden single digit, or `nil` if none is found.
    static func findHiddenSingle(in state: BoardState) -> HintStep? {
        for unit in SudokuUnit.allUnits {
            if let hint = findHiddenSingleInUnit(unit, state) {
                return hint
            }
        }
        return nil
    }

    /// Searches a single unit for a hidden single.
    ///
    /// Maps each digit (1-9) to the empty cells where it appears as a candidate. If any digit
    /// maps to exactly one cell (and that cell has more than one candidate), it is a hidden single.
    /// - Parameters:
    ///   - unit: The row, column, or box to search.
    ///   - state: The current board state.
    /// - Returns: A `HintStep` placing the hidden single, or `nil` if none is found in this unit.
    private static func findHiddenSingleInUnit(_ unit: SudokuUnit, _ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Use array instead of dictionary for digit counts (digits 1-9)
        // Index 0 is unused, indices 1-9 correspond to digits 1-9
        var digitPositions: [[Puzzle.Index]] = Array(repeating: [], count: 10)

        for position in unit.positions {
            // Skip filled cells
            if grid[position.row][position.column] != 0 {
                continue
            }

            let candidates = pencilMarks[position.row][position.column]
            for digit in candidates {
                digitPositions[digit].append(position)
            }
        }

        // Check if any digit appears exactly once
        for digit in 1...9 {
            let positions = digitPositions[digit]
            if positions.count == 1 {
                let position = positions[0]
                guard pencilMarks[position.row][position.column].count > 1
                else { continue }

                let actions = [HintAction(position: position, solveAs: digit)]
                // The cells already holding `digit` elsewhere that force it into `position` —
                // a fact of the deduction, captured so presentation can narrate it.
                let restrictions = cellsOfIntrest(
                    for: position,
                    with: digit,
                    in: unit.orientation,
                    in: state
                ).restrictions
                return HintStep(
                    actions: actions,
                    technique: .hiddenSingle,
                    reasoning: HintReasoning(
                        actions: actions,
                        focusDigits: [digit],
                        units: [unit],
                        components: [
                            .subject([position], candidates: [digit], unit: unit),
                            .constraint(restrictions, in: state)
                        ]
                    )
                )
            }
        }

        return nil
    }
}
