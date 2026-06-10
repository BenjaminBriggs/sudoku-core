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
    ///   - technique: The `HintTechnique` to label the result with.
    ///   - state: The current immutable board snapshot to analyse.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no naked subset is found.
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

    /// Searches a single unit (row, column, or box) for a naked subset of size `n`.
    ///
    /// Collects empty cells whose candidate count is at most `n`, then checks every combination
    /// of `n` such cells. If the union of their candidates contains exactly `n` digits, those
    /// digits can be removed from all other cells in the unit. Uses a bitset for fast union counting.
    /// - Parameters:
    ///   - n: The subset size (2 = pair, 3 = triple, 4 = quad).
    ///   - unit: The row, column, or box to search.
    ///   - technique: The `HintTechnique` to label the result with.
    ///   - state: The current board state.
    /// - Returns: A `HintStep` with candidate removal actions, or `nil` if no naked subset is found.
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
                        ),
                        reasoning: .make(
                            actions: removals,
                            focusDigits: Array(allCandidates).sorted(),
                            units: [unit],
                            components: [
                                .make(.subset, subsetPositions, in: state, unit: unit),
                                .make(.eliminated, excludeIndices, in: state, unit: unit)
                            ]
                        )
                    )
                }
            }
        }

        return nil
    }

    /// Builds the explanation steps for a naked subset hint.
    ///
    /// Generates three steps: (1) highlight the subset cells with `.primary`, (2) show their
    /// shared candidates with `.action` to explain the constraint, and (3) highlight affected
    /// cells with `.warning` to show which candidates will be removed.
    /// - Parameters:
    ///   - indices: The positions of the cells forming the naked subset.
    ///   - digits: The sorted list of shared candidate digits.
    ///   - orientation: Whether this is a row, column, or box.
    ///   - excludeIndices: Other cells in the unit that have candidates to remove.
    ///   - n: The subset size (2, 3, or 4).
    ///   - state: The current board state for pencil mark lookups.
    /// - Returns: An array of `HintExplanationStep` describing the naked subset deduction.
    private static func nakedSubsetExplanation(
        indices: Set<Puzzle.Index>,
        digits: [Int],
        orientation: Puzzle.Index.Orientation,
        excludeIndices: Set<Puzzle.Index>,
        n: Int,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        let subsetName = localisedCountName(n)

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
