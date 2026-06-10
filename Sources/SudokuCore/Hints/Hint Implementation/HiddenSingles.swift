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
                return HintStep(
                    actions: actions,
                    technique: .hiddenSingle,
                    explanation: hiddenSingleExplanation(
                        orientation: unit.orientation,
                        digit: digit,
                        cellWithDigit: position,
                        state: state
                    ),
                    reasoning: .make(
                        actions: actions,
                        focusDigits: [digit],
                        units: [unit],
                        components: [
                            .make(.subject, [position], candidates: [digit], unit: unit)
                        ]
                    )
                )
            }
        }

        return nil
    }

    /// Builds the explanation steps for a hidden single hint.
    ///
    /// Generates four steps: (1) highlight the unit with `.primary` to show the missing digit,
    /// (2) show restricting cells with `.secondary`, (3) mark eliminated cells with `.warning`
    /// to explain why the digit cannot go elsewhere, and (4) place the digit with `.success`.
    /// - Parameters:
    ///   - orientation: Whether the unit is a row, column, or box.
    ///   - digit: The hidden single digit to place.
    ///   - cellWithDigit: The only cell in the unit where the digit can go.
    ///   - state: The current board state for context.
    /// - Returns: An array of `HintExplanationStep` describing the hidden single deduction.
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
                text = LocalizedStringResource("This \(digit) affects this \(orientation.displayName)", bundle: .module)
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
