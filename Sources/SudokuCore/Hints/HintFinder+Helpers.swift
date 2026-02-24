//
//  HintFinder+Helpers.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 27/02/2025.
//
import Foundation
import Algorithms

extension HintFinder {
    /// Returns the set of valid candidate digits for a cell based on Sudoku constraints.
    ///
    /// Uses the precomputed `validOptions` on the board state, which accounts for
    /// all placed digits in the cell's row, column, and box.
    ///
    /// - Parameters:
    ///   - position: The cell position to check.
    ///   - state: The current board state snapshot.
    /// - Returns: An empty set if the cell already has a value; otherwise the valid digits.
    static func possibleValuesForCell(at position: Puzzle.Index, in state: BoardState) -> Set<Int> {
        let row = position.row
        let col = position.column


        // If the cell already has a value, return empty set
        if state.grid[row][col] != 0 {
            return []
        }

        return state.validOptions[row][col]
    }

    /// Returns the pencil-mark (candidate) digits the player has noted for a cell.
    ///
    /// Unlike `possibleValuesForCell`, this reflects the player's manually entered
    /// pencil marks rather than the constraint-derived options.
    ///
    /// - Parameters:
    ///   - position: The cell position to check.
    ///   - state: The current board state snapshot.
    /// - Returns: An empty set if the cell already has a value; otherwise the pencil marks.
    static func pencilValuesForCell(at position: Puzzle.Index, in state: BoardState) -> Set<Int> {
        let row = position.row
        let col = position.column


        // If the cell already has a value, return empty set
        if state.grid[row][col] != 0 {
            return []
        }

        return state.pencilMarks[row][col]
    }

    /// Returns a localised word for the count (e.g. 2 -> "two", 3 -> "three").
    ///
    /// - Parameter n: The numeric count to convert.
    /// - Returns: A `LocalizedStringResource` containing the word form of the count.
    static func localisedCountName(_ n: Int) -> LocalizedStringResource {
        switch n {
        case 2: return LocalizedStringResource("two", bundle: .module)
        case 3: return LocalizedStringResource("three", bundle: .module)
        case 4: return LocalizedStringResource("four", bundle: .module)
        default: return LocalizedStringResource("\(n)", bundle: .module)
        }
    }

    /// Get all constraining cells for a position using pre-computed lookup table.
    ///
    /// - Parameter position: The cell position to look up neighbours for.
    /// - Returns: The set of all cells that share a row, column, or box with `position`.
    static func getConstrainingCells(for position: Puzzle.Index) -> Set<Puzzle.Index> {
        return LookupTables.cellNeighbours[position.row][position.column]
    }

    /// Returns all k-element combinations of the given array using Swift Algorithms.
    ///
    /// - Parameters:
    ///   - array: The source array to draw elements from.
    ///   - k: The number of elements in each combination.
    /// - Returns: An array of all k-element combinations, or an empty array if `k` is out of range.
    static func combinations<T>(of array: [T], choose k: Int) -> [[T]] {
        guard k > 0 && k <= array.count else { return [] }
        return Array(array.combinations(ofCount: k).map { Array($0) })
    }

    /// Checks that no digit appears more than once in any row, column, or 3x3 box.
    ///
    /// Only placed (non-zero) values are checked. Empty cells are ignored.
    ///
    /// - Parameter grid: The 9x9 grid of placed digit values (0 for empty).
    /// - Returns: `true` if the grid has no duplicate digits in any unit; `false` otherwise.
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


    /// Finds the placed cells that prevent a given digit from being valid at a position.
    ///
    /// For each requested orientation (row, column, house), returns the set of cells
    /// that already contain `digit` and therefore restrict it from `position`.
    /// Only returns entries for orientations that actually have a restricting cell.
    ///
    /// - Parameters:
    ///   - position: The cell to check restrictions for.
    ///   - digit: The digit being investigated.
    ///   - state: The current board state.
    ///   - orientations: Which unit types to check (defaults to all).
    /// - Returns: A dictionary mapping each relevant orientation to its restricting cells.
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

    /// Collects restriction and highlight cells for explaining why a digit is forced at a position.
    ///
    /// For each empty peer cell in the given orientation, this finds the cells in the
    /// *other* orientations that restrict `digit` from that peer. The result includes:
    /// - `restrictions`: The placed cells that directly eliminate `digit` from peers.
    /// - `highlighted`: All cells in the same unit as each restricting cell (for visual context).
    ///
    /// Used by hint explanations to show why no other cell in the orientation can hold the digit.
    ///
    /// - Parameters:
    ///   - position: The cell position being explained.
    ///   - digit: The digit that is forced at `position`.
    ///   - orientation: The unit type (row, column, or house) to scan for peer cells.
    ///   - state: The current board state snapshot.
    /// - Returns: A tuple of restricting cells and highlighted cells for visual context.
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
