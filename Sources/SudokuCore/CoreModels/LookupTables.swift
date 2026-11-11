//
//  LookupTables.swift
//  SudokuCore
//
//  Created by Claude on 30/09/2025.
//
//  Pre-computed lookup tables for performance optimization

import Foundation

/// Pre-computed lookup tables for common Sudoku operations
enum LookupTables {
    /// Pre-computed neighbours for each cell (20 neighbours per cell: 8 in row, 8 in column, 4 in box excluding duplicates)
    static let cellNeighbours: [[Set<Puzzle.Index>]] = {
        var table: [[Set<Puzzle.Index>]] = Array(repeating: Array(repeating: Set<Puzzle.Index>(), count: 9), count: 9)

        for row in 0..<9 {
            for col in 0..<9 {
                var neighbours = Set<Puzzle.Index>()

                // Add cells in the same row
                for c in 0..<9 where c != col {
                    neighbours.insert(Puzzle.Index(row: row, column: c))
                }

                // Add cells in the same column
                for r in 0..<9 where r != row {
                    neighbours.insert(Puzzle.Index(row: r, column: col))
                }

                // Add cells in the same 3x3 box
                let boxRow = (row / 3) * 3
                let boxCol = (col / 3) * 3
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        if r != row || c != col {
                            neighbours.insert(Puzzle.Index(row: r, column: c))
                        }
                    }
                }

                table[row][col] = neighbours
            }
        }

        return table
    }()

    /// Pre-computed box indices for each cell
    static let cellToBoxIndex: [[Int]] = {
        var table: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)

        for row in 0..<9 {
            for col in 0..<9 {
                table[row][col] = (row / 3) * 3 + (col / 3)
            }
        }

        return table
    }()

    /// Pre-computed row cells for each row index
    static let rowCells: [[Puzzle.Index]] = {
        var table: [[Puzzle.Index]] = Array(repeating: [], count: 9)

        for row in 0..<9 {
            table[row] = (0..<9).map { Puzzle.Index(row: row, column: $0) }
        }

        return table
    }()

    /// Pre-computed column cells for each column index
    static let columnCells: [[Puzzle.Index]] = {
        var table: [[Puzzle.Index]] = Array(repeating: [], count: 9)

        for col in 0..<9 {
            table[col] = (0..<9).map { Puzzle.Index(row: $0, column: col) }
        }

        return table
    }()

    /// Pre-computed box cells for each box index (0-8)
    static let boxCells: [[Puzzle.Index]] = {
        var table: [[Puzzle.Index]] = Array(repeating: [], count: 9)

        for boxIndex in 0..<9 {
            let boxRow = (boxIndex / 3) * 3
            let boxCol = (boxIndex % 3) * 3
            var cells: [Puzzle.Index] = []

            for r in boxRow..<(boxRow + 3) {
                for c in boxCol..<(boxCol + 3) {
                    cells.append(Puzzle.Index(row: r, column: c))
                }
            }

            table[boxIndex] = cells
        }

        return table
    }()

    /// All 81 cell indices
    static let allCells: [Puzzle.Index] = {
        var cells: [Puzzle.Index] = []
        cells.reserveCapacity(81)

        for row in 0..<9 {
            for col in 0..<9 {
                cells.append(Puzzle.Index(row: row, column: col))
            }
        }

        return cells
    }()

    /// Pre-computed bitset to Set<Int> conversion
    /// Bitset represents digits 1-9 as bits 0-8
    /// For example: 0b000000001 = Set([1]), 0b000000011 = Set([1,2]), etc.
    static let bitsetToSet: [Set<Int>] = {
        var table: [Set<Int>] = []
        table.reserveCapacity(512) // 2^9 possible combinations

        for bitset in 0..<512 {
            var digits = Set<Int>()
            digits.reserveCapacity(9)

            for digit in 1...9 {
                let bit = 1 << (digit - 1)
                if (bitset & bit) != 0 {
                    digits.insert(digit)
                }
            }

            table.append(digits)
        }

        return table
    }()

    // MARK: - Cell sets as bitmasks

    // A set of cells is a `UInt128` with bit `row * 9 + column` set for each cell in it, so
    // "does this cell see all of those" is one AND instead of a hash lookup per cell.

    /// The bit for one cell in a cell-set bitmask.
    static func cellBit(_ cell: Int) -> UInt128 { 1 << UInt128(cell) }

    /// All 81 cells.
    static let allCellsMask: UInt128 = (1 << 81) - 1

    /// Each cell's 20 neighbours, indexed by `row * 9 + column`.
    static let peerMasks: [UInt128] = (0..<81).map { cell in
        cellNeighbours[cell / 9][cell % 9].reduce(0) { $0 | cellBit($1.row * 9 + $1.column) }
    }

    /// The cells of each unit, in `SudokuUnit.allUnits` order: rows, columns, houses.
    static let unitMasks: [UInt128] = (rowCells + columnCells + boxCells).map { cells in
        cells.reduce(0) { $0 | cellBit($1.row * 9 + $1.column) }
    }

    /// Every way to choose `k` of `0..<count`, as ascending index lists in lexicographic order:
    /// `choices[count][k]`, for `count` up to 9. Worked out once, so a finder that tries every
    /// combination of a unit's cells or lines doesn't build the lists again at every state.
    static let choices: [[[[Int]]]] = (0...9).map { count in
        (0...count).map { k in
            var result: [[Int]] = []
            var current: [Int] = []
            func choose(from start: Int) {
                if current.count == k {
                    result.append(current)
                    return
                }
                guard count - start >= k - current.count else { return }
                for index in start..<count {
                    current.append(index)
                    choose(from: index + 1)
                    current.removeLast()
                }
            }
            choose(from: 0)
            return result
        }
    }

    /// `choices[count][k]`, or none when `k` is out of range: what `combinations(of:choose:)`
    /// gives for a list of `count` items, as indices into it.
    static func choices(of count: Int, choose k: Int) -> [[Int]] {
        guard k > 0, k <= count else { return [] }
        return choices[count][k]
    }
}
