//
//  EmptyRectangle.swift
//  SudokuCore
//
//  Created by Claude on 25/02/2026.
//

import Foundation

// MARK: - Empty Rectangle Technique
extension HintFinder {
    /// Implements the Empty Rectangle technique.
    ///
    /// An Empty Rectangle occurs when a digit's candidates within a box span more than
    /// one row and more than one column (forming an L or cross shape). A conjugate pair
    /// (strong link) in a row or column outside the box connects to the ER box, enabling
    /// an elimination at the intersection point.
    ///
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first Empty Rectangle elimination found, or `nil`.
    static func findEmptyRectangle(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for digit in 1...9 {
            // For each box, check if digit candidates form an ER pattern
            for boxIndex in 0..<9 {
                let boxCells = LookupTables.boxCells[boxIndex]
                let boxRowStart = (boxIndex / 3) * 3
                let boxColStart = (boxIndex % 3) * 3

                // Collect candidate positions for digit in this box
                var candidatePositions: [Puzzle.Index] = []
                for cell in boxCells {
                    if grid[cell.row][cell.column] == 0,
                       pencilMarks[cell.row][cell.column].contains(digit) {
                        candidatePositions.append(cell)
                    }
                }

                if candidatePositions.count < 2 { continue }

                // Check rows and columns within the box that have candidates
                let candidateRows = Set(candidatePositions.map(\.row))
                let candidateCols = Set(candidatePositions.map(\.column))

                // Must span more than one row AND more than one column (otherwise it's a locked candidate)
                if candidateRows.count < 2 || candidateCols.count < 2 { continue }

                // For each row in the box that has candidates, try it as the "ER row"
                // For each column in the box that has candidates, try it as the "ER column"
                // The ER intersection point is (erRow, erCol)
                for erRow in candidateRows {
                    for erCol in candidateCols {
                        // Check: all candidates not in erRow must be in erCol,
                        // and all candidates not in erCol must be in erRow
                        let valid = candidatePositions.allSatisfy { pos in
                            pos.row == erRow || pos.column == erCol
                        }
                        if valid == false { continue }

                        // Now look for strong links on this digit in rows outside the box
                        // that have one endpoint in erCol
                        if let hint = findERWithRowLink(
                            digit: digit, erRow: erRow, erCol: erCol,
                            boxRowStart: boxRowStart, boxColStart: boxColStart,
                            candidatePositions: candidatePositions,
                            grid: grid, pencilMarks: pencilMarks
                        ) {
                            return hint
                        }

                        // Look for strong links on this digit in columns outside the box
                        // that have one endpoint in erRow
                        if let hint = findERWithColLink(
                            digit: digit, erRow: erRow, erCol: erCol,
                            boxRowStart: boxRowStart, boxColStart: boxColStart,
                            candidatePositions: candidatePositions,
                            grid: grid, pencilMarks: pencilMarks
                        ) {
                            return hint
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Searches for an Empty Rectangle elimination using a strong link in a row.
    ///
    /// The strong link has one endpoint in the same column as the ER column.
    /// The elimination occurs at the intersection of the other endpoint's column and the ER row.
    private static func findERWithRowLink(
        digit: Int, erRow: Int, erCol: Int,
        boxRowStart: Int, boxColStart: Int,
        candidatePositions: [Puzzle.Index],
        grid: [[Int]], pencilMarks: [[Set<Int>]]
    ) -> HintStep? {
        for linkRow in 0..<9 {
            // Skip rows that are in the same box
            if linkRow >= boxRowStart && linkRow < boxRowStart + 3 { continue }

            // Find cells in this row with digit as candidate
            var linkCols: [Int] = []
            for col in 0..<9 {
                if grid[linkRow][col] == 0, pencilMarks[linkRow][col].contains(digit) {
                    linkCols.append(col)
                }
            }

            // Must be exactly 2 for a strong link
            if linkCols.count != 2 { continue }

            // Check if one endpoint is in the ER column
            for i in 0..<2 {
                if linkCols[i] == erCol {
                    // The connecting endpoint is at (linkRow, erCol)
                    // The other endpoint is at (linkRow, linkCols[1-i])
                    let otherCol = linkCols[1 - i]

                    // Elimination target is at (erRow, otherCol)
                    let target = Puzzle.Index(row: erRow, column: otherCol)

                    // The target must not be in the same box as the ER
                    if target.row >= boxRowStart && target.row < boxRowStart + 3 &&
                       target.column >= boxColStart && target.column < boxColStart + 3 {
                        continue
                    }

                    if grid[target.row][target.column] == 0,
                       pencilMarks[target.row][target.column].contains(digit) {
                        let connectingCell = Puzzle.Index(row: linkRow, column: erCol)
                        let otherLinkCell = Puzzle.Index(row: linkRow, column: otherCol)

                        return HintStep(
                            actions: [HintAction(position: target, ruleOut: digit)],
                            technique: .emptyRectangle,
                            explanation: emptyRectangleExplanation(
                                digit: digit,
                                boxCandidates: candidatePositions,
                                strongLink: [connectingCell, otherLinkCell],
                                eliminationCell: target
                            )
                        )
                    }
                }
            }
        }
        return nil
    }

    /// Searches for an Empty Rectangle elimination using a strong link in a column.
    ///
    /// The strong link has one endpoint in the same row as the ER row.
    /// The elimination occurs at the intersection of the other endpoint's row and the ER column.
    private static func findERWithColLink(
        digit: Int, erRow: Int, erCol: Int,
        boxRowStart: Int, boxColStart: Int,
        candidatePositions: [Puzzle.Index],
        grid: [[Int]], pencilMarks: [[Set<Int>]]
    ) -> HintStep? {
        for linkCol in 0..<9 {
            // Skip columns that are in the same box
            if linkCol >= boxColStart && linkCol < boxColStart + 3 { continue }

            // Find cells in this column with digit as candidate
            var linkRows: [Int] = []
            for row in 0..<9 {
                if grid[row][linkCol] == 0, pencilMarks[row][linkCol].contains(digit) {
                    linkRows.append(row)
                }
            }

            // Must be exactly 2 for a strong link
            if linkRows.count != 2 { continue }

            // Check if one endpoint is in the ER row
            for i in 0..<2 {
                if linkRows[i] == erRow {
                    // The connecting endpoint is at (erRow, linkCol)
                    // The other endpoint is at (linkRows[1-i], linkCol)
                    let otherRow = linkRows[1 - i]

                    // Elimination target is at (otherRow, erCol)
                    let target = Puzzle.Index(row: otherRow, column: erCol)

                    // The target must not be in the same box as the ER
                    if target.row >= boxRowStart && target.row < boxRowStart + 3 &&
                       target.column >= boxColStart && target.column < boxColStart + 3 {
                        continue
                    }

                    if grid[target.row][target.column] == 0,
                       pencilMarks[target.row][target.column].contains(digit) {
                        let connectingCell = Puzzle.Index(row: erRow, column: linkCol)
                        let otherLinkCell = Puzzle.Index(row: otherRow, column: linkCol)

                        return HintStep(
                            actions: [HintAction(position: target, ruleOut: digit)],
                            technique: .emptyRectangle,
                            explanation: emptyRectangleExplanation(
                                digit: digit,
                                boxCandidates: candidatePositions,
                                strongLink: [connectingCell, otherLinkCell],
                                eliminationCell: target
                            )
                        )
                    }
                }
            }
        }
        return nil
    }

    /// Generates a multi-step explanation for an Empty Rectangle elimination.
    ///
    /// - Parameters:
    ///   - digit: The candidate digit involved.
    ///   - boxCandidates: The candidate positions in the ER box.
    ///   - strongLink: The two cells forming the conjugate pair.
    ///   - eliminationCell: The cell from which the digit will be eliminated.
    /// - Returns: An array of `HintExplanationStep` values.
    private static func emptyRectangleExplanation(
        digit: Int,
        boxCandidates: [Puzzle.Index],
        strongLink: [Puzzle.Index],
        eliminationCell: Puzzle.Index
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []

        // Step 1: Identify the ER box
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at the candidates for digit \(digit) in this box — they form an Empty Rectangle pattern.", bundle: .module),
                highlightedCells: boxCandidates.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 2: Show the strong link
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("There is also a strong link for \(digit) — it appears exactly twice in this line.", bundle: .module),
                highlightedCells: strongLink.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )

        // Step 3: Explain the logic
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("One end of the strong link aligns with the rectangle. If \(digit) is not at that end, the rectangle forces \(digit) into a position that eliminates it from the target cell.", bundle: .module),
                highlightedCells: strongLink.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                } + boxCandidates.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )

        // Step 4: Show elimination
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Therefore, \(digit) can be eliminated from this cell.", bundle: .module),
                highlightedCells: [
                    HintExplanationStepHighlight(
                        cell: eliminationCell,
                        candidates: [digit],
                        highlightType: .warning
                    )
                ] + strongLink.map { index in
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
