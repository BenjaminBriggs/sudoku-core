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
    ///   - technique: The `HintTechnique` to label the result with.
    ///   - state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no hidden subset is found.
    static func findHiddenSubsets(n: Int, technique: HintTechnique, in state: BoardState) -> HintStep? {
        // Check all units (rows, columns, houses)
        for unit in SudokuUnit.allUnits {
            if let hint = findHiddenSubsetsInUnit(n: n, unit: unit, technique: technique, state: state) {
                return hint
            }
        }
        return nil
    }

    /// Searches a single unit (row, column, or box) for a hidden subset of size `n`.
    ///
    /// Maps each unplaced digit to the cells where it appears as a candidate. Then checks every
    /// combination of `n` available digits. If those `n` digits are confined to exactly `n` cells,
    /// all other candidates can be removed from those cells. Uses a bitset to track placed digits.
    /// - Parameters:
    ///   - n: The subset size (2 = pair, 3 = triple, 4 = quad).
    ///   - unit: The row, column, or box to search.
    ///   - technique: The `HintTechnique` to label the result with.
    ///   - state: The current board state.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no hidden subset is found.
    private static func findHiddenSubsetsInUnit(
        n: Int,
        unit: SudokuUnit,
        technique: HintTechnique,
        state: BoardState
    ) -> HintStep? {
        // Use array instead of dictionary for digit->cells mapping (digits 1-9)
        // Index 0 is unused, indices 1-9 correspond to digits 1-9
        var digitToCells: [Set<Puzzle.Index>] = Array(repeating: Set<Puzzle.Index>(), count: 10)
        let unitCells = Set(unit.positions)

        // Pre-compute grid and pencil marks for faster access
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Gather cells for each digit in this unit
        var placedDigitsBits = 0
        for position in unit.positions {
            let value = grid[position.row][position.column]
            if value == 0 {  // Empty cell
                let candidates = pencilMarks[position.row][position.column]
                for digit in candidates {
                    digitToCells[digit].insert(position)
                }
            } else {
                placedDigitsBits |= (1 << (value - 1))
            }
        }

        // Get available digits using bitset
        var availableDigits: [Int] = []
        availableDigits.reserveCapacity(9)
        for digit in 1...9 {
            let bit = 1 << (digit - 1)
            if (placedDigitsBits & bit) == 0 {
                availableDigits.append(digit)
            }
        }

        let digitCombinations = combinations(of: availableDigits, choose: n)

        for digitCombo in digitCombinations {
            // Get all cells where these digits can appear
            var unionCells = Set<Puzzle.Index>()
            unionCells.reserveCapacity(n)

            for digit in digitCombo {
                unionCells.formUnion(digitToCells[digit])
            }

            // For a hidden subset, these n digits must be confined to exactly n cells
            if unionCells.count == n {
                // Verify that all digits in the combo actually appear in the union
                var allDigitsPresent = true
                for digit in digitCombo {
                    let cells = digitToCells[digit]
                    if cells.isEmpty || cells.isSubset(of: unionCells) == false {
                        allDigitsPresent = false
                        break
                    }
                }

                if allDigitsPresent == false {
                    continue
                }

                // We have a hidden subset
                let subsetDigits = Set(digitCombo)
                var removals: [HintAction] = []
                removals.reserveCapacity(unionCells.count * 6)  // Estimate

                // Remove all other digits from these n cells
                for position in unionCells {
                    let candidates = pencilMarks[position.row][position.column]
                    for digit in candidates where subsetDigits.contains(digit) == false {
                        removals.append(HintAction(position: position, ruleOut: digit))
                    }
                }

                if removals.isEmpty == false {
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        explanation: hiddenSubsetExplanation(
                            indices: unionCells,
                            digits: digitCombo.sorted(),
                            orientation: unit.orientation,
                            unitCells: unitCells,
                            n: n,
                            state: state
                        ),
                        reasoning: .make(
                            actions: removals,
                            focusDigits: digitCombo.sorted(),
                            units: [unit],
                            // The subset cells are also the cells that lose candidates, so a single
                            // `.subset` component (carrying each cell's real pencil marks) captures
                            // the pattern; the eliminations themselves are in `reasoning.eliminations`.
                            components: [
                                .make(.subset, unionCells, in: state, unit: unit)
                            ]
                        )
                    )
                }
            }
        }

        return nil
    }

    /// Builds the explanation steps for a hidden subset hint.
    ///
    /// Generates three steps: (1) highlight the entire unit with `.primary` to focus attention,
    /// (2) show the subset cells with `.action` to identify where the hidden digits appear,
    /// and (3) mark non-subset candidates in those cells with `.warning` to show what will be removed.
    /// - Parameters:
    ///   - indices: The positions of the cells forming the hidden subset.
    ///   - digits: The sorted list of hidden subset digits.
    ///   - orientation: Whether this is a row, column, or box.
    ///   - unitCells: All cells in the unit, used for the initial highlight.
    ///   - n: The subset size (2, 3, or 4).
    ///   - state: The current board state for pencil mark lookups.
    /// - Returns: An array of `HintExplanationStep` describing the hidden subset deduction.
    private static func hiddenSubsetExplanation(
        indices: Set<Puzzle.Index>,
        digits: [Int],
        orientation: Puzzle.Index.Orientation,
        unitCells: Set<Puzzle.Index>,
        n: Int,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        let subsetName = localisedCountName(n)

        // Step 1: Focus on the unit
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at this \(orientation.displayName). Pay attention to where digits \(digits.formattedList()) can appear.", bundle: .module),
                highlightedCells: unitCells.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Identify the hidden subset
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("The digits \(digits.formattedList()) can only appear in these \(subsetName) cells in this \(orientation.displayName).", bundle: .module),
                highlightedCells: indices.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: Set(digits),
                        highlightType: .action
                    )
                }
            )
        )

        // Step 3: Show the implications
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Since these \(subsetName) cells must contain \(digits.formattedList()), we can remove all other candidates from them.", bundle: .module),
                highlightedCells: indices.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: state
                            .pencilMarks[index.row][index.column]
                            .subtracting(Set(digits)),
                        highlightType: .warning
                    )
                }
            )
        )

        return steps
    }
}