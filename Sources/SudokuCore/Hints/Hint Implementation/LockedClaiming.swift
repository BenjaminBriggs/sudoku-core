//
//  LockedClaiming.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation

// MARK: - Locked Candidates Claiming Technique - Updated
extension HintFinder {
    /// Searches for a Locked Candidates Claiming elimination in the given board state.
    ///
    /// Iterates over all rows and columns. When a candidate digit within a row or column is
    /// confined to a single box, that digit can be eliminated from the rest of that box.
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first claiming elimination found, or `nil` if none exists.
    static func findLockedCandidatesClaiming(in state: BoardState) -> HintStep? {
        for unit in SudokuUnit.allRows + SudokuUnit.allColumns {
            if let hint = findLockedCandidatesClaimingInUnit(unit, state) {
                return hint
            }
        }
        return nil
    }

    /// Checks a single row or column unit for a claiming pattern.
    ///
    /// For each digit 1-9, collects all candidate positions in the unit. If two or more candidates
    /// share the same box, any other occurrences of that digit in the box (outside the unit) can be removed.
    /// - Parameters:
    ///   - unit: The row or column to examine.
    ///   - state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` if an elimination is found, or `nil` otherwise.
    private static func findLockedCandidatesClaimingInUnit(_ unit: SudokuUnit, _ state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks
        let unitPositions = Set(unit.positions)

        for digit in 1...9 {
            // Find all positions in this unit where digit is a candidate
            var candidates: [Puzzle.Index] = []
            candidates.reserveCapacity(9)

            for position in unit.positions {
                if grid[position.row][position.column] == 0 {
                    if pencilMarks[position.row][position.column].contains(digit) {
                        candidates.append(position)
                    }
                }
            }

            // We need at least 2 candidates to have a claiming pattern
            if candidates.count >= 2 {
                // Check if all candidates are in the same house
                if let boxIndex = commonBoxIndex(for: candidates) {
                    // All candidates are in the same house - use lookup table
                    let house = LookupTables.boxCells[boxIndex]

                    // Find cells in this house NOT in the original unit
                    var removals: [HintAction] = []
                    var cellsToRemoveFrom = Set<Puzzle.Index>()
                    removals.reserveCapacity(6)

                    for housePosition in house {
                        // Skip if it's in the original unit
                        if unitPositions.contains(housePosition) {
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
                                orientation: unit.orientation,
                                digit: digit,
                                cellsInRowOrColumn: Set(candidates),
                                boxCellsToRemoveDigit: cellsToRemoveFrom,
                                state: state
                            ),
                            reasoning: .make(
                                actions: removals,
                                focusDigits: [digit],
                                units: [unit, .house(boxIndex)],
                                components: [
                                    .make(.base, Set(candidates), candidates: [digit], unit: unit),
                                    .make(.eliminated, cellsToRemoveFrom, candidates: [digit], unit: .house(boxIndex))
                                ]
                            )
                        )
                    }
                }
            }
        }

        return nil
    }
    
    /// Returns the box index shared by all the given positions, or `nil` if they span multiple boxes.
    ///
    /// Uses the precomputed `LookupTables.cellToBoxIndex` mapping for O(1) per-cell lookups.
    /// This is the key check for the claiming pattern: all candidates in a unit must fall within one box.
    /// - Parameter positions: The candidate positions to test.
    /// - Returns: The common box index (0-8), or `nil` if the positions are not all in the same box.
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
    
    /// Builds a multi-step explanation for a Locked Candidates Claiming hint.
    ///
    /// Generates three explanation steps:
    /// 1. All candidates for the digit in the row/column fall within one box (primary highlight).
    /// 2. The digit must be in one of those cells, so it cannot appear elsewhere in the box (primary + warning).
    /// 3. Concludes with the candidates to remove from the box (warning highlight).
    /// - Parameters:
    ///   - orientation: Whether the claiming pattern was found along a row or column.
    ///   - digit: The candidate digit confined to a single box within the unit.
    ///   - cellsInRowOrColumn: The cells in the row or column where the digit appears as a candidate.
    ///   - boxCellsToRemoveDigit: The cells in the box (outside the unit) that will have the digit eliminated.
    ///   - state: An immutable snapshot of the current board.
    /// - Returns: An array of `HintExplanationStep` values for progressive disclosure in the UI.
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
