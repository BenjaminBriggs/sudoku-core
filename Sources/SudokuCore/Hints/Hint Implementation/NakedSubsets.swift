//
//  NakedSubsets.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Naked Subset Technique (Generic for Pairs, Triples, Quads)
extension HintFinder {
    /// Finds a naked subset of size `n` across all units (rows, columns, and boxes).
    ///
    /// A naked subset occurs when `n` cells in a unit collectively contain exactly `n` candidates,
    /// meaning those digits can be eliminated from all other cells in the unit.
    /// - Parameters:
    ///   - n: The subset size (2 = naked pair, 3 = naked triple, 4 = naked quad).
    ///   - technique: The `TechniqueInfo` to label the result with.
    ///   - state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no naked subset is found.
    static func findNakedSubsets(n: Int, technique: TechniqueInfo, in state: BoardState)
        -> HintStep?
    {
        // Check all units (rows, columns, houses)
        for unit in SudokuUnit.allUnits {
            if let hint = findNakedSubsetsInUnit(
                n: n, unit: unit, technique: technique, state: state)
            {
                return hint
            }
        }
        return nil
    }

    /// Searches a single unit (row, column, or box) for a naked subset of size `n`.
    ///
    /// Collects empty cells whose candidate count is at most `n`, then checks every combination
    /// of `n` such cells. If the union of their candidates contains exactly `n` digits, those
    /// digits can be removed from all other cells in the unit. Uses a bitset for fast union counting.
    /// - Parameters:
    ///   - n: The subset size (2 = pair, 3 = triple, 4 = quad).
    ///   - unit: The row, column, or box to search.
    ///   - technique: The `TechniqueInfo` to label the result with.
    ///   - state: The current board state.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no naked subset is found.
    private static func findNakedSubsetsInUnit(
        n: Int,
        unit: SudokuUnit,
        technique: TechniqueInfo,
        state: BoardState
    ) -> HintStep? {
        // Get all empty cells with their candidates in this unit
        // Pre-allocate array with capacity for better performance
        var cellCandidates: [(Puzzle.Index, Set<Int>)] = []
        cellCandidates.reserveCapacity(9)

        let positions = unit.positions
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for position in positions {
            if grid[position.row][position.column] == 0 {
                let candidates = pencilMarks[position.row][position.column]
                let count = candidates.count
                if count > 0 && count <= n {
                    cellCandidates.append((position, candidates))
                }
            }
        }

        // Need at least n cells to form a subset
        if cellCandidates.count < n {
            return nil
        }

        // Check all combinations of n cells
        for combo in combinations(of: cellCandidates, choose: n) {
            let positions = combo.map { $0.0 }
            let candidateSets = combo.map { $0.1 }

            // Find union of all candidates using bitset for faster operations
            var allCandidatesBits = 0
            for candidates in candidateSets {
                for digit in candidates {
                    allCandidatesBits |= (1 << (digit - 1))
                }
            }

            // Count bits to get number of unique candidates
            let candidateCount = allCandidatesBits.nonzeroBitCount

            // Check if the union has exactly n candidates
            if candidateCount == n {
                // Convert bitset back to Set for compatibility
                var allCandidates = Set<Int>()
                for digit in 1...9 {
                    if (allCandidatesBits & (1 << (digit - 1))) != 0 {
                        allCandidates.insert(digit)
                    }
                }
                // This is a naked subset
                let subsetPositions = Set(positions)

                // Find all other cells in this unit
                let otherPositions = Set(unit.positions).subtracting(subsetPositions)

                // Check if we can remove any candidates from other cells
                var removals: [HintAction] = []
                var excludeIndices = Set<Puzzle.Index>()

                for position in otherPositions {
                    if state.grid[position.row][position.column] == 0 {
                        let candidates = state.pencilMarks[position.row][position.column]
                        for digit in allCandidates {
                            if candidates.contains(digit) {
                                removals.append(HintAction(position: position, ruleOut: digit))
                                excludeIndices.insert(position)
                            }
                        }
                    }
                }

                if removals.isEmpty == false {
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        reasoning: HintReasoning(
                            actions: removals,
                            focusDigits: Array(allCandidates).sorted(),
                            units: [unit],
                            components: [
                                .subset(subsetPositions, in: state, unit: unit),
                                .eliminated(excludeIndices, in: state, unit: unit)
                            ]
                        )
                    )
                }
            }
        }

        return nil
    }
}
