//
//  UndoStep.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 22/02/2025.
//
import Foundation
extension Board {
    /// Captures a snapshot of the board state for undo/redo functionality.
    ///
    /// An `UndoStep` stores the complete state of all 81 cells along with metadata
    /// about validity and which positions changed since the previous state.
    ///
    /// ## Usage
    ///
    /// Undo steps are automatically managed by ``Board`` methods. When you modify
    /// the board through methods like ``Board/mark(positions:as:)``, the board
    /// saves the current state to the undo stack before applying changes.
    ///
    /// ```swift
    /// // Make a move (automatically saves undo state)
    /// board.mark(positions: [position], as: 5)
    ///
    /// // Undo to previous state
    /// try board.undo()
    ///
    /// // Or undo to a specific checkpoint
    /// if let checkpoint = board.undoStack.last {
    ///     try board.undo(to: checkpoint)
    /// }
    /// ```
    public struct UndoStep: Codable, Sendable {
        /// Snapshot of all 81 cells at this point in time.
        public let cells: [Cell]

        /// Positions that changed to create this undo step.
        ///
        /// Tracks which cells were modified, useful for highlighting or analytics.
        public let changes: [Puzzle.Index]

        /// Whether the board had no validation conflicts at this state.
        public let isValid: Bool

        /// Whether the board state was still solvable (no contradictions).
        public let correctSolution: Bool

        /// Timestamp when this state was captured.
        public let date: Date

        /// Creates an undo step with the specified configuration.
        ///
        /// - Parameters:
        ///   - cells: The cell array to snapshot.
        ///   - changes: Positions that changed to reach this state.
        ///   - isValid: Whether the board has no validation errors.
        ///   - correctSolution: Whether the board is still solvable.
        init(
            cells: [Cell],
            changes: [Puzzle.Index],
            isValid: Bool,
            correctSolution: Bool
        ) {
            self.cells = cells
            self.changes = changes
            self.isValid = isValid
            self.correctSolution = correctSolution
            self.date = .now
        }

        /// Creates an undo step from the current board state.
        ///
        /// This captures a complete snapshot with no specific change tracking.
        ///
        /// - Parameter board: The board to snapshot.
        @MainActor
        public init(from board: Board) {
            self.cells = board.cells
            self.changes = []
            self.isValid = board.isValid
            self.correctSolution = board.isSolvable
            self.date = .now
        }
    }
}

extension Board.UndoStep: Equatable {}

extension Board.UndoStep: CustomDebugStringConvertible {
    public var debugDescription: String {
        cells.solution.exportString
    }
}
