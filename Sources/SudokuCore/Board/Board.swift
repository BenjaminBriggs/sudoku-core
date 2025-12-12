//
//  Board.swift
//  Sudoku-Blue
//
//  Created by Benjamin Briggs on 03/02/2025.
//
import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Represents the game state for a Sudoku puzzle.
///
/// `Board` is the core data structure that manages the entire state of a Sudoku game,
/// including the 81 cells, player progress, validation, undo/redo history, and statistics.
/// It uses Swift's `@Observable` macro for automatic UI updates.
///
/// ## Overview
///
/// The board maintains:
/// - A flat array of 81 ``Cell`` objects representing the puzzle grid
/// - Validation state tracking which rows, columns, houses, and numbers are complete
/// - Undo/redo functionality with a complete history stack
/// - Player statistics (incorrect moves, hints used, note updates)
/// - Auto-pencil marking support
///
/// ## Cell Access
///
/// Cells are stored in a flat array indexed by row-major order (row 0, columns 0-8, then row 1, etc.).
/// Use ``cell(at:)`` to access cells by position.
///
/// ## Usage Example
///
/// ```swift
/// // Create a board from a puzzle
/// let board = Board(puzzle: myPuzzle)
///
/// // Make a move
/// board.mark(positions: [position], as: 5)
///
/// // Undo if needed
/// try board.undo()
///
/// // Check completion
/// if board.isSolved {
///     os_log("Puzzle solved!")
/// }
/// ```
@Observable
@MainActor
public final class Board {
    // MARK: - Puzzle Configuration

    /// The difficulty level of this puzzle (easy, medium, hard, expert, professional, or custom).
    public let difficulty: PuzzleDifficulty.Level

    /// The HoDoKu difficulty score representing the puzzle's intrinsic difficulty.
    ///
    /// See ``PuzzleDifficulty`` for details on the scoring system. Higher scores indicate more difficult puzzles.
    public let difficultyScore: Int

    // MARK: - Grid State

    /// The 81 cells that make up the Sudoku grid.
    ///
    /// Cells are stored in row-major order: cells 0-8 are row 0, cells 9-17 are row 1, etc.
    /// Use ``cell(at:)`` for position-based access instead of indexing directly.
    public internal(set) var cells: [Board.Cell]

    /// The complete solution grid, if available.
    ///
    /// A 9x9 array where `solution[row][column]` gives the correct value for that cell.
    /// May be `nil` for puzzles without a known solution.
    public internal(set) var solution: [[Int]]?

    // MARK: - Completion Tracking

    /// Rows (0-8) that are completely filled with correct values.
    public internal(set) var completedRows: Set<Int> = []

    /// Columns (0-8) that are completely filled with correct values.
    public internal(set) var completedColumns: Set<Int> = []

    /// Houses/boxes (0-8) that are completely filled with correct values.
    ///
    /// Houses are numbered 0-8 in row-major order: top-left is 0, top-middle is 1, etc.
    public internal(set) var completedHouses: Set<Int> = []

    /// Numbers (1-9) that have all nine instances correctly placed on the board.
    public internal(set) var completedNumbers: Set<Int> = []

    // MARK: - Player Statistics

    /// Count of incorrect values placed by the player.
    ///
    /// This is incremented when a player places a value that doesn't match the solution.
    /// Only tracked when a solution is available.
    public internal(set) var incorrectMoves: Int = 0

    /// Count of hints requested by the player during this game.
    public internal(set) var hintsUsed: Int = 0

    /// Count of manual pencil mark updates made by the player.
    ///
    /// Auto-generated pencil marks are not counted.
    public internal(set) var noteUpdates: Int = 0

    // MARK: - Puzzle Status

    /// Whether the puzzle has been successfully completed.
    ///
    /// Set to `true` when all cells are filled correctly.
    public var isSolved = false

    /// Whether the puzzle is still solvable.
    ///
    /// Set to `false` if the current board state has led to an unsolvable configuration.
    public var isSolvable = true

    // MARK: - Undo/Redo

    /// Whether the undo stack has any states to restore.
    public var canUndo: Bool {
        undoStack.isEmpty == false
    }

    /// Stack of previous board states for undo functionality.
    ///
    /// Each ``UndoStep`` captures the complete state at a point in time.
    /// Use ``undo()`` or ``undo(to:)`` to restore previous states.
    public internal(set) var undoStack: [UndoStep] = []

    // MARK: - Auto-Pencil Mode

    /// When enabled, the board automatically maintains valid pencil marks for empty cells.
    ///
    /// Setting this to `true` triggers an immediate update of all pencil marks based on
    /// current board state and valid candidates for each cell.
    public var autoPencilMode: Bool = false {
        didSet {
            if autoPencilMode {
                updatePencilMarks()
            }
        }
    }

    // MARK: - Initialization

    /// Creates an empty board with no given cells.
    ///
    /// Useful for testing or creating a blank puzzle to solve.
    public convenience init() {
        self.init(
            difficulty: .easy,
            difficultyScore: 0,
            givenCells: Solution.empty()
        )
    }

    /// Creates a board from a ``Puzzle`` instance.
    ///
    /// This is the primary way to initialize a board for gameplay.
    ///
    /// - Parameter puzzle: The puzzle containing starting state, solution, and difficulty information.
    public convenience init(puzzle: Puzzle) {
        self.init(
            difficulty: puzzle.difficulty.level,
            difficultyScore: puzzle.difficulty.score,
            givenCells: puzzle.startingState,
            solution: puzzle.solution
        )
    }

    /// Creates a board from a string representation.
    ///
    /// - Parameters:
    ///   - difficulty: The difficulty level for this puzzle. Defaults to `.custom`.
    ///   - string: An 81-character string where '0' or '.' represents empty cells and '1'-'9' represent given values.
    public convenience init(
        difficulty: PuzzleDifficulty.Level = .custom,
        string: String = ""
    ) {
        self.init(
            difficulty: difficulty,
            difficultyScore: 0,
            givenCells: Solution.cells(from: string)
        )
    }

    /// Creates a board with the specified configuration.
    ///
    /// This is the designated initializer that all other initializers call.
    ///
    /// - Parameters:
    ///   - difficulty: The difficulty level of this puzzle.
    ///   - difficultyScore: The HoDoKu difficulty score.
    ///   - givenCells: A 9x9 array of integers (0-9) where 0 represents empty cells.
    ///   - solution: Optional 9x9 array containing the complete solution.
    ///
    /// - Precondition: `givenCells` must be exactly 9x9.
    public init(
        difficulty: PuzzleDifficulty.Level = .custom,
        difficultyScore: Int = 0,
        givenCells: [[Int]],
        solution: [[Int]]? = nil
    ) {
        precondition(givenCells.count == 9)
        precondition(givenCells.allSatisfy { $0.count == 9 })

        self.difficulty = difficulty
        self.difficultyScore = difficultyScore
        self.solution = solution
        self.cells = []

        SetUp(givenCells, solution)
    }

    // MARK: - Setup

    /// Initializes the cell array from the given configuration.
    ///
    /// This method creates all 81 cells and performs initial validation.
    /// It's called during initialization and when resetting the board.
    ///
    /// - Parameters:
    ///   - givenCells: A 9x9 array of integers (0-9) where 0 represents empty cells.
    ///   - solution: Optional 9x9 array containing the complete solution.
    public func SetUp(_ givenCells: [[Int]], _ solution: [[Int]]?) {
        var cells = [Board.Cell]()
        for (row, columns) in givenCells.enumerated() {
            for (column, value) in columns.enumerated() {
                let position = Puzzle.Index(row: row, column: column)
                let correctValue: Int?
                if let solution {
                    correctValue = solution[row][column]
                } else {
                    correctValue = nil
                }
                if value != 0 {
                    cells.append(
                        Board.Cell(
                            position: position,
                            value: value,
                            isGiven: true,
                            correctAnswer: correctValue
                        )
                    )
                } else {
                    cells.append(
                        Board.Cell(
                            position: position,
                            value: nil,
                            isGiven: false,
                            correctAnswer: correctValue
                        )
                    )
                }
            }
        }

        assert(
            cells.count == 81,
            "We should have a board with 81 cells, but we have \(cells.count)"
        )
        self.cells = cells
        updateCellValidation()
    }
}

extension Puzzle.Index {
    var linerIndex: Int {
        row * 9 + column
    }
}
