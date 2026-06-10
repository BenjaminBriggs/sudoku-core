//
//  HintFinder+Validation.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Validation Technique
extension HintFinder {
    /// Checks the board for conflicts and incorrect placements, returning a hint if any are found.
    ///
    /// The check proceeds in priority order:
    /// 1. Duplicate digits within a **row** (returns immediately on first conflict).
    /// 2. Duplicate digits within a **column**.
    /// 3. Duplicate digits within a **3x3 box (house)**.
    /// 4. If a solution is available, cells whose value differs from the solution.
    ///
    /// - Parameter state: The current board state snapshot to validate.
    /// - Returns: A `HintStep` with a `clearPosition` action for the offending cell(s),
    ///   or `nil` if the board is valid.
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
                            reasoning: HintReasoning(
                                actions: [HintAction(clearPosition: position)],
                                focusDigits: [correctValue],
                                components: [
                                    HintComponent(
                                        role: .subject,
                                        cells: [CellFact(position: position, value: correctValue)]
                                    )
                                ]
                            )
                        )
                    }
                }
            }
        }

        return nil
    }

    /// Creates a validation `HintStep` from the detected conflict, deduplicating actions.
    ///
    /// - Parameters:
    ///   - actions: The hint actions identifying conflicting cells.
    ///   - orientation: The unit type (row, column, or house) where the conflict was found.
    ///   - digit: The duplicated digit causing the conflict.
    ///   - conflictCells: The set of cell positions involved in the conflict.
    ///   - solution: The puzzle solution, if available, for identifying the correct placement.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` describing the conflict with deduplicated actions and explanation.
    private static func createValidationHintStep(
        actions: [HintAction],
        orientation: Puzzle.Index.Orientation,
        digit: Int,
        conflictCells: Set<Puzzle.Index>,
        solution: [[Int]]?,
        state: BoardState
    ) -> HintStep {
        let uniqueActions = Array(Set(actions))

        // Record the conflicting unit so presentation can name the orientation.
        var units: [SudokuUnit] = []
        if let anchor = conflictCells.first {
            let lineIndex: Int
            switch orientation {
            case .row: lineIndex = anchor.row
            case .column: lineIndex = anchor.column
            case .house: lineIndex = anchor.houseNumber
            }
            units = [SudokuUnit(orientation: orientation, index: lineIndex)]
        }

        var components: [HintComponent] = [.constraint(conflictCells, in: state)]
        // When the solution is known, the correct placement is a fact of the deduction.
        if let solution, conflictCells.count == 2,
           let correctCell = conflictCells.first(where: { solution[$0.row][$0.column] == digit }) {
            components.append(
                HintComponent(role: .subject, cells: [CellFact(position: correctCell, value: digit)])
            )
        }

        return HintStep(
            actions: uniqueActions,
            technique: .validation,
            reasoning: HintReasoning(
                actions: uniqueActions,
                focusDigits: [digit],
                units: units,
                components: components
            )
        )
    }
}
