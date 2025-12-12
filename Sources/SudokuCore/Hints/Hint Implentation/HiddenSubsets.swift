//
//  HiddenSubsets.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Hidden Subset Technique (Generic for Pairs, Triples, Quads)
extension HintFinder {
    /// Find hidden subsets of size n (2 for pairs, 3 for triples, 4 for quads)
    static func findHiddenSubsets(n: Int, technique: HintTechnique, in state: BoardState) -> HintStep? {
        // Check all units (rows, columns, houses)
        for unit in SudokuUnit.allUnits {
            if let hint = findHiddenSubsetsInUnit(n: n, unit: unit, technique: technique, state: state) {
                return hint
            }
        }
        return nil
    }

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
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func hiddenSubsetExplanation(
        indices: Set<Puzzle.Index>,
        digits: [Int],
        orientation: Puzzle.Index.Orientation,
        unitCells: Set<Puzzle.Index>,
        n: Int,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        // Determine the name of the subset
        let subsetName: LocalizedStringResource
        switch n {
        case 2:
            subsetName = LocalizedStringResource("two", bundle: .module)
        case 3:
            subsetName = LocalizedStringResource("three", bundle: .module)
        case 4:
            subsetName = LocalizedStringResource("four", bundle: .module)
        default:
            subsetName = LocalizedStringResource("\(n)", bundle: .module)
        }

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