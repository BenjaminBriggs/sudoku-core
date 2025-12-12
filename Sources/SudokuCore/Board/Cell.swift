//
//  Cell.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 05/02/2025.
//
import Foundation

extension Board {
    /// Represents a single cell in the Sudoku grid.
    ///
    /// Each cell has a position, an optional value (1-9), and various marking states
    /// used for pencil marks and validation. Cells can be either "given" (part of the
    /// initial puzzle) or player-filled.
    ///
    /// ## Pencil Marks
    ///
    /// Cells support two types of pencil marks:
    /// - **Simple pencil marks**: Basic candidate numbers manually entered by the player
    /// - **Advanced pencil marks**: Additional candidate tracking for advanced solving techniques
    ///
    /// ## Validation
    ///
    /// The board automatically maintains:
    /// - `validOptions`: Candidates that don't conflict with existing values
    /// - `ruledOutCandidates`: Candidates eliminated by the player or solving logic
    /// - `allowedValues`: Valid candidates after ruling out (computed property)
    ///
    /// ## State Changes
    ///
    /// Cell state should only be modified through ``Board`` methods like ``Board/mark(positions:as:)``
    /// rather than directly, as the board needs to maintain validation and undo history.
    public struct Cell: Identifiable, Hashable, Codable, Sendable {
        /// Unique identifier for this cell, used for SwiftUI list tracking.
        public internal(set) var id = UUID()

        /// The position of this cell in the 9x9 grid.
        public let position: Puzzle.Index

        /// Whether this cell was part of the initial puzzle configuration.
        ///
        /// Given cells cannot be modified by the player.
        public let isGiven: Bool

        /// The current value placed in this cell (1-9), or `nil` if empty.
        public internal(set) var value: Int?

        /// Simple pencil marks entered by the player.
        ///
        /// These are the basic candidate numbers that appear as small numbers in the cell.
        public internal(set) var simplePencilMarks: Set<Int> = []

        /// Advanced pencil marks for sophisticated solving techniques.
        ///
        /// Used by advanced players to track additional candidate information beyond simple marks.
        public internal(set) var advancedPencilMarks: Set<Int> = []

        /// Candidates that have been explicitly ruled out.
        ///
        /// These are removed from ``allowedValues`` even if they appear in ``validOptions``.
        public internal(set) var ruledOutCandidates: Set<Int> = []

        /// All valid candidate values based on current board state.
        ///
        /// Automatically maintained by the board's validation system.
        /// Contains numbers that don't conflict with the same row, column, or house.
        public internal(set) var validOptions: Set<Int> = []

        /// The correct answer for this cell from the solution, if known.
        ///
        /// Used for validation and error detection. May be `nil` if no solution is available.
        public internal(set) var correctAnswer: Int? = nil

        /// Visual highlighting/coloring applied to this cell.
        ///
        /// Used for hint visualization and player-applied colors.
        public internal(set) var background: Background = .clear

        /// Creates a new cell with the specified configuration.
        ///
        /// - Parameters:
        ///   - position: The cell's position in the grid.
        ///   - value: Optional value (1-9) if the cell is filled.
        ///   - isGiven: Whether this is a given cell from the puzzle.
        ///   - pencilMarks: Initial simple pencil marks.
        ///   - advancedPencilMarks: Initial advanced pencil marks.
        ///   - ruledOutCandidates: Initially ruled-out candidates.
        ///   - validOptions: Initially valid candidate options.
        ///   - correctAnswer: The correct value from the solution.
        ///   - background: Initial background color/highlighting.
        public init(
            position: Puzzle.Index,
            value: Int? = nil,
            isGiven: Bool = false,
            pencilMarks: Set<Int> = [],
            advancedPencilMarks: Set<Int> = [],
            ruledOutCandidates: Set<Int> = [],
            validOptions: Set<Int> = [],
            correctAnswer: Int? = nil,
            background: Background = .clear
        ) {
            self.position = position
            self.value = value
            self.isGiven = isGiven
            self.simplePencilMarks = pencilMarks
            self.advancedPencilMarks = advancedPencilMarks
            self.ruledOutCandidates = ruledOutCandidates
            self.validOptions = validOptions
            self.correctAnswer = correctAnswer
            self.background = background
        }

        /// The set of candidate values that are both valid and not ruled out.
        ///
        /// This is computed as `validOptions - ruledOutCandidates`.
        public var allowedValues: Set<Int> {
            validOptions.subtracting(ruledOutCandidates)
        }
    }
}

extension Array where Element == Board.Cell {
    /// Converts the cell array into a 9x9 grid representation.
    ///
    /// Empty cells are represented as 0 in the returned grid.
    ///
    /// - Returns: A 9x9 array where each element is the cell's value (0-9).
    public var solution: [[Int]] {
        var grid: [[Int]] = Array<Array<Int>>(
            repeating: Array<Int>(
                repeating: 0,
                count: 9
            ),
            count: 9
        )

        for cell in self {
            if let val = cell.value {
                grid[cell.position.row][cell.position.column] = val
            }
        }
        return grid
    }

    /// A formatted debug description showing the grid with visual grouping.
    ///
    /// The output includes extra spacing after the 3rd and 6th rows/columns
    /// to visually separate the 3x3 houses.
    ///
    /// - Returns: A multi-line string representation of the grid suitable for debugging.
    public var debugDescription: String {
        var output = ""
        for (i, row) in solution.enumerated() {
            output += "["
            output += row.enumerated().map { (j, num) in
                let separator = (j == 2 || j == 5) ? ", " : ","
                return "\(num)\(separator)"
            }.joined()

            // remove the last ,
            output.removeLast()
            output += "],\n"

            if i == 2 || i == 5 {
                output += "\n"
            }
        }
        // remove final , and newline
        output.removeLast(2)

        return output
    }

    /// Converts the cell array to a flat 81-character string.
    ///
    /// - Parameter empty: The character to use for empty cells (typically "0" or ".").
    /// - Returns: An 81-character string representing the entire grid in row-major order.
    public func flatString(empty: String) -> String {
        solution.map {
            $0.map {
                $0 == 0 ? empty : "\($0)"
            }.joined()
        }.joined()
    }
}

extension Array where Element == Board.Cell {
    /// Returns the cells that have changed between two cell arrays.
    ///
    /// Cells are considered changed if their value or any pencil marks differ.
    /// Used for undo/redo and change tracking.
    ///
    /// - Parameter oldCells: The previous cell array to compare against.
    /// - Returns: An array containing only the cells that have changed.
    func diff(from oldCells: [Board.Cell]) -> [Board.Cell] {
        // Create a lookup for the old cells by their id
        let oldCellDict = Dictionary(uniqueKeysWithValues: oldCells.map { ($0.id, $0) })

        // Filter the new cells: if a cell is not present in the old array or is different, consider it changed
        return self.filter { newCell in
            guard let oldCell = oldCellDict[newCell.id] else {
                // New cell not found in old array – treat as changed
                return true
            }
            return oldCell.value != newCell.value ||
            oldCell.simplePencilMarks != newCell.simplePencilMarks ||
            oldCell.advancedPencilMarks != newCell.advancedPencilMarks ||
            oldCell.ruledOutCandidates != newCell.ruledOutCandidates
        }
    }
}
