//
//  NakedSubsets.swift
//  SudokuCore
//
//  Created by Claude on 29/01/2025.
//

import Foundation

// MARK: - Naked Subset Technique (Generic for Pairs, Triples, Quads)
extension HintFinder {
    /// Find naked subsets of size n (2 for pairs, 3 for triples, 4 for quads)
    static func findNakedSubsets(n: Int, technique: HintTechnique, in state: BoardState)
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

    private static func findNakedSubsetsInUnit(
        n: Int,
        unit: SudokuUnit,
        technique: HintTechnique,
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
                    if ProcessInfo.processInfo.environment["SUDOKU_DEBUG_NAKED"] != nil {
                        print(
                            "[NakedSubsetDebug] n=\(n) unit=\(unit) positions=\(subsetPositions) digits=\(Array(allCandidates).sorted()) removals=\(removals.map { $0.debugDescription })"
                        )
                    }
                    return HintStep(
                        actions: removals,
                        technique: technique,
                        explanation: nakedSubsetExplanation(
                            indices: subsetPositions,
                            digits: Array(allCandidates).sorted(),
                            orientation: unit.orientation,
                            excludeIndices: excludeIndices,
                            n: n,
                            state: state
                        )
                    )
                }
            }
        }

        return nil
    }

    private static func nakedSubsetExplanation(
        indices: Set<Puzzle.Index>,
        digits: [Int],
        orientation: Puzzle.Index.Orientation,
        excludeIndices: Set<Puzzle.Index>,
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

        // Step 1: Identify the naked subset
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource(
                    "Look at these \(subsetName) cells in the same \(orientation.displayName). Together, they contain only \(subsetName) candidates: \(digits.formattedList()).",
                    bundle: .module),
                highlightedCells: indices.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Explain the constraint
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource(
                    "These \(subsetName) digits (\(digits.formattedList())) must go in these \(subsetName) cells, though we don't know the exact arrangement yet.",
                    bundle: .module),
                highlightedCells: indices.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: state.pencilMarks[index.row][index.column],
                        highlightType: .action
                    )
                }
            )
        )

        // Step 3: Show the implications
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource(
                    "This means \(digits.formattedList()) cannot appear in any other cells in this \(orientation.displayName).",
                    bundle: .module),
                highlightedCells: indices.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: state.pencilMarks[index.row][index.column],
                        highlightType: .action
                    )
                }
                    + excludeIndices.map { index in
                        HintExplanationStepHighlight(
                            cell: index,
                            candidates: state.pencilMarks[index.row][index.column],
                            highlightType: .warning
                        )
                    }
            )
        )

        return steps
    }
}
