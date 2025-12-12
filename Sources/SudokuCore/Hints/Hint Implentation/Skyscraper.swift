//
//  Skyscraper.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 10/03/2025.
//
import Foundation

// MARK: - Skyscraper Technique
extension HintFinder {
    /// Implements the Skyscraper technique
    /// A Skyscraper happens when a digit appears exactly twice in each of two rows/columns,
    /// and one of the candidates in each row/column shares the same column/row.
    static func findSkyscraper(in state: BoardState) -> HintStep? {
        // First check for row-based Skyscraper
        if let hint = findRowBasedSkyscraper(in: state) {
            return hint
        }
        
        // Then check for column-based Skyscraper
        if let hint = findColumnBasedSkyscraper(in: state) {
            return hint
        }
        
        return nil
    }
    
    private static func findRowBasedSkyscraper(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // For each digit
        for digit in 1...9 {
            // Build a map of rows -> columns where digit appears as a candidate
            // Use array indexed by row for better performance
            var rowToCols: [[Int]] = Array(repeating: [], count: 9)
            var validRows: [Int] = []
            validRows.reserveCapacity(9)

            for row in 0..<9 {
                var candidateCols: [Int] = []
                candidateCols.reserveCapacity(9)

                for col in 0..<9 {
                    if grid[row][col] == 0 {
                        if pencilMarks[row][col].contains(digit) {
                            candidateCols.append(col)
                        }
                    }
                }

                // Only consider rows with exactly two candidate positions for this digit
                if candidateCols.count == 2 {
                    rowToCols[row] = candidateCols
                    validRows.append(row)
                }
            }


            // We need at least 2 rows with 2 or more candidates each
            if validRows.count < 2 {
                continue
            }

            // Check all pairs of rows (already sorted from iteration order)
            for i in 0..<validRows.count-1 {
                for j in i+1..<validRows.count {
                    let row1 = validRows[i]
                    let row2 = validRows[j]

                    let cols1 = rowToCols[row1]
                    let cols2 = rowToCols[row2]

                    let pairs1 = HintFinder.combinations(of: cols1, choose: 2)
                    let pairs2 = HintFinder.combinations(of: cols2, choose: 2)

                    for pair1 in pairs1 {
                        let set1 = Set(pair1)
                        for pair2 in pairs2 {
                            let set2 = Set(pair2)
                            let commonCols = set1.intersection(set2)
                            if commonCols.count != 1 {
                                continue
                            }

                            guard let commonCol = commonCols.first,
                                  let endCol1 = pair1.first(where: { $0 != commonCol }),
                                  let endCol2 = pair2.first(where: { $0 != commonCol })
                            else { continue }

                            let skyscraperPositions = Set([
                                Puzzle.Index(row: row1, column: commonCol),
                                Puzzle.Index(row: row1, column: endCol1),
                                Puzzle.Index(row: row2, column: commonCol),
                                Puzzle.Index(row: row2, column: endCol2)
                            ])

                            var removals: [HintAction] = []
                            var eliminationCells = Set<Puzzle.Index>()

                            let end1Pos = Puzzle.Index(row: row1, column: endCol1)
                            let end2Pos = Puzzle.Index(row: row2, column: endCol2)

                            let end1Neighbors = LookupTables.cellNeighbours[end1Pos.row][end1Pos.column]
                            let end2Neighbors = LookupTables.cellNeighbours[end2Pos.row][end2Pos.column]
                            let commonNeighbors = end1Neighbors.intersection(end2Neighbors)

                            for position in commonNeighbors {
                                if skyscraperPositions.contains(position) {
                                    continue
                                }

                                if grid[position.row][position.column] == 0,
                                   pencilMarks[position.row][position.column].contains(digit) {
                                    removals.append(HintAction(position: position, ruleOut: digit))
                                    eliminationCells.insert(position)
                                }
                            }

                            if removals.isEmpty == false {
                                return HintStep(
                                    actions: removals,
                                    technique: .skyscraper,
                                    explanation: skyscraperExplanation(
                                        digit: digit,
                                        skyscraperPositions: skyscraperPositions,
                                        endPositions: [
                                            Puzzle.Index(row: row1, column: endCol1),
                                            Puzzle.Index(row: row2, column: endCol2)
                                        ],
                                        orientation: .row,
                                        eliminationCells: eliminationCells,
                                        state: state
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func findColumnBasedSkyscraper(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // For each digit
        for digit in 1...9 {
            // Build a map of columns -> rows where digit appears as a candidate
            // Use array indexed by column for better performance
            var colToRows: [[Int]] = Array(repeating: [], count: 9)
            var validCols: [Int] = []
            validCols.reserveCapacity(9)

            for col in 0..<9 {
                var candidateRows: [Int] = []
                candidateRows.reserveCapacity(9)

                for row in 0..<9 {
                    if grid[row][col] == 0 {
                        if pencilMarks[row][col].contains(digit) {
                            candidateRows.append(row)
                        }
                    }
                }

                // Only consider columns with exactly two candidate positions for this digit
                if candidateRows.count == 2 {
                    colToRows[col] = candidateRows
                    validCols.append(col)
                }
            }


            // We need at least 2 columns with 2 or more candidates each
            if validCols.count < 2 {
                continue
            }

            // Check all pairs of columns (already sorted from iteration order)
            for i in 0..<validCols.count-1 {
                for j in i+1..<validCols.count {
                    let col1 = validCols[i]
                    let col2 = validCols[j]

                    let rows1 = colToRows[col1]
                    let rows2 = colToRows[col2]

                    let pairs1 = HintFinder.combinations(of: rows1, choose: 2)
                    let pairs2 = HintFinder.combinations(of: rows2, choose: 2)

                    for pair1 in pairs1 {
                        let set1 = Set(pair1)
                        for pair2 in pairs2 {
                            let set2 = Set(pair2)
                            let commonRows = set1.intersection(set2)
                            if commonRows.count != 1 {
                                continue
                            }

                            guard let commonRow = commonRows.first,
                                  let endRow1 = pair1.first(where: { $0 != commonRow }),
                                  let endRow2 = pair2.first(where: { $0 != commonRow })
                            else { continue }

                            let skyscraperPositions = Set([
                                Puzzle.Index(row: commonRow, column: col1),
                                Puzzle.Index(row: endRow1, column: col1),
                                Puzzle.Index(row: commonRow, column: col2),
                                Puzzle.Index(row: endRow2, column: col2)
                            ])

                            var removals: [HintAction] = []
                            var eliminationCells = Set<Puzzle.Index>()

                            let end1Pos = Puzzle.Index(row: endRow1, column: col1)
                            let end2Pos = Puzzle.Index(row: endRow2, column: col2)

                            let end1Neighbors = LookupTables.cellNeighbours[end1Pos.row][end1Pos.column]
                            let end2Neighbors = LookupTables.cellNeighbours[end2Pos.row][end2Pos.column]
                            let commonNeighbors = end1Neighbors.intersection(end2Neighbors)

                            for position in commonNeighbors {
                                if skyscraperPositions.contains(position) {
                                    continue
                                }

                                if grid[position.row][position.column] == 0,
                                   pencilMarks[position.row][position.column].contains(digit) {
                                    removals.append(HintAction(position: position, ruleOut: digit))
                                    eliminationCells.insert(position)
                                }
                            }

                            if removals.isEmpty == false {
                                return HintStep(
                                    actions: removals,
                                    technique: .skyscraper,
                                    explanation: skyscraperExplanation(
                                        digit: digit,
                                        skyscraperPositions: skyscraperPositions,
                                        endPositions: [
                                            Puzzle.Index(row: endRow1, column: col1),
                                            Puzzle.Index(row: endRow2, column: col2)
                                        ],
                                        orientation: .column,
                                        eliminationCells: eliminationCells,
                                        state: state
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private static func skyscraperExplanation(
        digit: Int,
        skyscraperPositions: Set<Puzzle.Index>,
        endPositions: [Puzzle.Index],
        orientation: Puzzle.Index.Orientation,
        eliminationCells: Set<Puzzle.Index>,
        state: BoardState
    ) -> [HintExplanationStep] {
        var steps: [HintExplanationStep] = []
        
        // Step 1: Identify the Skyscraper pattern
        let baseText = orientation == .row ? LocalizedStringResource("rows", bundle: .module) : LocalizedStringResource("columns", bundle: .module)
        let crossText = orientation == .row ? LocalizedStringResource("columns", bundle: .module) : LocalizedStringResource("rows", bundle: .module)

        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Look at these cells forming a Skyscraper pattern for digit \(digit):", bundle: .module),
                highlightedCells: skyscraperPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .primary
                    )
                }
            )
        )
        
        // Step 2: Explain the pattern
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("The digit \(digit) appears exactly twice in two different \(baseText), with one candidate in each \(baseText) sharing the same \(crossText).", bundle: .module),
                highlightedCells: skyscraperPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )
        
        // Step 3: Highlight the roof endpoints
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("These two cells form the 'roof' of the Skyscraper. One of these cells must contain \(digit).", bundle: .module),
                highlightedCells: endPositions.map { index in
                    HintExplanationStepHighlight(
                        cell: index,
                        candidates: [digit],
                        highlightType: .action
                    )
                }
            )
        )
        
        // Step 4: Show the implications
        steps.append(
            HintExplanationStep(
                text: LocalizedStringResource("Any cell that can see both 'roof' cells cannot contain \(digit), as this would create a contradiction.", bundle: .module),
                highlightedCells: eliminationCells.map { pos in
                    HintExplanationStepHighlight(
                        cell: pos,
                        candidates: [digit],
                        highlightType: .warning
                    )
                } + endPositions.map { index in
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
