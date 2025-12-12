//
//  HiddenSingle.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Hidden Single Technique
extension HintFinder {
    static func findHiddenSingle(in state: BoardState) -> HintStep? {
        // Find hidden singles in rows
        if let hint = findHiddenSingleInRows(state) {
            return hint
        }

        // Find hidden singles in columns
        if let hint = findHiddenSingleInColumns(state) {
            return hint
        }

        // Find hidden singles in houses
        if let hint = findHiddenSingleInHouses(state) {
            return hint
        }

        return nil
    }

    private static func findHiddenSingleInRows(_ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for row in 0..<9 {
            // Use array instead of dictionary for digit counts (digits 1-9)
            // Index 0 is unused, indices 1-9 correspond to digits 1-9
            var digitPositions: [[Puzzle.Index]] = Array(repeating: [], count: 10)

            for col in 0..<9 {
                // Skip filled cells
                if grid[row][col] != 0 {
                    continue
                }

                let candidates = pencilMarks[row][col]
                for digit in candidates {
                    digitPositions[digit].append(Puzzle.Index(row: row, column: col))
                }
            }

            // Check if any digit appears exactly once
            for digit in 1...9 {
                let positions = digitPositions[digit]
                if positions.count == 1 {
                    let position = positions[0]
                    guard pencilMarks[position.row][position.column].count > 1
                    else { continue }

                    return HintStep(
                        actions: [HintAction(position: position, solveAs: digit)],
                        technique: .hiddenSingle,
                        explanation: hiddenSingleExplanation(
                            orientation: .row,
                            digit: digit,
                            cellWithDigit: position,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func findHiddenSingleInColumns(_ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for col in 0..<9 {
            // Use array instead of dictionary for digit counts (digits 1-9)
            var digitPositions: [[Puzzle.Index]] = Array(repeating: [], count: 10)

            for row in 0..<9 {
                // Skip filled cells
                if grid[row][col] != 0 {
                    continue
                }

                let candidates = pencilMarks[row][col]
                for digit in candidates {
                    digitPositions[digit].append(Puzzle.Index(row: row, column: col))
                }
            }

            // Check if any digit appears exactly once
            for digit in 1...9 {
                let positions = digitPositions[digit]
                if positions.count == 1 {
                    let position = positions[0]
                    guard pencilMarks[position.row][position.column].count > 1
                    else { continue }

                    return HintStep(
                        actions: [HintAction(position: position, solveAs: digit)],
                        technique: .hiddenSingle,
                        explanation: hiddenSingleExplanation(
                            orientation: .column,
                            digit: digit,
                            cellWithDigit: position,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func findHiddenSingleInHouses(_ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Use box indices with lookup tables
        for boxIndex in 0..<9 {
            let boxCells = LookupTables.boxCells[boxIndex]

            // Use array instead of dictionary for digit counts (digits 1-9)
            var digitPositions: [[Puzzle.Index]] = Array(repeating: [], count: 10)

            for position in boxCells {
                let row = position.row
                let col = position.column

                // Skip filled cells
                if grid[row][col] != 0 {
                    continue
                }

                let candidates = pencilMarks[row][col]
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

                    return HintStep(
                        actions: [HintAction(position: position, solveAs: digit)],
                        technique: .hiddenSingle,
                        explanation: hiddenSingleExplanation(
                            orientation: .house,
                            digit: digit,
                            cellWithDigit: position,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func hiddenSingleExplanation(
        orientation: Puzzle.Index.Orientation,
        digit: Int,
        cellWithDigit: Puzzle.Index,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        // Step 1: Draw attention to the unit (row, column, or house)
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("We are missing a \(digit) in this \(orientation.displayName).", bundle: .module),
                highlightedCells: cellWithDigit.cells(in: orientation).map { cell in
                    HintExplanationStepHighlight(
                        cell: cell,
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Explain why the other cells can't be the digit
        let interest = cellsOfIntrest(
            for: cellWithDigit,
            with: digit,
            in: orientation,
            in: state
        )
        if interest.restrictions.isEmpty == false {
            let text: LocalizedStringResource
            if interest.restrictions.count == 1 {
                text = LocalizedStringResource("This \(digit) affect this \(orientation.displayName)", bundle: .module)
            } else {
                text = LocalizedStringResource("These \(digit)'s affect this \(orientation.displayName)", bundle: .module)
            }
            steps.append(
                HintExplanationStep(
                    text: text,
                    highlightedCells: interest.restrictions.map { cell in
                        HintExplanationStepHighlight(
                            cell: cell,
                            highlightType: .secondary
                        )
                    } + cellWithDigit.cells(in: orientation).map { cell in
                        HintExplanationStepHighlight(
                            cell: cell,
                            highlightType: .primary
                        )
                    }
                )
            )
        }

        // Step 3: Explain hidden single concept
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("So, the red cells cannot be \(digit).", bundle: .module),
                highlightedCells: interest.restrictions.map { cell in
                    HintExplanationStepHighlight(
                        cell: cell,
                        highlightType: .secondary
                    )
                } + interest.highlighted.map { cell in
                    HintExplanationStepHighlight(
                        cell: cell,
                        highlightType: .warning
                    )
                } + [
                    HintExplanationStepHighlight(
                        cell: cellWithDigit,
                        highlightType: .primary
                    )
                ] + cellWithDigit.cells(in: orientation).map { cell in
                    HintExplanationStepHighlight(
                        cell: cell,
                        highlightType: .warning
                    )
                }
            )
        )

        // Step 4: Place the value
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Therefore, this cell must be \(digit).", bundle: .module),
                highlightedCells: [
                    HintExplanationStepHighlight(
                        cell: cellWithDigit,
                        value: digit,
                        highlightType: .success
                    )
                ]
            )
        )

        return steps
    }
}
