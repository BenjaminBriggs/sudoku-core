//
//  HiddenSubsets.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Hidden Subset Technique (Generic for Pairs, Triples, Quads)
extension HintFinder {
    /// Finds a hidden subset of size `n` across all units (rows, columns, and boxes).
    ///
    /// A hidden subset occurs when `n` digits within a unit can only appear in exactly `n` cells,
    /// meaning all other candidates in those cells can be eliminated.
    /// - Parameters:
    ///   - n: The subset size (2 = hidden pair, 3 = hidden triple, 4 = hidden quad).
    ///   - technique: The `TechniqueInfo` to label the result with.
    ///   - state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no hidden subset is found.
    static func findHiddenSubsets(n: Int, technique: TechniqueInfo, in state: BoardState) -> HintStep? {
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
            if let hint = findHiddenSubsetsInUnit(
                n: n, unit: unit, technique: technique, state: state, candidates: candidates)
            {
                return hint
            }
        }
        return nil
    }

    /// Searches a single unit (row, column, or box) for a hidden subset of size `n`.
    ///
    /// Maps each unplaced digit to the cells where it appears as a candidate. Then checks every
    /// combination of `n` available digits. If those `n` digits are confined to exactly `n` cells,
    /// all other candidates can be removed from those cells. Digits and cells are bitmasks, so
    /// a combination that isn't a subset costs a few ORs.
    /// - Parameters:
    ///   - n: The subset size (2 = pair, 3 = triple, 4 = quad).
    ///   - unit: The row, column, or box to search.
    ///   - technique: The `TechniqueInfo` to label the result with.
    ///   - state: The current board state.
    ///   - candidates: Each empty cell's candidates as a bitmask, by cell index.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no hidden subset is found.
    private static func findHiddenSubsetsInUnit(
        n: Int,
        unit: SudokuUnit,
        technique: TechniqueInfo,
        state: BoardState,
        candidates: [Int]
    ) -> HintStep? {
        let positions = unit.positions

        // For each digit 1-9, the unit's cells holding it as a candidate: bit i for the
        // unit's i-th cell. Index 0 is unused.
        var digitCells = [Int](repeating: 0, count: 10)
        var placedDigits = 0
        for (index, position) in positions.enumerated() {
            let value = state.grid[position.row][position.column]
            if value == 0 {  // Empty cell
                let cellCandidates = candidates[position.row * 9 + position.column]
                for digit in 1...9 where cellCandidates & (1 << digit) != 0 {
                    digitCells[digit] |= 1 << index
                }
            } else {
                placedDigits |= 1 << value
            }
        }

        let availableDigits = (1...9).filter { placedDigits & (1 << $0) == 0 }

        for choice in LookupTables.choices(of: availableDigits.count, choose: n) {
            // All the cells where these digits can appear. For a hidden subset the n digits
            // must each have a cell, and be confined to exactly n cells between them.
            var unionCells = 0
            var subsetDigits = 0
            var allDigitsPresent = true
            for index in choice {
                let digit = availableDigits[index]
                unionCells |= digitCells[digit]
                subsetDigits |= 1 << digit
                if digitCells[digit] == 0 { allDigitsPresent = false }
            }
            guard unionCells.nonzeroBitCount == n, allDigitsPresent else { continue }

            // We have a hidden subset: remove all other digits from these n cells
            let subsetPositions = (0..<9).filter { unionCells & (1 << $0) != 0 }.map { positions[$0] }
            var removals: [HintAction] = []
            for position in subsetPositions {
                let others = candidates[position.row * 9 + position.column] & ~subsetDigits
                for digit in 1...9 where others & (1 << digit) != 0 {
                    removals.append(HintAction(position: position, ruleOut: digit))
                }
            }

            if removals.isEmpty == false {
                return HintStep(
                    actions: removals,
                    technique: technique,
                    reasoning: HintReasoning(
                        actions: removals,
                        focusDigits: choice.map { availableDigits[$0] },
                        units: [unit],
                        // The subset cells are also the cells that lose candidates, so a single
                        // `.subset` component (carrying each cell's real pencil marks) captures
                        // the pattern; the eliminations themselves are in `reasoning.eliminations`.
                        components: [
                            .subset(subsetPositions, in: state, unit: unit)
                        ]
                    )
                )
            }
        }

        return nil
    }
}
