//
//  LockedPointing.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Locked Candidates Pointing Technique - Updated
extension HintFinder {
    /// Searches for a Locked Candidates Pointing elimination in the given board state.
    ///
    /// For each box, checks whether any candidate digit is confined to a single row or column.
    /// When found, that digit can be eliminated from the rest of that row or column outside the box.
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first pointing elimination found, or `nil` if none exists.
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
                            reasoning: HintReasoning(
                                actions: removals,
                                focusDigits: [digit],
                                units: [.house(boxIndex), .row(lockedRow)],
                                components: [
                                    .base(cellsInHouse, candidates: [digit], unit: .house(boxIndex)),
                                    .eliminated(cellsToRemoveFrom, candidates: [digit], unit: .row(lockedRow))
                                ]
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
                            reasoning: HintReasoning(
                                actions: removals,
                                focusDigits: [digit],
                                units: [.house(boxIndex), .column(lockedCol)],
                                components: [
                                    .base(cellsInHouse, candidates: [digit], unit: .house(boxIndex)),
                                    .eliminated(cellsToRemoveFrom, candidates: [digit], unit: .column(lockedCol))
                                ]
                            )
                        )
                    }
                }
            }
        }

        return nil
    }
}
