//
//  NakedSingle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Naked Single Technique
extension HintFinder {
    static func findNakedSingle(in state: BoardState) -> HintStep? {
        let grid = state.grid
        _ = state.pencilMarks

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

                return HintStep(
                    actions: [HintAction(position: position, solveAs: digit)],
                    technique: .nakedSingle,
                    explanation: nakedSingleExplanation(
                        index: position,
                        digit: digit,
                        influence: influence,
                        state: state
                    )
                )
            }
        }

        return nil
    }
    
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

