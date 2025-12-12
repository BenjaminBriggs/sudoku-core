//
//  HintFinder+Helpers.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation
import Algorithms

extension HintFinder {
    static func possibleValuesForCell(at position: Puzzle.Index, in state: BoardState) -> Set<Int> {
        let row = position.row
        let col = position.column


        // If the cell already has a value, return empty set
        if state.grid[row][col] != 0 {
            return []
        }

        return state.validOptions[row][col]
    }

    static func pencilValuesForCell(at position: Puzzle.Index, in state: BoardState) -> Set<Int> {
        let row = position.row
        let col = position.column


        // If the cell already has a value, return empty set
        if state.grid[row][col] != 0 {
            return []
        }

        return state.pencilMarks[row][col]
    }

    /// Get all constraining cells for a position using pre-computed lookup table
    static func getConstrainingCells(for position: Puzzle.Index) -> Set<Puzzle.Index> {
        return LookupTables.cellNeighbours[position.row][position.column]
    }

    /// Optimized combinations using Swift Algorithms
    /// Returns an array of all k-element combinations
    static func combinations<T>(of array: [T], choose k: Int) -> [[T]] {
        guard k > 0 && k <= array.count else { return [] }
        return Array(array.combinations(ofCount: k).map { Array($0) })
    }

    static func checkNoConflicts(in grid: [[Int]]) -> Bool {
        // Check rows
        for row in 0..<9 {
            var seen = Set<Int>()
            for col in 0..<9 {
                let value = grid[row][col]
                if value != 0 {
                    if seen.contains(value) {
                        return false
                    }
                    seen.insert(value)
                }
            }
        }

        // Check columns
        for col in 0..<9 {
            var seen = Set<Int>()
            for row in 0..<9 {
                let value = grid[row][col]
                if value != 0 {
                    if seen.contains(value) {
                        return false
                    }
                    seen.insert(value)
                }
            }
        }

        // Check houses
        for houseRow in stride(from: 0, to: 9, by: 3) {
            for houseCol in stride(from: 0, to: 9, by: 3) {
                var seen = Set<Int>()
                for r in houseRow..<(houseRow + 3) {
                    for c in houseCol..<(houseCol + 3) {
                        let value = grid[r][c]
                        if value != 0 {
                            if seen.contains(value) {
                                return false
                            }
                            seen.insert(value)
                        }
                    }
                }
            }
        }

        return true
    }

    func isCompleteAndValid(grid: [[Int]]) -> Bool {
        // Check if all cells are filled
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 {
                    return false
                }
            }
        }

        // Check for conflicts
        return Self.checkNoConflicts(in: grid)
    }

    /// Get all neighbours of a cell using pre-computed lookup table
    static func getNeighbours(of position: Puzzle.Index, in state: BoardState) -> Set<Puzzle.Index> {
        return LookupTables.cellNeighbours[position.row][position.column]
    }

    static func getRestrictingCells(
        for position: Puzzle.Index,
        digit: Int,
        in state: BoardState,
        orientations: [Puzzle.Index.Orientation] = Puzzle.Index.Orientation.allCases
    ) -> [Puzzle.Index.Orientation: Set<Puzzle.Index>] {
        var result: [Puzzle.Index.Orientation: Set<Puzzle.Index>] = [:]

        // Check if the cell already contains a value
        if state.grid[position.row][position.column] != 0 {
            return result
        }

        // Check if the digit is already ruled out by existing constraints
        if state.validOptions[position.row][position.column].contains(digit) == false {
            // For each orientation, find cells that have this digit
            for orientation in orientations {
                var restrictingCells = Set<Puzzle.Index>()

                switch orientation {
                case .row:
                    // Check the row
                    for col in 0..<9 where col != position.column {
                        let cellPos = Puzzle.Index(row: position.row, column: col)
                        if state.grid[position.row][col] == digit {
                            restrictingCells.insert(cellPos)
                        }
                    }

                    if restrictingCells.isEmpty == false {
                        result[.row] = restrictingCells
                    }

                case .column:
                    // Check the column
                    for row in 0..<9 where row != position.row {
                        let cellPos = Puzzle.Index(row: row, column: position.column)
                        if state.grid[row][position.column] == digit {
                            restrictingCells.insert(cellPos)
                        }
                    }

                    if restrictingCells.isEmpty == false {
                        result[.column] = restrictingCells
                    }

                case .house:
                    // Check the 3x3 box
                    let houseStartRow = (position.row / 3) * 3
                    let houseStartCol = (position.column / 3) * 3

                    for r in houseStartRow..<(houseStartRow + 3) {
                        for c in houseStartCol..<(houseStartCol + 3) {
                            if r != position.row || c != position.column {
                                let cellPos = Puzzle.Index(row: r, column: c)
                                if state.grid[r][c] == digit {
                                    restrictingCells.insert(cellPos)
                                }
                            }
                        }
                    }

                    if restrictingCells.isEmpty == false {
                        result[.house] = restrictingCells
                    }
                }
            }
        }

        return result
    }

    static func cellsOfIntrest(
        for position: Puzzle.Index,
        with digit: Int,
        in orientation: Puzzle.Index.Orientation,
        in state: BoardState
    ) -> (
        restrictions: Set<Puzzle.Index>,
        highlighted: Set<Puzzle.Index>
    ) {
        var restrictions = Set<Puzzle.Index>()
        var highlighted = Set<Puzzle.Index>()
        for index in position.cells(in: orientation) where index != position {
            if state.grid[index.row][index.column] == 0 {
                let cells = Self.getRestrictingCells(
                    for: index,
                    digit: digit,
                    in: state,
                    orientations: orientation.otherOrientations
                )
                for cell in cells {
                    restrictions.formUnion(cell.value)
                    for a in cell.value {
                        highlighted.formUnion(a.cells(in: cell.key))
                    }
                }
            }
        }
        return (restrictions, highlighted)
    }
}
