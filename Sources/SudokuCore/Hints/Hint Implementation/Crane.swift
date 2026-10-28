//
//  Crane.swift
//  SudokuCore
//
//  Created by Claude on 27/10/2026.
//
import Foundation

// MARK: - Crane Technique
extension HintFinder {
    /// Finds a Crane: a strong link for a digit in a box and another in a row or column, with
    /// one end of each seeing the other.
    ///
    /// The digit is at one end of each strong link. If it isn't at the box link's far end, it's
    /// at the box link's joined end, which rules it out of the line link's joined end and puts
    /// it at the line link's far end. Either way one of the two far ends holds the digit, so any
    /// cell seeing both loses it. Skyscrapers and Two-String Kites are the same chain with both
    /// links in lines.
    ///
    /// - Parameter state: The current board state snapshot.
    /// - Returns: A `HintStep` describing the first Crane elimination found, or `nil`.
    static func findCrane(in state: BoardState) -> HintStep? {
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        for digit in 1...9 {
            let boxLinks = strongLinks(for: digit, grid: grid, pencilMarks: pencilMarks, units: [.box])
            guard boxLinks.isEmpty == false else { continue }
            let lineLinks = strongLinks(for: digit, grid: grid, pencilMarks: pencilMarks, units: [.row, .column])

            for boxLink in boxLinks {
                for lineLink in lineLinks {
                    let boxEnds = [boxLink.cellA, boxLink.cellB]
                    let lineEnds = [lineLink.cellA, lineLink.cellB]
                    let allFour = Set(boxEnds + lineEnds)
                    // A line link sharing a cell with the box link is the same box's pair seen again
                    if allFour.count < 4 { continue }

                    for bi in 0..<2 {
                        for li in 0..<2 {
                            let boxJoint = boxEnds[bi]
                            let lineJoint = lineEnds[li]
                            guard LookupTables.cellNeighbours[boxJoint.row][boxJoint.column].contains(lineJoint) else { continue }

                            let boxTip = boxEnds[1 - bi]
                            let lineTip = lineEnds[1 - li]
                            let commonNeighbours = LookupTables.cellNeighbours[boxTip.row][boxTip.column]
                                .intersection(LookupTables.cellNeighbours[lineTip.row][lineTip.column])

                            var removals: [HintAction] = []
                            var eliminationCells = Set<Puzzle.Index>()
                            for position in commonNeighbours where allFour.contains(position) == false {
                                if grid[position.row][position.column] == 0,
                                   pencilMarks[position.row][position.column].contains(digit) {
                                    removals.append(HintAction(position: position, ruleOut: digit))
                                    eliminationCells.insert(position)
                                }
                            }

                            if removals.isEmpty == false {
                                let lineUnit: SudokuUnit = lineLink.cellA.row == lineLink.cellB.row
                                    ? .row(lineLink.cellA.row)
                                    : .column(lineLink.cellA.column)
                                return HintStep(
                                    actions: removals,
                                    technique: .crane,
                                    reasoning: HintReasoning(
                                        actions: removals,
                                        focusDigits: [digit],
                                        units: [.house(boxJoint.houseNumber), lineUnit],
                                        components: [
                                            .base([boxJoint, lineJoint], candidates: [digit]),
                                            .wing([boxTip, lineTip], candidates: [digit]),
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
