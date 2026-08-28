//
//  Board+UndoRedo.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 25/02/2025.
//
import Foundation
import OSLog

public enum UndoError: Error {
    case stepNotFound
}

private let logger = Logger(subsystem: "SudokuCore", category: "Board.UndoRedo")

extension Board {

    public func undo() {
        guard let lastState = self.undoStack.popLast()
        else { return }

        self.cells = lastState.cells

        refreshDerivedState()
    }

    public func undo(to step: UndoStep) throws {
        if self.cells == step.cells {
            return
        }

        // Check if the target step exists in the undoStack.
        // Here, we compare by cell state.
        guard undoStack.contains(where: { $0.cells == step.cells }) else {
            throw UndoError.stepNotFound
        }

        // Repeatedly undo until we reach the target state.
        while self.cells != step.cells {
            guard !undoStack.isEmpty else { throw UndoError.stepNotFound }
            self.undo()
        }
    }

    public func recoverToLastCorrectState() throws {
        for step in undoStack.reversed() {
            if step.correctSolution {
                do {
                    try undo(to: step)
                    return
                } catch {
                    logger.error("Failed to undo to last correct state: \(error)")
                }
            }
        }
    }

    public func makeCheckpoint() -> UndoStep {
        saveState()
        guard let checkpoint = undoStack.last else {
            // saveState() is suppressed during atomic changes; fall back to a
            // step built from the current state rather than crashing.
            return UndoStep(
                cells: cells,
                changes: [],
                isValid: isValid,
                correctSolution: isSolvable
            )
        }
        return checkpoint
    }

    public func saveState() {
        guard let step = pendingUndoStep() else { return }
        undoStack.append(step)
    }

    /// Runs `mutate` and records an undo step only if it changed any cell.
    ///
    /// The editing methods skip cells they cannot touch (given cells, filled cells for
    /// pencil marks, already-empty cells for clears). Snapshotting before knowing whether
    /// anything will change pushed a step identical to the live board, so the next
    /// `undo()` appeared to do nothing.
    internal func recordingUndo(_ mutate: () -> Void) {
        let step = pendingUndoStep()
        let before = cells
        mutate()
        guard let step, cells != before else { return }
        undoStack.append(step)
    }

    /// The step `saveState()` would push, or `nil` when nothing should be recorded
    /// (an atomic change is in progress, or the board matches the last step).
    private func pendingUndoStep() -> UndoStep? {
        guard isPerformingAtomicChange == false
        else { return nil }

        let previousState = undoStack.last

        guard cells != previousState?.cells
        else { return nil }

        let changes = previousState?.cells
            .diff(from: cells)
            .compactMap { $0.position } ?? []

        return UndoStep(
            cells: cells,
            changes: changes,
            isValid: isValid,
            correctSolution: self.isSolvable
        )
    }
}
