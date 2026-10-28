//
//  BUG.swift
//  SudokuCore
//
//  Created by Claude on 27/10/2026.
//
import Foundation

// MARK: - BUG+1 Technique
extension HintFinder {
    /// Finds a BUG+1 (Bivalue Universal Grave plus one).
    ///
    /// When every empty cell has two candidates and every candidate appears exactly twice in
    /// each row, column and box, the grid is a BUG: it has either no solution or more than
    /// one. If every empty cell but one has two candidates, and taking a single digit out of
    /// that cell would leave a BUG, then a puzzle with one solution needs that digit there.
    ///
    /// Only runs when the board is known to have exactly one solution.
    ///
    /// - Parameter state: The current board state snapshot.
    /// - Returns: A `HintStep` placing the digit, or `nil` if the board isn't a BUG+1.
    static func findBUG(in state: BoardState) -> HintStep? {
        guard state.assumesUniqueSolution else { return nil }
        let grid = state.grid
        let pencilMarks = state.pencilMarks

        // Every empty cell has two candidates, except exactly one with three.
        var extraCell: Puzzle.Index?
        for row in 0..<9 {
            for column in 0..<9 where grid[row][column] == 0 {
                switch pencilMarks[row][column].count {
                case 2:
                    continue
                case 3 where extraCell == nil:
                    extraCell = Puzzle.Index(row: row, column: column)
                default:
                    return nil
                }
            }
        }
        guard let cell = extraCell else { return nil }

        for digit in pencilMarks[cell.row][cell.column].sorted() {
            // With `digit` taken out of the extra cell, is every candidate in every unit twice?
            let leavesBUG = SudokuUnit.allUnits.allSatisfy { unit in
                let positions = unit.positions.filter { grid[$0.row][$0.column] == 0 }
                let placed = Set(unit.positions.map { grid[$0.row][$0.column] })
                return (1...9).allSatisfy { candidate in
                    if placed.contains(candidate) { return true }
                    let homes = positions.filter { position in
                        if position == cell && candidate == digit { return false }
                        return pencilMarks[position.row][position.column].contains(candidate)
                    }
                    return homes.count == 2
                }
            }
            guard leavesBUG else { continue }

            // The other cells of the extra cell's row holding the digit show it appears three times.
            let rowCopies = LookupTables.rowCells[cell.row].filter {
                $0 != cell && grid[$0.row][$0.column] == 0 && pencilMarks[$0.row][$0.column].contains(digit)
            }
            let actions = [HintAction(position: cell, solveAs: digit)]
            return HintStep(
                actions: actions,
                technique: .bug,
                reasoning: HintReasoning(
                    actions: actions,
                    focusDigits: [digit],
                    units: [.row(cell.row), .column(cell.column), .house(cell.houseNumber)],
                    components: [
                        .subject([cell], in: state, unit: .row(cell.row)),
                        .constraint(rowCopies, candidates: [digit], unit: .row(cell.row))
                    ]
                )
            )
        }

        return nil
    }
}
