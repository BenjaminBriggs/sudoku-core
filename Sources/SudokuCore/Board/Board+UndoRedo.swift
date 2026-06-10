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
        guard isPerformingAtomicChange == false
        else { return }

        let previousState = undoStack.last

        guard cells != previousState?.cells
        else { return }


        let changes = previousState?.cells
            .diff(from: cells)
            .compactMap { $0.position } ?? []

        undoStack.append(
            UndoStep(
                cells: cells,
                changes: changes,
                isValid: isValid,
                correctSolution: self.isSolvable
            )
        )
    }
}
