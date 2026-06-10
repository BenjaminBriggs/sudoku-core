//
//  NakedSingle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Naked Single Technique
extension HintFinder {
    /// Finds a naked single: a cell whose pencil marks contain exactly one candidate.
    ///
    /// Iterates all empty cells in row-major order and returns a `HintStep` for the first cell
    /// that has only one remaining candidate, or `nil` if no naked single exists.
    /// - Parameter state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` that places the sole candidate, or `nil` if none is found.
    static func findNakedSingle(in state: BoardState) -> HintStep? {
        let grid = state.grid

        // Use pre-computed cell list for better cache locality
        for position in LookupTables.allCells {
            let row = position.row
            let col = position.column

            // Skip filled cells
            if grid[row][col] != 0 {
                continue
            }

            // Get possible values from pencil marks
            let candidates = pencilValuesForCell(at: position, in: state)

            // Check if there's exactly one candidate
            if candidates.count == 1, let digit = candidates.first {
                // Use pre-computed neighbours
                let influence = LookupTables.cellNeighbours[row][col]

                let actions = [HintAction(position: position, solveAs: digit)]
                return HintStep(
                    actions: actions,
                    technique: .nakedSingle,
                    reasoning: HintReasoning(
                        actions: actions,
                        focusDigits: [digit],
                        units: [.row(row), .column(col), .house(position.houseNumber)],
                        components: [
                            .subject([position], candidates: [digit]),
                            .constraint(influence.filter { state.grid[$0.row][$0.column] != 0 }, in: state)
                        ]
                    )
                )
            }
        }

        return nil
    }
}

