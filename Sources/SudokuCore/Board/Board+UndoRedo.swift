//
//  Board+UndoRedo.swift
//  SudokuCore
//
//  Created by Benjamin Briggs on 25/02/2025.
//
import Foundation

public enum UndoError: Error {
    case stepNotFound
}

extension Board {

    public func undo() {
        guard let lastState = self.undoStack.popLast()
        else { return }

        self.cells = lastState.cells

        updateCellValidation()
        updateCompletedSets()
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
                } catch  {
                    print(error)
                }
            }
        }
    }

    public func makeCheckpoint() -> UndoStep {
        saveState()
        return undoStack.last!
    }

    public func saveState() {
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
