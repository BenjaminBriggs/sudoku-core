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
            // Collect rows/columns where digit appears as candidate in exactly 2 cells
            let rowLinks = strongLinks(
                for: digit, grid: grid, pencilMarks: pencilMarks, units: [.row]
            )
            let colLinks = strongLinks(
                for: digit, grid: grid, pencilMarks: pencilMarks, units: [.column]
            )

            // For each (row link, column link) pair, check if any two endpoints share a box
            for rowLink in rowLinks {
                for colLink in colLinks {
                    let rowEndpoints = [rowLink.cellA, rowLink.cellB]
                    let colEndpoints = [colLink.cellA, colLink.cellB]

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
                                        reasoning: HintReasoning(
                                            actions: removals,
                                            focusDigits: [digit],
                                            units: [.row(rowLink.cellA.row), .column(colLink.cellA.column), .house(rowEndpoint.houseNumber)],
                                            components: [
                                                .base([rowEndpoint, colEndpoint], candidates: [digit]),
                                                .wing([rowTip, colTip], candidates: [digit]),
                                                .eliminated(eliminationCells, candidates: [digit])
                                            ]
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
}
