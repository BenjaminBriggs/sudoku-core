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
                    explanation: nakedSingleExplanation(
                        index: position,
                        digit: digit,
                        influence: influence,
                        state: state
                    ),
                    reasoning: .make(
                        actions: actions,
                        focusDigits: [digit],
                        units: [.row(row), .column(col), .house(position.houseNumber)],
                        components: [
                            .make(.subject, [position], candidates: [digit]),
                            .make(.constraint, influence.filter { state.grid[$0.row][$0.column] != 0 }, in: state)
                        ]
                    )
                )
            }
        }

        return nil
    }
    
    /// Builds the explanation steps for a naked single hint.
    ///
    /// Generates up to three steps: (1) highlight the cell with `.primary`, (2) show the
    /// neighbouring constraints with `.secondary` to explain why all other digits are eliminated,
    /// and (3) place the digit with `.success`.
    /// - Parameters:
    ///   - index: The position of the naked single cell.
    ///   - digit: The sole remaining candidate to place.
    ///   - influence: The set of neighbouring cells that constrain this cell.
    ///   - state: The current board state for context.
    /// - Returns: An array of `HintExplanationStep` describing the naked single deduction.
    private static func nakedSingleExplanation(
        index: Puzzle.Index,
        digit: Int,
        influence: Set<Puzzle.Index> = [],
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []
        
        // Step 1: Identify the cell with only one candidate
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("This cell only has one candidate", bundle: .module),
                highlightedCells: [
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .primary
                    )
                ]
            )
        )
        
        // Step 2: Show the constraints if provided
        if influence.isEmpty == false {
            steps.append(
                HintExplanationStep(
                    text: LocalizedStringResource("We can rule out every other number by looking at the row, column, or box that affect this cell. Leaving \(digit) the only remaining option", bundle: .module),
                    highlightedCells: [
                        HintExplanationStepHighlight(
                            cell: index,
                            highlightType: .primary
                        )
                    ] + influence.map { constraint in
                        HintExplanationStepHighlight(
                            cell: constraint,
                            highlightType: .secondary
                        )
                    }
                )
            )
        }
        
        // Step 3: Place the value
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Therefore, this cell must be \(digit).", bundle: .module),
                highlightedCells: [
                    HintExplanationStepHighlight(
                        cell: index,
                        value: digit,
                        highlightType: .success
                    )
                ]
            )
        )
        
        return steps
    }
}

