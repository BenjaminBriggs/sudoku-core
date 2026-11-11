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
        // Each empty cell's candidates as a bitmask (bit d set for digit d), by cell index
        // (`row * 9 + column`), worked out once for all 27 units
        var candidates = [Int](repeating: 0, count: 81)
        for row in 0..<9 {
            for column in 0..<9 where state.grid[row][column] == 0 {
                candidates[row * 9 + column] = state.pencilMarks[row][column].reduce(0) { $0 | (1 << $1) }
            }
        }

        // Check all units (rows, columns, houses)
        for unit in SudokuUnit.allUnits {
            if let hint = findNakedSubsetsInUnit(
                n: n, unit: unit, technique: technique, state: state, candidates: candidates)
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
    /// digits can be removed from all other cells in the unit. Candidates are bitmasks, so a
    /// combination that isn't a subset costs a few ORs.
    /// - Parameters:
    ///   - n: The subset size (2 = pair, 3 = triple, 4 = quad).
    ///   - unit: The row, column, or box to search.
    ///   - technique: The `TechniqueInfo` to label the result with.
    ///   - state: The current board state.
    ///   - candidates: Each empty cell's candidates as a bitmask, by cell index.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no naked subset is found.
    private static func findNakedSubsetsInUnit(
        n: Int,
        unit: SudokuUnit,
        technique: TechniqueInfo,
        state: BoardState,
        candidates: [Int]
    ) -> HintStep? {
        let positions = unit.positions
        let unitCandidates = positions.map { candidates[$0.row * 9 + $0.column] }

        // The unit's empty cells with at most n candidates, as indices into its positions
        let small = (0..<9).filter { unitCandidates[$0] != 0 && unitCandidates[$0].nonzeroBitCount <= n }

        // Check all combinations of n cells
        for choice in LookupTables.choices(of: small.count, choose: n) {
            // A naked subset's cells hold exactly n candidates between them
            var subsetDigits = 0
            var subsetCells = 0
            for index in choice {
                subsetDigits |= unitCandidates[small[index]]
                subsetCells |= 1 << small[index]
            }
            guard subsetDigits.nonzeroBitCount == n else { continue }

            // Check if we can remove any of its candidates from the unit's other cells
            var removals: [HintAction] = []
            var eliminated: [Puzzle.Index] = []
            for index in 0..<9 where subsetCells & (1 << index) == 0 {
                let shared = unitCandidates[index] & subsetDigits
                guard shared != 0 else { continue }
                for digit in 1...9 where shared & (1 << digit) != 0 {
                    removals.append(HintAction(position: positions[index], ruleOut: digit))
                }
                eliminated.append(positions[index])
            }

            if removals.isEmpty == false {
                return HintStep(
                    actions: removals,
                    technique: technique,
                    reasoning: HintReasoning(
                        actions: removals,
                        focusDigits: (1...9).filter { subsetDigits & (1 << $0) != 0 },
                        units: [unit],
                        components: [
                            .subset(choice.map { positions[small[$0]] }, in: state, unit: unit),
                            .eliminated(eliminated, in: state, unit: unit)
                        ]
                    )
                )
            }
        }

        return nil
    }
}
