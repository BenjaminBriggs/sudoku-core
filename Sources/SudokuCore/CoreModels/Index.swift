//
//  Index.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 19/02/2025.
//
import Foundation

extension Puzzle {
    /// Represents a position in the 9x9 Sudoku grid.
    ///
    /// `Index` uses zero-based coordinates where (0,0) is the top-left cell
    /// and (8,8) is the bottom-right cell.
    ///
    /// ## House Mapping
    ///
    /// The 3x3 house (box) number for a cell is calculated as:
    /// ```swift
    /// let house = (row / 3) * 3 + (column / 3)
    /// ```
    ///
    /// Houses are numbered 0-8 in row-major order:
    /// ```
    /// 0 1 2
    /// 3 4 5
    /// 6 7 8
    /// ```
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let topLeft = Puzzle.Index(row: 0, column: 0)
    /// let center = Puzzle.Index(row: 4, column: 4)
    ///
    /// // Access all 81 positions
    /// for index in Puzzle.Index.allIndices {
    ///     // Process each cell
    /// }
    /// ```
    public struct Index: Codable, Hashable, Sendable {
        /// The row number (0-8) where 0 is the top row.
        public let row: Int

        /// The column number (0-8) where 0 is the leftmost column.
        public let column: Int

        /// Creates an index for the specified row and column.
        ///
        /// - Parameters:
        ///   - row: The row number (0-8).
        ///   - column: The column number (0-8).
        public init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(row)
            hasher.combine(column)
        }
    }
}

extension Puzzle.Index {
    /// All 81 positions in the grid in row-major order.
    ///
    /// The indices are ordered from top-left (0,0) to bottom-right (8,8),
    /// going left-to-right, top-to-bottom.
    public static var allIndices: [Puzzle.Index] {
        (0..<9).flatMap { r in
            (0..<9).map { c in
                Puzzle.Index(row: r, column: c)
            }
        }
    }
}


extension Puzzle.Index: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        // the human readable description is 1 indexed
        "(\(row+1),\(column+1))"
    }

    public var debugDescription: String {
        "Puzzle.Index(row: \(row), column: \(column))"
    }
}
