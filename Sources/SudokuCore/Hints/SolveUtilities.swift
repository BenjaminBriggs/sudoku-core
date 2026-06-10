//
//  SolveUtilities.swift
//  SudokuCore
//
//  Shared utilities for human-style solving steps.
//

import Foundation

extension BoardState {
    /// Build a BoardState from a 9x9 grid, initializing candidates via Validator.
    public static func fromGrid(_ grid: [[Int]]) -> BoardState {
        let pencilMarks = Validator.validOptions(for: grid)
        return BoardState(
            grid: grid,
            pencilMarks: pencilMarks,
            validOptions: pencilMarks
        )
    }

    /// True when every cell is non-zero and there are no conflicts.
    public var isSolved: Bool {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 { return false }
            }
        }
        return Validator.hasNoConflicts(in: grid)
    }

    /// Apply a hint's actions to produce the next BoardState, recalculating candidates.
    public func applying(_ hint: HintStep) -> BoardState {
        var newGrid = self.grid
        var newPencilMarks = self.pencilMarks
        var gridChanged = false

        for action in hint.actions {
            switch action.action {
            case .solveAs(let value):
                newGrid[action.position.row][action.position.column] = value
                newPencilMarks[action.position.row][action.position.column] = []
                gridChanged = true
            case .ruleOut(let value):
                newPencilMarks[action.position.row][action.position.column].remove(value)
            case .pencilIn(_):
                break
            case .clear:
                newGrid[action.position.row][action.position.column] = 0
                gridChanged = true
            }
        }

        // Elimination-only hints leave the grid untouched, so the valid options
        // derived from it are unchanged — skip the full recompute.
        let validOptions = gridChanged ? Validator.validOptions(for: newGrid) : self.validOptions
        var merged = newPencilMarks
        for row in 0..<9 {
            for col in 0..<9 {
                merged[row][col] = merged[row][col].intersection(validOptions[row][col])
            }
        }

        return BoardState(
            grid: newGrid,
            pencilMarks: merged,
            validOptions: validOptions
        )
    }
}

extension HintFinder {
    /// Return the first available hint scanning techniques from easiest to hardest.
    ///
    /// `techniques` defaults to the classic set; variant modules append their own
    /// (e.g. `ClassicTechniques.all + KillerSudoku.techniques`). The array is
    /// stable-sorted by difficulty, so callers compose by concatenation.
    public static func firstHint(
        in state: BoardState,
        using techniques: [any HintTechnique] = ClassicTechniques.all
    ) -> HintStep? {
        for technique in techniques.sorted(by: { $0.info.difficulty < $1.info.difficulty }) {
            if let hint = technique.findHint(in: state) {
                return hint
            }
        }
        return nil
    }
}

