//
//  Skyscraper.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 10/03/2025.
//
import Foundation

// MARK: - Skyscraper Technique
extension HintFinder {
    /// Implements the Skyscraper technique.
    ///
    /// A Skyscraper happens when a digit appears exactly twice in each of two rows/columns,
    /// and one of the candidates in each row/column shares the same column/row.
    /// - Parameter state: An immutable snapshot of the current board.
    /// - Returns: A `HintStep` describing the first Skyscraper elimination found, or `nil` if none exists.
    static func findSkyscraper(in state: BoardState) -> HintStep? {
        if let hint = findSkyscraperInOrientation(baseOrientation: .row, in: state) {
            return hint
        }
        if let hint = findSkyscraperInOrientation(baseOrientation: .column, in: state) {
            return hint
        }
        return nil
    }

    /// Searches for a Skyscraper pattern along a single orientation (rows or columns).
    ///
    /// Iterates over each digit 1-9, collecting base lines where that digit appears as a candidate
    /// in exactly two positions. For each pair of such base lines, checks whether one candidate in
    /// each shares the same cross line (the "base" of the skyscraper). The two non-shared endpoints
    /// form the "roof" -- any cell that sees both roof cells can have the digit eliminated.
    ///
    /// - Parameters:
    ///   - baseOrientation: Whether to treat rows or columns as the base lines.
    ///   - state: The current board state snapshot.
    /// - Returns: A `HintStep` describing the first Skyscraper found, or `nil` if none exists.
    private static func findSkyscraperInOrientation(
        baseOrientation: Puzzle.Index.Orientation,
        in state: BoardState
    ) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // The `makeIndex` closure abstracts over the orientation so the same algorithm
        // works for both row-based and column-based skyscrapers. When baseOrientation is .row,
        // `base` maps to the row and `cross` maps to the column; for .column it is reversed.
        let makeIndex: (Int, Int) -> Puzzle.Index = baseOrientation == .row
            ? { base, cross in Puzzle.Index(row: base, column: cross) }
            : { base, cross in Puzzle.Index(row: cross, column: base) }

        // For each digit
        for digit in 1...9 {
            // Build a map of base lines -> cross lines where digit appears as a candidate
            // Use array indexed by base line for better performance
            var baseLineToCrossLines: [[Int]] = Array(repeating: [], count: 9)
            var validBaseLines: [Int] = []
            validBaseLines.reserveCapacity(9)

            for baseLine in 0..<9 {
                var candidateCrossLines: [Int] = []
                candidateCrossLines.reserveCapacity(9)

                for crossLine in 0..<9 {
                    let index = makeIndex(baseLine, crossLine)
                    if grid[index.row][index.column] == 0 {
                        if pencilMarks[index.row][index.column].contains(digit) {
                            candidateCrossLines.append(crossLine)
                        }
                    }
                }

                // Only consider base lines with exactly two candidate positions for this digit
                if candidateCrossLines.count == 2 {
                    baseLineToCrossLines[baseLine] = candidateCrossLines
                    validBaseLines.append(baseLine)
                }
            }

            // We need at least 2 base lines with exactly 2 candidates each
            if validBaseLines.count < 2 {
                continue
            }

            // Check all pairs of base lines (already sorted from iteration order)
            for i in 0..<validBaseLines.count-1 {
                for j in i+1..<validBaseLines.count {
                    let baseLine1 = validBaseLines[i]
                    let baseLine2 = validBaseLines[j]

                    let crossLines1 = baseLineToCrossLines[baseLine1]
                    let crossLines2 = baseLineToCrossLines[baseLine2]

                    let pairs1 = HintFinder.combinations(of: crossLines1, choose: 2)
                    let pairs2 = HintFinder.combinations(of: crossLines2, choose: 2)

                    for pair1 in pairs1 {
                        let set1 = Set(pair1)
                        for pair2 in pairs2 {
                            let set2 = Set(pair2)
                            let commonCrossLines = set1.intersection(set2)
                            if commonCrossLines.count != 1 {
                                continue
                            }

                            guard let commonCross = commonCrossLines.first,
                                  let endCross1 = pair1.first(where: { $0 != commonCross }),
                                  let endCross2 = pair2.first(where: { $0 != commonCross })
                            else { continue }

                            // The four cells forming the skyscraper: two share the common
                            // cross line (the "base"), and the other two are the "roof" endpoints
                            let skyscraperPositions = Set([
                                makeIndex(baseLine1, commonCross),
                                makeIndex(baseLine1, endCross1),
                                makeIndex(baseLine2, commonCross),
                                makeIndex(baseLine2, endCross2)
                            ])

                            var removals: [HintAction] = []
                            var eliminationCells = Set<Puzzle.Index>()

                            let end1Pos = makeIndex(baseLine1, endCross1)
                            let end2Pos = makeIndex(baseLine2, endCross2)

                            // Cells that can see both roof endpoints can have the digit eliminated
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
                                let roof = Set([end1Pos, end2Pos])
                                return HintStep(
                                    actions: removals,
                                    technique: .skyscraper,
                                    reasoning: HintReasoning(
                                        actions: removals,
                                        focusDigits: [digit],
                                        units: [
                                            SudokuUnit(orientation: baseOrientation, index: baseLine1),
                                            SudokuUnit(orientation: baseOrientation, index: baseLine2)
                                        ],
                                        components: [
                                            .base(skyscraperPositions.subtracting(roof), candidates: [digit]),
                                            .wing(roof, candidates: [digit]),
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

        return nil
    }
}
