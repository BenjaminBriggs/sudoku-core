//
//  TwoStringKite.swift
//  SudokuCore
//
//  Created by Claude on 25/02/2026.
//

import Foundation

// MARK: - Two-String Kite Technique
extension HintFinder {
    /// Implements the Two-String Kite technique.
    ///
    /// A Two-String Kite occurs when a digit has a strong link (exactly two candidates)
    /// in a row and another strong link in a column, with one endpoint from each link
    /// sharing the same box. The other two endpoints (the "kite tips") allow eliminations
    /// from any cell that sees both tips.
    ///
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first Two-String Kite elimination found, or `nil`.
    static func findTwoStringKite(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for digit in 1...9 {
            // Collect rows where digit appears as candidate in exactly 2 cells
            var rowLinks: [(row: Int, cols: (Int, Int))] = []
            for row in 0..<9 {
                var cols: [Int] = []
                for col in 0..<9 {
                    if grid[row][col] == 0, pencilMarks[row][col].contains(digit) {
                        cols.append(col)
                    }
                }
                if cols.count == 2 {
                    rowLinks.append((row: row, cols: (cols[0], cols[1])))
                }
            }

            // Collect columns where digit appears as candidate in exactly 2 cells
            var colLinks: [(col: Int, rows: (Int, Int))] = []
            for col in 0..<9 {
                var rows: [Int] = []
                for row in 0..<9 {
                    if grid[row][col] == 0, pencilMarks[row][col].contains(digit) {
                        rows.append(row)
                    }
                }
                if rows.count == 2 {
                    colLinks.append((col: col, rows: (rows[0], rows[1])))
                }
            }

            // For each (row link, column link) pair, check if any two endpoints share a box
            for rowLink in rowLinks {
                for colLink in colLinks {
                    let rowEndpoints = [
                        Puzzle.Index(row: rowLink.row, column: rowLink.cols.0),
                        Puzzle.Index(row: rowLink.row, column: rowLink.cols.1)
                    ]
                    let colEndpoints = [
                        Puzzle.Index(row: colLink.rows.0, column: colLink.col),
                        Puzzle.Index(row: colLink.rows.1, column: colLink.col)
                    ]

                    // Check all 4 endpoint combinations for shared box
                    for ri in 0..<2 {
                        for ci in 0..<2 {
                            let rowEndpoint = rowEndpoints[ri]
                            let colEndpoint = colEndpoints[ci]

                            // Skip if they are the same cell
                            if rowEndpoint == colEndpoint { continue }

                            // Check if these two endpoints share a box
                            if rowEndpoint.houseNumber == colEndpoint.houseNumber {
                                // The other two endpoints are the kite tips
                                let rowTip = rowEndpoints[1 - ri]
                                let colTip = colEndpoints[1 - ci]

                                // Skip if any tips overlap with box-sharing endpoints
                                let allFour = Set([rowEndpoint, colEndpoint, rowTip, colTip])
                                if allFour.count < 4 { continue }

                                // Find cells that see both tips and contain the digit
                                let tipANeighbours = LookupTables.cellNeighbours[rowTip.row][rowTip.column]
                                let tipBNeighbours = LookupTables.cellNeighbours[colTip.row][colTip.column]
                                let commonNeighbours = tipANeighbours.intersection(tipBNeighbours)

                                var removals: [HintAction] = []
                                var eliminationCells = Set<Puzzle.Index>()

                                for position in commonNeighbours {
                                    if allFour.contains(position) { continue }
                                    if grid[position.row][position.column] == 0,
                                       pencilMarks[position.row][position.column].contains(digit) {
                                        removals.append(HintAction(position: position, ruleOut: digit))
                                        eliminationCells.insert(position)
                                    }
                                }

                                if removals.isEmpty == false {
                                    return HintStep(
                                        actions: removals,
                                        technique: .twoStringKite,
                                        explanation: twoStringKiteExplanation(
                                            digit: digit,
                                            allPositions: allFour,
                                            tipPositions: [rowTip, colTip],
                                            boxPositions: [rowEndpoint, colEndpoint],
                                            eliminationCells: eliminationCells
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Generates a multi-step explanation for a Two-String Kite elimination.
    ///
    /// - Parameters:
    ///   - digit: The candidate digit involved.
    ///   - allPositions: All four cells forming the kite.
    ///   - tipPositions: The two kite tip cells.
    ///   - boxPositions: The two cells sharing a box.
    ///   - eliminationCells: Cells that will have the digit eliminated.
    /// - Returns: An array of `HintExplanationStep` values.
    private static func twoStringKiteExplanation(
        digit: Int,
        allPositions: Set<Puzzle.Index>,
        tipPositions: [Puzzle.Index],
        boxPositions: [Puzzle.Index],
        eliminationCells: Set<Puzzle.Index>
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        // Step 1: Identify the pattern
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at these cells forming a Two-String Kite pattern for digit \(digit):", bundle: .module),
                highlightedCells: allPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Explain the strong links
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Digit \(digit) appears exactly twice in a row and exactly twice in a column, with one cell from each sharing the same box.", bundle: .module),
                highlightedCells: allPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )

        // Step 3: Highlight the kite tips
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("One of these two cells must contain \(digit).", bundle: .module),
                highlightedCells: tipPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )

        // Step 4: Show eliminations
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Any cell that can see both of these cells cannot contain \(digit).", bundle: .module),
                highlightedCells: eliminationCells.map { pos in
                    HintExplanationStepHighlight(
                        cell: pos,
                        candidates: [digit],
                        highlightType: .warning
                    )
                } + tipPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )

        return steps
    }
}
