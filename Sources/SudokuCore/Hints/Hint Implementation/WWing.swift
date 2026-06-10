//
//  WWing.swift
//  SudokuCore
//
//  Created by Claude on 25/02/2026.
//

import Foundation

// MARK: - W-Wing Technique
extension HintFinder {
    /// Implements the W-Wing technique.
    ///
    /// A W-Wing occurs when two bi-value cells with the same candidate pair {X, Y} are
    /// connected by a strong link on one of their digits. The other digit can then be
    /// eliminated from any cell that sees both bi-value cells.
    ///
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first W-Wing elimination found, or `nil`.
    static func findWWing(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Collect all bi-value cells and group by their candidate pair
        var biValueGroups: [[Int]: [Puzzle.Index]] = [:]

        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0, pencilMarks[row][col].count == 2 {
                    let key = Array(pencilMarks[row][col]).sorted()
                    biValueGroups[key, default: []].append(Puzzle.Index(row: row, column: col))
                }
            }
        }

        // Sort candidate pairs for deterministic iteration order
        let sortedGroups = biValueGroups
            .filter { $0.value.count >= 2 }
            .sorted { $0.key.lexicographicallyPrecedes($1.key) }

        // No pair of matching bi-value cells means no W-Wing can exist.
        guard sortedGroups.isEmpty == false else { return nil }

        // Compute strong links only for digits that appear in a usable bi-value pair.
        // Strong link = digit appears as candidate in exactly 2 cells in a unit.
        var strongLinksByDigit: [Int: [(cellA: Puzzle.Index, cellB: Puzzle.Index)]] = [:]
        for digit in Set(sortedGroups.flatMap(\.key)) {
            strongLinksByDigit[digit] = Self.strongLinks(
                for: digit,
                grid: grid,
                pencilMarks: pencilMarks,
                units: [.row, .column, .box]
            )
        }

        // For each group of bi-value cells with the same candidates
        for (candidatePair, cells) in sortedGroups {

            let digitX = candidatePair[0]
            let digitY = candidatePair[1]

            // For each pair of bi-value cells
            for i in 0..<cells.count - 1 {
                for j in (i + 1)..<cells.count {
                    let cellA = cells[i]
                    let cellB = cells[j]

                    // Try connecting via strong link on digitX (eliminate digitY)
                    if let hint = tryWWingConnection(
                        cellA: cellA, cellB: cellB,
                        linkDigit: digitX, eliminationDigit: digitY,
                        strongLinks: strongLinksByDigit[digitX] ?? [],
                        grid: grid, pencilMarks: pencilMarks
                    ) {
                        return hint
                    }

                    // Try connecting via strong link on digitY (eliminate digitX)
                    if let hint = tryWWingConnection(
                        cellA: cellA, cellB: cellB,
                        linkDigit: digitY, eliminationDigit: digitX,
                        strongLinks: strongLinksByDigit[digitY] ?? [],
                        grid: grid, pencilMarks: pencilMarks
                    ) {
                        return hint
                    }
                }
            }
        }

        return nil
    }

    /// Attempts to find a W-Wing elimination using a specific strong link digit.
    ///
    /// Checks if any strong link on `linkDigit` connects `cellA` and `cellB` (one link
    /// endpoint is a neighbour of cellA, the other a neighbour of cellB). If connected,
    /// `eliminationDigit` can be removed from cells seeing both bi-value cells.
    ///
    /// - Parameters:
    ///   - cellA: The first bi-value cell.
    ///   - cellB: The second bi-value cell.
    ///   - linkDigit: The digit the strong link is on.
    ///   - eliminationDigit: The digit to eliminate.
    ///   - strongLinks: All strong links for `linkDigit`.
    ///   - grid: The current grid values.
    ///   - pencilMarks: The current pencil marks.
    /// - Returns: A `HintStep` if a valid W-Wing with eliminations is found, or `nil`.
    private static func tryWWingConnection(
        cellA: Puzzle.Index, cellB: Puzzle.Index,
        linkDigit: Int, eliminationDigit: Int,
        strongLinks: [(cellA: Puzzle.Index, cellB: Puzzle.Index)],
        grid: [[Int]], pencilMarks: [[Set<Int>]]
    ) -> HintStep? {
        let neighboursA = LookupTables.cellNeighbours[cellA.row][cellA.column]
        let neighboursB = LookupTables.cellNeighbours[cellB.row][cellB.column]

        for link in strongLinks {
            // The strong link cells must not be the bi-value cells themselves
            if link.cellA == cellA || link.cellA == cellB ||
               link.cellB == cellA || link.cellB == cellB {
                continue
            }

            // Check: one end of strong link sees cellA, other sees cellB
            let aSeesLinkA = neighboursA.contains(link.cellA)
            let aSeesLinkB = neighboursA.contains(link.cellB)
            let bSeesLinkA = neighboursB.contains(link.cellA)
            let bSeesLinkB = neighboursB.contains(link.cellB)

            let connected = (aSeesLinkA && bSeesLinkB) || (aSeesLinkB && bSeesLinkA)
            if connected == false { continue }

            // Find elimination cells: cells seeing both cellA and cellB with eliminationDigit
            let commonNeighbours = neighboursA.intersection(neighboursB)

            var removals: [HintAction] = []
            var eliminationCells = Set<Puzzle.Index>()

            for position in commonNeighbours {
                if position == cellA || position == cellB { continue }
                if grid[position.row][position.column] == 0,
                   pencilMarks[position.row][position.column].contains(eliminationDigit) {
                    removals.append(HintAction(position: position, ruleOut: eliminationDigit))
                    eliminationCells.insert(position)
                }
            }

            if removals.isEmpty == false {
                return HintStep(
                    actions: removals,
                    technique: .wWing,
                    reasoning: HintReasoning(
                        actions: removals,
                        focusDigits: [linkDigit, eliminationDigit],
                        components: [
                            // Both bi-value cells hold exactly this candidate pair.
                            .wing([cellA, cellB], candidates: [linkDigit, eliminationDigit]),
                            .constraint([link.cellA, link.cellB], candidates: [linkDigit]),
                            .eliminated(eliminationCells, candidates: [eliminationDigit])
                        ]
                    )
                )
            }
        }

        return nil
    }
}
