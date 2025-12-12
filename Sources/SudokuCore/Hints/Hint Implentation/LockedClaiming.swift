//
//  LockedClaiming.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Locked Candidates Claiming Technique - Updated
extension HintFinder {
    static func findLockedCandidatesClaiming(in state: BoardState) -> HintStep? {
        // Check rows
        if let hint = findLockedCandidatesClaimingInRows(state) {
            return hint
        }
        
        // Check columns
        if let hint = findLockedCandidatesClaimingInColumns(state) {
            return hint
        }
        
        return nil
    }
    
    private static func findLockedCandidatesClaimingInRows(_ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for row in 0..<9 {
            for digit in 1...9 {
                // Find all positions in this row where digit is a candidate
                var candidates: [Puzzle.Index] = []
                candidates.reserveCapacity(9)

                for col in 0..<9 {
                    if grid[row][col] == 0 {
                        if pencilMarks[row][col].contains(digit) {
                            candidates.append(Puzzle.Index(row: row, column: col))
                        }
                    }
                }

                // We need at least 2 candidates to have a claiming pattern
                if candidates.count >= 2 {
                    // Check if all candidates are in the same house
                    if let boxIndex = commonBoxIndex(for: candidates) {
                        // All candidates are in the same house - use lookup table
                        let house = LookupTables.boxCells[boxIndex]

                        // Find cells in this house NOT in the original row
                        var removals: [HintAction] = []
                        var cellsToRemoveFrom = Set<Puzzle.Index>()
                        removals.reserveCapacity(6)

                        for housePosition in house {
                            // Skip if it's in the original row
                            if housePosition.row == row {
                                continue
                            }

                            if grid[housePosition.row][housePosition.column] == 0 {
                                if pencilMarks[housePosition.row][housePosition.column].contains(digit) {
                                    removals.append(HintAction(position: housePosition, ruleOut: digit))
                                    cellsToRemoveFrom.insert(housePosition)
                                }
                            }
                        }

                        if removals.isEmpty == false {
                            return HintStep(
                                actions: removals,
                                technique: .lockedCandidatesClaiming,
                                explanation: lockedCandidatesClaimingExplanation(
                                    orientation: .row,
                                    digit: digit,
                                    cellsInRowOrColumn: Set(candidates),
                                    boxCellsToRemoveDigit: cellsToRemoveFrom,
                                    state: state
                                )
                            )
                        }
                    }
                }
            }
        }

        return nil
    }
    
    private static func findLockedCandidatesClaimingInColumns(_ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for col in 0..<9 {
            for digit in 1...9 {
                // Find all positions in this column where digit is a candidate
                var candidates: [Puzzle.Index] = []
                candidates.reserveCapacity(9)

                for row in 0..<9 {
                    if grid[row][col] == 0 {
                        if pencilMarks[row][col].contains(digit) {
                            candidates.append(Puzzle.Index(row: row, column: col))
                        }
                    }
                }

                // We need at least 2 candidates to have a claiming pattern
                if candidates.count >= 2 {
                    // Check if all candidates are in the same house
                    if let boxIndex = commonBoxIndex(for: candidates) {
                        // All candidates are in the same house - use lookup table
                        let house = LookupTables.boxCells[boxIndex]

                        // Find cells in this house NOT in the original column
                        var removals: [HintAction] = []
                        var cellsToRemoveFrom = Set<Puzzle.Index>()
                        removals.reserveCapacity(6)

                        for housePosition in house {
                            // Skip if it's in the original column
                            if housePosition.column == col {
                                continue
                            }

                            if grid[housePosition.row][housePosition.column] == 0 {
                                if pencilMarks[housePosition.row][housePosition.column].contains(digit) {
                                    removals.append(HintAction(position: housePosition, ruleOut: digit))
                                    cellsToRemoveFrom.insert(housePosition)
                                }
                            }
                        }

                        if removals.isEmpty == false {
                            return HintStep(
                                actions: removals,
                                technique: .lockedCandidatesClaiming,
                                explanation: lockedCandidatesClaimingExplanation(
                                    orientation: .column,
                                    digit: digit,
                                    cellsInRowOrColumn: Set(candidates),
                                    boxCellsToRemoveDigit: cellsToRemoveFrom,
                                    state: state
                                )
                            )
                        }
                    }
                }
            }
        }

        return nil
    }
    
    // Helper function to check if all positions are in the same house/box
    // Returns the box index if all positions are in the same box, nil otherwise
    private static func commonBoxIndex(for positions: [Puzzle.Index]) -> Int? {
        guard let firstPos = positions.first else { return nil }

        let firstBoxIndex = LookupTables.cellToBoxIndex[firstPos.row][firstPos.column]

        // Check if all positions are in the same house
        for pos in positions.dropFirst() {
            let boxIndex = LookupTables.cellToBoxIndex[pos.row][pos.column]
            if boxIndex != firstBoxIndex {
                return nil
            }
        }

        return firstBoxIndex
    }
    
    private static func lockedCandidatesClaimingExplanation(
        orientation: Puzzle.Index.Orientation,
        digit: Int,
        cellsInRowOrColumn: Set<Puzzle.Index>,
        boxCellsToRemoveDigit: Set<Puzzle.Index>,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []
        
        // Step 1: Introduce the concept
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("In this \(orientation.displayName), all candidates for digit \(digit) are in the same house.", bundle: .module),
                highlightedCells: cellsInRowOrColumn.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )
        
        // Step 2: Explain the implication
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Since \(digit) must be in one of these cells, it can't appear elsewhere in this house.", bundle: .module),
                highlightedCells: cellsInRowOrColumn.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                } + boxCellsToRemoveDigit.map { index in
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
                text: LocalizedStringResource("Remove \(digit) as a candidate from these cells in the same house.", bundle: .module),
                highlightedCells: boxCellsToRemoveDigit.map { index in
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
