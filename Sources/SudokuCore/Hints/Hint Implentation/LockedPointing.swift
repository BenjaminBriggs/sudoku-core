//
//  LockedPointing.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Locked Candidates Pointing Technique - Updated
extension HintFinder {
    static func findLockedCandidatesPointing(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Iterate through each 3x3 house using box indices
        for boxIndex in 0..<9 {
            let boxCells = LookupTables.boxCells[boxIndex]

            // For each digit 1..9, check if it's confined to a single row or column in the house
            for digit in 1...9 {
                var possibleRows = Set<Int>()
                var possibleCols = Set<Int>()
                var possiblePositions = Set<Puzzle.Index>()
                possibleRows.reserveCapacity(3)
                possibleCols.reserveCapacity(3)
                possiblePositions.reserveCapacity(9)

                // Iterate through each cell in the house
                for position in boxCells {
                    let row = position.row
                    let col = position.column

                    // Skip filled cells
                    if grid[row][col] != 0 {
                        continue
                    }

                    if pencilMarks[row][col].contains(digit) {
                        possibleRows.insert(row)
                        possibleCols.insert(col)
                        possiblePositions.insert(position)
                    }
                }
                    
                // Check if the digit is confined to a single row within the house
                if possibleRows.count == 1, let lockedRow = possibleRows.first, possiblePositions.count > 0 {
                    // Find cells in this row outside the current house where digit is a candidate
                    let cellsInHouse = possiblePositions
                    var removals: [HintAction] = []
                    var cellsToRemoveFrom = Set<Puzzle.Index>()
                    removals.reserveCapacity(6)

                    // Use lookup table to get all cells in this row
                    for position in LookupTables.rowCells[lockedRow] {
                        let col = position.column

                        // Skip if it's in the same box
                        if LookupTables.cellToBoxIndex[lockedRow][col] == boxIndex {
                            continue
                        }

                        if grid[lockedRow][col] == 0 {
                            if pencilMarks[lockedRow][col].contains(digit) {
                                removals.append(HintAction(position: position, ruleOut: digit))
                                cellsToRemoveFrom.insert(position)
                            }
                        }
                    }
                        
                    if removals.isEmpty == false {
                        return HintStep(
                            actions: removals,
                            technique: .lockedCandidatesPointing,
                            explanation: lockedCandidatesPointingExplanation(
                                digit: digit,
                                cellsInHouse: cellsInHouse,
                                orientation: .row,
                                cellsOutsideBoxToRemoveDigit: cellsToRemoveFrom,
                                state: state
                            )
                        )
                    }
                }

                // Check if the digit is confined to a single column within the house
                if possibleCols.count == 1, let lockedCol = possibleCols.first, possiblePositions.count > 0 {
                    // Find cells in this column outside the current house where digit is a candidate
                    let cellsInHouse = possiblePositions
                    var removals: [HintAction] = []
                    var cellsToRemoveFrom = Set<Puzzle.Index>()
                    removals.reserveCapacity(6)

                    // Use lookup table to get all cells in this column
                    for position in LookupTables.columnCells[lockedCol] {
                        let row = position.row

                        // Skip if it's in the same box
                        if LookupTables.cellToBoxIndex[row][lockedCol] == boxIndex {
                            continue
                        }

                        if grid[row][lockedCol] == 0 {
                            if pencilMarks[row][lockedCol].contains(digit) {
                                removals.append(HintAction(position: position, ruleOut: digit))
                                cellsToRemoveFrom.insert(position)
                            }
                        }
                    }

                    if removals.isEmpty == false {
                        return HintStep(
                            actions: removals,
                            technique: .lockedCandidatesPointing,
                            explanation: lockedCandidatesPointingExplanation(
                                digit: digit,
                                cellsInHouse: cellsInHouse,
                                orientation: .column,
                                cellsOutsideBoxToRemoveDigit: cellsToRemoveFrom,
                                state: state
                            )
                        )
                    }
                }
            }
        }

        return nil
    }
    
    private static func lockedCandidatesPointingExplanation(
        digit: Int,
        cellsInHouse: Set<Puzzle.Index>,
        orientation: Puzzle.Index.Orientation,
        cellsOutsideBoxToRemoveDigit: Set<Puzzle.Index>,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []
        
        // Step 1: Introduce the concept
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("In this house, \(digit) can only be in cells in one \(orientation.displayName).", bundle: .module),
                highlightedCells: cellsInHouse.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Explain the implication
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Because this house must contain a \(digit), we know that it has to be on of these cells.", bundle: .module),
                highlightedCells: cellsInHouse.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .primary
                    )
                } + cellsInHouse.first!.cells(in: .house).map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .secondary
                    )
                }
            )
        )

        // Step 2: Explain the implication
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Since \(digit) must be in one of these cells, it can't appear elsewhere else in this \(orientation.displayName).", bundle: .module),
                highlightedCells: cellsInHouse.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        value: digit,
                        highlightType: .primary
                    )
                } + cellsInHouse.first!.cells(in: orientation).map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .warning
                    )
                }
            )
        )

        // Step 2: Explain the implication
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("In this \(orientation.displayName), only these cells contain a \(digit) as a candidate", bundle: .module),
                highlightedCells: cellsInHouse.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                } + cellsOutsideBoxToRemoveDigit.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .warning
                    )
                }
            )
        )
        
        // Step 3: Show the candidates to remove
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Therefore we can rule out \(digit) as a candidate from these cells.", bundle: .module),
                highlightedCells: cellsOutsideBoxToRemoveDigit.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .warning
                    )
                }
            )
        )
        
        return steps
    }
}
