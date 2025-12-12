//
//  HintFinder+Validation.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Validation Technique
extension HintFinder {
    static func checkValidity(in state: BoardState) -> HintStep? {
        if checkNoConflicts(in: state.grid) == false {
            // Find the conflict
            var conflictActions: [HintAction] = []
            var conflictCells = Set<Puzzle.Index>()
            var conflictDigit = 0
            var conflictOrientation: Puzzle.Index.Orientation = .row

            // Check rows for duplicates
            for row in 0..<9 {
                var seen = [Int: Puzzle.Index]()
                for col in 0..<9 {
                    let value = state.grid[row][col]
                    if value != 0 {
                        if let previousIndex = seen[value] {
                            // Found a conflict
                            let currentIndex = Puzzle.Index(row: row, column: col)
                            conflictDigit = value
                            conflictOrientation = .row

                            conflictActions.append(HintAction(clearPosition: currentIndex))
                            conflictCells.insert(currentIndex)
                            conflictCells.insert(previousIndex)
                        }
                        seen[value] = Puzzle.Index(row: row, column: col)
                    }
                }
            }

            // If we found a conflict in rows, no need to check columns or houses
            if conflictActions.isEmpty == false {
                return createValidationHintStep(
                    actions: conflictActions,
                    orientation: conflictOrientation,
                    digit: conflictDigit,
                    conflictCells: conflictCells,
                    solution: state.solution,
                    state: state
                )
            }

            // Check columns for duplicates
            for col in 0..<9 {
                var seen = [Int: Puzzle.Index]()
                for row in 0..<9 {
                    let value = state.grid[row][col]
                    if value != 0 {
                        if let previousIndex = seen[value] {
                            // Found a conflict
                            let currentIndex = Puzzle.Index(row: row, column: col)
                            conflictDigit = value
                            conflictOrientation = .column

                            conflictActions.append(HintAction(clearPosition: currentIndex))
                            conflictCells.insert(currentIndex)
                            conflictCells.insert(previousIndex)
                        }
                        seen[value] = Puzzle.Index(row: row, column: col)
                    }
                }
            }

            // If we found a conflict in columns, no need to check houses
            if conflictActions.isEmpty == false {
                return createValidationHintStep(
                    actions: conflictActions,
                    orientation: conflictOrientation,
                    digit: conflictDigit,
                    conflictCells: conflictCells,
                    solution: state.solution,
                    state: state
                )
            }

            // Check houses for duplicates
            for houseRow in stride(from: 0, to: 9, by: 3) {
                for houseCol in stride(from: 0, to: 9, by: 3) {
                    var seen = [Int: Puzzle.Index]()
                    for r in houseRow..<(houseRow + 3) {
                        for c in houseCol..<(houseCol + 3) {
                            let value = state.grid[r][c]
                            if value != 0 {
                                if let previousIndex = seen[value] {
                                    // Found a conflict
                                    let currentIndex = Puzzle.Index(row: r, column: c)
                                    conflictDigit = value
                                    conflictOrientation = .house

                                    conflictActions.append(HintAction(clearPosition: currentIndex))
                                    conflictCells.insert(currentIndex)
                                    conflictCells.insert(previousIndex)
                                }
                                seen[value] = Puzzle.Index(row: r, column: c)
                            }
                        }
                    }
                }
            }

            if conflictActions.isEmpty == false {
                return createValidationHintStep(
                    actions: conflictActions,
                    orientation: conflictOrientation,
                    digit: conflictDigit,
                    conflictCells: conflictCells,
                    solution: state.solution,
                    state: state
                )
            }
        }

        // If solution is available, check if current state matches it
        if let solution = state.solution,
            solution.count == 9,
            solution.allSatisfy({ $0.count == 9 })
        {
            for row in 0..<9 {
                for col in 0..<9 {
                    let value = state.grid[row][col]
                    // Only check cells that have been filled
                    if value != 0 && value != solution[row][col] {
                        let position = Puzzle.Index(row: row, column: col)
                        let correctValue = solution[row][col]
                        return HintStep(
                            actions: [HintAction(clearPosition: position)],
                            technique: .validation,
                            explanation: [
                                HintExplanationStep(
                                    text: LocalizedStringResource("This value is incorrect. The correct value is \(correctValue).", bundle: .module),
                                    highlightedCells: [
                                        HintExplanationStepHighlight(
                                            cell: position,
                                            candidates: state.pencilMarks[position.row][position.column]
                                        )
                                    ]
                                ),
                                HintExplanationStep(
                                    text: LocalizedStringResource("Remove this value and try again.", bundle: .module),
                                    highlightedCells: [
                                        HintExplanationStepHighlight(
                                            cell: position,
                                            value: correctValue,
                                            highlightType: .success
                                        )
                                    ]
                                )
                            ]
                        )
                    }
                }
            }
        }

        return nil
    }

    private static func createValidationHintStep(
        actions: [HintAction],
        orientation: Puzzle.Index.Orientation,
        digit: Int,
        conflictCells: Set<Puzzle.Index>,
        solution: [[Int]]?,
        state: BoardState
    ) -> HintStep {
        let uniqueActions = Array(Set(actions))
        return HintStep(
            actions: uniqueActions,
            technique: .validation,
            explanation: validationExplanation(
                orientation: orientation,
                digit: digit,
                conflictCells: conflictCells,
                solution: solution,
                state: state
            )
        )
    }

    private static func validationExplanation(
        orientation: Puzzle.Index.Orientation,
        digit: Int,
        conflictCells: Set<Puzzle.Index>,
        solution: [[Int]]? = nil,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        // Step 1: Identify the conflict
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("There's a conflict with digit \(digit) in this \(orientation.displayName).", bundle: .module),
                highlightedCells: conflictCells.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        value: digit
                    )
                }
            )
        )

        // Step 2: Explain the rule being violated
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Each \(orientation.displayName) can only contain the digit \(digit) once.", bundle: .module),
                highlightedCells: conflictCells.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        value: digit
                    )
                }
            )
        )

        // Step 3: If solution is available, suggest which one is correct
        if let solution = solution, conflictCells.count == 2 {
            let correctCell = conflictCells.first { index in
                solution[index.row][index.column] == digit
            }

            if let correctCell = correctCell {
                let incorrectCells = conflictCells.filter { $0 != correctCell }

                steps.append(
                    HintExplanationStep(
                        text: LocalizedStringResource("The correct placement for \(digit) is at \(correctCell.description).", bundle: .module),
                        highlightedCells: [
                            HintExplanationStepHighlight(
                                cell: correctCell,
                                value: digit
                            )
                        ] + incorrectCells.map { index in
                            HintExplanationStepHighlight(
                                cell: index,
                                candidates: state.pencilMarks[index.row][index.column]
                            )
                        }
                    )
                )
            }
        } else {
            // Without a solution, suggest removing one of the conflicts
            steps.append(
                HintExplanationStep(
                    text: LocalizedStringResource("Remove \(digit) from one of these positions to resolve the conflict.", bundle: .module),
                    highlightedCells: conflictCells.map { index in
                        HintExplanationStepHighlight(
                            cell: index,
                            candidates: state.pencilMarks[index.row][index.column]
                        )
                    }
                )
            )
        }

        return steps
    }
}
